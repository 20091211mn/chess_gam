// Chess server: matchmaking by time control, move validation, server clocks,
// Elo ratings per category (bullet / blitz / rapid), draw offers, rematch, leaderboard.
const { WebSocketServer } = require('ws');
const { Chess } = require('chess.js');
const fs = require('fs');

const FILE = process.env.RATINGS_FILE || './ratings.json';
let db = {};
try {
  db = JSON.parse(fs.readFileSync(FILE, 'utf8'));
} catch (e) {}
let dirty = false;
setInterval(() => {
  if (dirty) {
    try {
      fs.writeFileSync(FILE, JSON.stringify(db));
    } catch (e) {}
    dirty = false;
  }
}, 15000);

const START = 800;
const CATS = ['bullet', 'blitz', 'rapid'];

function player(id, name) {
  if (!db[id]) {
    db[id] = {
      name: name || 'Player',
      r: { bullet: START, blitz: START, rapid: START },
      n: { bullet: 0, blitz: 0, rapid: 0 },
    };
  } else if (name) {
    db[id].name = name;
  }
  dirty = true;
  return db[id];
}

function catOf(min, inc) {
  const t = min * 60 + inc * 40;
  return t < 180 ? 'bullet' : t < 600 ? 'blitz' : 'rapid';
}

function elo(ra, rb, score, games) {
  const e = 1 / (1 + Math.pow(10, (rb - ra) / 400));
  const k = games < 10 ? 40 : ra < 2200 ? 24 : 16;
  return Math.round(k * (score - e));
}

const wss = new WebSocketServer({ port: process.env.PORT || 8080 });
const queues = new Map(); // "min+inc" -> [ws]
const rooms = new Map(); // room id -> {ws, min, inc}
let gidSeq = 1;

const send = (ws, o) => {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(o));
};
const clampTc = (m) => ({
  min: Math.max(1, Math.min(60, parseInt(m.min) || 10)),
  inc: Math.max(0, Math.min(30, parseInt(m.inc) || 0)),
});
const oppOf = (ws) => {
  const g = ws.game;
  if (!g) return null;
  return g.w === ws ? g.b : g.w;
};

function startGame(a, b, min, inc, aWhite) {
  if (aWhite === undefined) aWhite = Math.random() < 0.5;
  const w = aWhite ? a : b;
  const bl = aWhite ? b : a;
  const c = catOf(min, inc);
  const g = {
    id: gidSeq++,
    w,
    b: bl,
    chess: new Chess(),
    min,
    inc,
    cat: c,
    clocks: { w: min * 60000, b: min * 60000 },
    last: Date.now(),
    moves: 0,
    over: false,
    timer: null,
    offer: null,
    rw: player(w.pid).r[c],
    rb: player(bl.pid).r[c],
  };
  a.game = g;
  b.game = g;
  w.side = 'w';
  bl.side = 'b';
  w.rematch = false;
  bl.rematch = false;
  send(w, { t: 'start', color: 'w', opp: { name: bl.pname, rating: g.rb }, you: { rating: g.rw }, min, inc, cat: c });
  send(bl, { t: 'start', color: 'b', opp: { name: w.pname, rating: g.rw }, you: { rating: g.rb }, min, inc, cat: c });
  armTimer(g);
}

function armTimer(g) {
  clearTimeout(g.timer);
  if (g.over) return;
  if (g.moves < 1) {
    g.timer = setTimeout(() => {
      if (!g.over && g.moves < 1) finish(g, '*', 'aborted');
    }, 45000);
    return;
  }
  const side = g.chess.turn();
  const left = Math.max(0, g.clocks[side] - (Date.now() - g.last)) + 80;
  g.timer = setTimeout(() => {
    if (!g.over) finish(g, side === 'w' ? '0-1' : '1-0', 'timeout');
  }, left);
}

function finish(g, result, reason) {
  if (g.over) return;
  g.over = true;
  clearTimeout(g.timer);
  const rated = g.moves >= 2 && result !== '*';
  let dw = 0,
    dbk = 0,
    nw = g.rw,
    nb = g.rb;
  if (rated) {
    const sw = result === '1-0' ? 1 : result === '0-1' ? 0 : 0.5;
    const pw = player(g.w.pid);
    const pb = player(g.b.pid);
    dw = elo(g.rw, g.rb, sw, pw.n[g.cat]);
    dbk = elo(g.rb, g.rw, 1 - sw, pb.n[g.cat]);
    pw.r[g.cat] = Math.max(100, g.rw + dw);
    pb.r[g.cat] = Math.max(100, g.rb + dbk);
    pw.n[g.cat]++;
    pb.n[g.cat]++;
    nw = pw.r[g.cat];
    nb = pb.r[g.cat];
    dirty = true;
  }
  const w = g.w,
    b = g.b;
  send(w, { t: 'end', result, reason, delta: dw, rating: nw, rated });
  send(b, { t: 'end', result, reason, delta: dbk, rating: nb, rated });
  w.lastOpp = b;
  b.lastOpp = w;
  w.lastTc = b.lastTc = { min: g.min, inc: g.inc };
  w.lastSide = 'w';
  b.lastSide = 'b';
  w.game = null;
  b.game = null;
}

function onMove(ws, m) {
  const g = ws.game;
  if (!g || g.over || g.chess.turn() !== ws.side) return;
  const now = Date.now();
  if (g.moves >= 1) {
    g.clocks[ws.side] -= now - g.last;
    if (g.clocks[ws.side] <= 0) {
      g.clocks[ws.side] = 0;
      return finish(g, ws.side === 'w' ? '0-1' : '1-0', 'timeout');
    }
  }
  try {
    g.chess.move({ from: m.from, to: m.to, promotion: m.promo || 'q' });
  } catch (e) {
    return send(ws, { t: 'illegal' });
  }
  g.clocks[ws.side] += g.inc * 1000;
  g.moves++;
  g.last = now;
  g.offer = null;
  const pay = { t: 'move', from: m.from, to: m.to, promo: m.promo || null, wt: g.clocks.w, bt: g.clocks.b };
  send(oppOf(ws), pay);
  send(ws, { t: 'clock', wt: g.clocks.w, bt: g.clocks.b });
  if (g.chess.isCheckmate()) return finish(g, ws.side === 'w' ? '1-0' : '0-1', 'checkmate');
  if (g.chess.isStalemate()) return finish(g, '1/2-1/2', 'stalemate');
  if (g.chess.isDraw()) return finish(g, '1/2-1/2', 'draw');
  armTimer(g);
}

function leaveQueues(ws) {
  if (ws.queueKey) {
    const q = queues.get(ws.queueKey) || [];
    queues.set(ws.queueKey, q.filter((x) => x !== ws));
    ws.queueKey = null;
  }
  if (ws.roomId) {
    const r = rooms.get(ws.roomId);
    if (r && r.ws === ws) rooms.delete(ws.roomId);
    ws.roomId = null;
  }
}

function quick(ws, tc) {
  leaveQueues(ws);
  const key = tc.min + '+' + tc.inc;
  const q = (queues.get(key) || []).filter((x) => x.readyState === 1);
  const c = catOf(tc.min, tc.inc);
  const mine = player(ws.pid).r[c];
  let bi = -1,
    bd = 1e9;
  q.forEach((o, i) => {
    if (o !== ws) {
      const d = Math.abs(player(o.pid).r[c] - mine);
      if (d < bd) {
        bd = d;
        bi = i;
      }
    }
  });
  if (bi >= 0) {
    const o = q.splice(bi, 1)[0];
    queues.set(key, q);
    o.queueKey = null;
    startGame(o, ws, tc.min, tc.inc);
  } else {
    q.push(ws);
    queues.set(key, q);
    ws.queueKey = key;
    send(ws, { t: 'waiting' });
  }
}

wss.on('connection', (ws) => {
  ws.alive = true;
  ws.pid = 'anon' + Math.random().toString(36).slice(2, 10);
  ws.pname = 'Player';
  ws.on('pong', () => (ws.alive = true));

  ws.on('message', (raw) => {
    let m;
    try {
      m = JSON.parse(raw);
    } catch (e) {
      return;
    }
    switch (m.t) {
      case 'hello': {
        ws.pid = String(m.id || ws.pid).slice(0, 40);
        ws.pname = String(m.name || 'Player').slice(0, 16);
        const p = player(ws.pid, ws.pname);
        send(ws, { t: 'hi', r: p.r, n: p.n });
        break;
      }
      case 'quick':
        quick(ws, clampTc(m));
        break;
      case 'join': {
        leaveQueues(ws);
        const id = String(m.room || '').toUpperCase().slice(0, 12);
        if (!id) return;
        const r = rooms.get(id);
        if (r && r.ws !== ws && r.ws.readyState === 1) {
          rooms.delete(id);
          r.ws.roomId = null;
          startGame(r.ws, ws, r.min, r.inc);
        } else {
          const tc = clampTc(m);
          rooms.set(id, { ws, min: tc.min, inc: tc.inc });
          ws.roomId = id;
          send(ws, { t: 'waiting' });
        }
        break;
      }
      case 'cancel':
        leaveQueues(ws);
        break;
      case 'move':
        onMove(ws, m);
        break;
      case 'resign': {
        const g = ws.game;
        if (g && !g.over) finish(g, ws.side === 'w' ? '0-1' : '1-0', 'resign');
        break;
      }
      case 'draw_offer': {
        const g = ws.game;
        if (g && !g.over && g.moves >= 2) {
          g.offer = ws.side;
          send(oppOf(ws), { t: 'draw_offer' });
        }
        break;
      }
      case 'draw_accept': {
        const g = ws.game;
        if (g && !g.over && g.offer && g.offer !== ws.side) finish(g, '1/2-1/2', 'agreement');
        break;
      }
      case 'draw_decline': {
        const g = ws.game;
        if (g && g.offer && g.offer !== ws.side) {
          g.offer = null;
          send(oppOf(ws), { t: 'draw_declined' });
        }
        break;
      }
      case 'rematch': {
        const o = ws.lastOpp;
        if (!o || ws.game || o.game || o.readyState !== 1) return;
        ws.rematch = true;
        if (o.rematch && o.lastOpp === ws) {
          ws.rematch = false;
          o.rematch = false;
          const tc = ws.lastTc || { min: 10, inc: 0 };
          // swap colors: whoever was white is black now
          startGame(ws, o, tc.min, tc.inc, ws.lastSide === 'b');
        } else {
          send(o, { t: 'rematch_offer' });
        }
        break;
      }
      case 'top': {
        const c = CATS.includes(m.cat) ? m.cat : 'blitz';
        const list = Object.values(db)
          .filter((p) => p.n && p.n[c] > 0)
          .sort((a, b) => b.r[c] - a.r[c])
          .slice(0, 20)
          .map((p) => ({ name: p.name, r: p.r[c], n: p.n[c] }));
        send(ws, { t: 'top', cat: c, list });
        break;
      }
    }
  });

  ws.on('close', () => {
    leaveQueues(ws);
    const g = ws.game;
    if (g && !g.over) {
      if (g.moves < 2) finish(g, '*', 'aborted');
      else finish(g, ws.side === 'w' ? '0-1' : '1-0', 'abandon');
    }
  });
});

setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.alive) return ws.terminate();
    ws.alive = false;
    ws.ping();
  });
}, 25000);

console.log('chess server v2 running');
