// Chess server v3
// - matchmaking by time control, server-side move validation + clocks
// - Elo per category (bullet / blitz / rapid)
// - friends (codes, requests, presence) + friend challenges
// - reconnect / resume (30s grace), quick chat
// - subscription gift codes (admin endpoint) + plan tier
const http = require('http');
const { WebSocketServer } = require('ws');
const { Chess } = require('chess.js');
const fs = require('fs');
const crypto = require('crypto');

const FILE = process.env.RATINGS_FILE || './ratings.json';
const ADMIN_KEY = process.env.ADMIN_KEY || '';
let store = { players: {}, codes: {} };
try {
  const raw = JSON.parse(fs.readFileSync(FILE, 'utf8'));
  if (raw && raw.players) store = raw;
  else if (raw) store.players = raw;
} catch (e) {}
if (!store.codes) store.codes = {};
const db = store.players;
let dirty = false;
function flush() {
  if (!dirty) return;
  try {
    fs.writeFileSync(FILE, JSON.stringify(store));
  } catch (e) {}
  dirty = false;
}
setInterval(flush, 15000);
process.on('SIGTERM', () => {
  flush();
  process.exit(0);
});

const START = 800;
const CATS = ['bullet', 'blitz', 'rapid'];
const FRIEND_LIMIT = [10, 30, 100, 300];
const ALPHA = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function randStr(n) {
  let s = '';
  for (let i = 0; i < n; i++) s += ALPHA[crypto.randomInt(ALPHA.length)];
  return s;
}
function newFriendCode() {
  for (;;) {
    const c = randStr(6);
    if (!Object.values(db).some((p) => p.code === c)) return c;
  }
}
function findByCode(code) {
  return Object.keys(db).find((k) => db[k].code === code);
}

function player(id, name) {
  let p = db[id];
  if (!p) {
    p = db[id] = {
      name: name || 'Player',
      r: { bullet: START, blitz: START, rapid: START },
      n: { bullet: 0, blitz: 0, rapid: 0 },
    };
  } else if (name) {
    p.name = name;
  }
  if (!p.code) p.code = newFriendCode();
  p.friends = p.friends || [];
  p.reqIn = p.reqIn || [];
  p.reqOut = p.reqOut || [];
  dirty = true;
  return p;
}

const online = new Map(); // pid -> ws
const active = new Map(); // pid -> game
const queues = new Map(); // "min+inc" -> [ws]
const rooms = new Map(); // room id -> {ws,min,inc}
const challenges = new Map(); // cid -> {cid,from,to,min,inc,timer}
let gidSeq = 1;
let cidSeq = 1;

const send = (ws, o) => {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(o));
};
const clamp = (v, a, b, d) => {
  const n = parseInt(v);
  return Math.max(a, Math.min(b, isNaN(n) ? d : n));
};
const clampTc = (m) => ({ min: clamp(m.min, 1, 60, 10), inc: clamp(m.inc, 0, 30, 0) });
const catOf = (min, inc) => {
  const t = min * 60 + inc * 40;
  return t < 180 ? 'bullet' : t < 600 ? 'blitz' : 'rapid';
};
function elo(ra, rb, score, games) {
  const e = 1 / (1 + Math.pow(10, (rb - ra) / 400));
  const k = games < 10 ? 40 : ra < 2200 ? 24 : 16;
  return Math.round(k * (score - e));
}
const planTier = (pid) => {
  const p = db[pid];
  return p && p.plan && p.plan.until > Date.now() ? p.plan.tier : 0;
};
const tierOf = (pid) => {
  const w = online.get(pid);
  const claimed = w ? w.stier | 0 : 0;
  return Math.max(planTier(pid), Math.min(3, Math.max(0, claimed)));
};
const oppOf = (ws) => {
  const g = ws.game;
  if (!g) return null;
  return g.w === ws ? g.b : g.w;
};

// ───────── friends ─────────
function friendsPayload(pid) {
  const p = player(pid);
  const info = (fid) => {
    const f = db[fid];
    const w = online.get(fid);
    return {
      id: fid,
      name: f ? f.name : '?',
      online: !!(w && w.readyState === 1),
      inGame: !!(w && w.game),
      r: f ? f.r : {},
      tier: tierOf(fid),
    };
  };
  return {
    t: 'friends',
    code: p.code,
    list: p.friends.map(info),
    reqIn: p.reqIn.map((id) => ({ id, name: db[id] ? db[id].name : '?' })),
    reqOut: p.reqOut.map((id) => ({ id, name: db[id] ? db[id].name : '?' })),
  };
}
function pushFriends(pid) {
  const w = online.get(pid);
  if (w) send(w, friendsPayload(pid));
}
function presence(pid, on) {
  const p = db[pid];
  if (!p) return;
  p.friends.forEach((fid) => {
    const w = online.get(fid);
    if (w) send(w, { t: 'presence', id: pid, online: on });
  });
}
function removeFrom(arr, v) {
  const i = arr.indexOf(v);
  if (i >= 0) arr.splice(i, 1);
}
function makeFriends(a, b) {
  const pa = player(a),
    pb = player(b);
  if (!pa.friends.includes(b)) pa.friends.push(b);
  if (!pb.friends.includes(a)) pb.friends.push(a);
  removeFrom(pa.reqIn, b);
  removeFrom(pa.reqOut, b);
  removeFrom(pb.reqIn, a);
  removeFrom(pb.reqOut, a);
  dirty = true;
  pushFriends(a);
  pushFriends(b);
}

// ───────── games ─────────
function startGame(a, b, min, inc, aWhite) {
  if (aWhite === undefined) aWhite = Math.random() < 0.5;
  const w = aWhite ? a : b;
  const bl = aWhite ? b : a;
  const c = catOf(min, inc);
  const g = {
    id: gidSeq++,
    w,
    b: bl,
    wp: w.pid,
    bp: bl.pid,
    chess: new Chess(),
    ucis: [],
    min,
    inc,
    cat: c,
    clocks: { w: min * 60000, b: min * 60000 },
    last: Date.now(),
    moves: 0,
    over: false,
    timer: null,
    grace: { w: null, b: null },
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
  active.set(g.wp, g);
  active.set(g.bp, g);
  send(w, { t: 'start', color: 'w', opp: { name: bl.pname, rating: g.rb, tier: tierOf(bl.pid) }, you: { rating: g.rw }, min, inc, cat: c });
  send(bl, { t: 'start', color: 'b', opp: { name: w.pname, rating: g.rw, tier: tierOf(w.pid) }, you: { rating: g.rb }, min, inc, cat: c });
  armTimer(g);
}

function liveClocks(g) {
  const c = { w: g.clocks.w, b: g.clocks.b };
  if (g.moves >= 1 && !g.over) {
    const t = g.chess.turn();
    c[t] = Math.max(0, c[t] - (Date.now() - g.last));
  }
  return c;
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
  clearTimeout(g.grace.w);
  clearTimeout(g.grace.b);
  active.delete(g.wp);
  active.delete(g.bp);
  const rated = g.moves >= 2 && result !== '*';
  let dw = 0,
    dbk = 0,
    nw = g.rw,
    nb = g.rb;
  if (rated) {
    const sw = result === '1-0' ? 1 : result === '0-1' ? 0 : 0.5;
    const pw = player(g.wp);
    const pb = player(g.bp);
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
  let mv;
  try {
    mv = g.chess.move({ from: m.from, to: m.to, promotion: m.promo || 'q' });
  } catch (e) {
    return send(ws, { t: 'illegal' });
  }
  g.ucis.push(mv.from + mv.to + (mv.promotion || ''));
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

function rebind(ws, g) {
  const side = g.wp === ws.pid ? 'w' : 'b';
  clearTimeout(g.grace[side]);
  g.grace[side] = null;
  const old = side === 'w' ? g.w : g.b;
  if (old && old !== ws) {
    old.game = null;
    try {
      old.close();
    } catch (e) {}
  }
  if (side === 'w') g.w = ws;
  else g.b = ws;
  ws.game = g;
  ws.side = side;
  const o = oppOf(ws);
  send(o, { t: 'opp_back' });
  const c = liveClocks(g);
  const oppPid = side === 'w' ? g.bp : g.wp;
  send(ws, {
    t: 'resume',
    color: side,
    fen: g.chess.fen(),
    moves: g.ucis,
    wt: c.w,
    bt: c.b,
    opp: { name: db[oppPid] ? db[oppPid].name : '?', rating: side === 'w' ? g.rb : g.rw, tier: tierOf(oppPid) },
    you: { rating: side === 'w' ? g.rw : g.rb },
    min: g.min,
    inc: g.inc,
    cat: g.cat,
  });
}

// ───────── queues / rooms ─────────
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
    if (o !== ws && o.pid !== ws.pid) {
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

function dropChallenge(c) {
  clearTimeout(c.timer);
  challenges.delete(c.cid);
}

// ───────── http (health + admin gift codes) ─────────
const server = http.createServer((req, res) => {
  let u;
  try {
    u = new URL(req.url, 'http://x');
  } catch (e) {
    res.writeHead(400);
    return res.end('bad');
  }
  if (u.pathname === '/admin/code') {
    if (!ADMIN_KEY || u.searchParams.get('key') !== ADMIN_KEY) {
      res.writeHead(403);
      return res.end('forbidden');
    }
    const tier = clamp(u.searchParams.get('tier'), 1, 3, 1);
    const days = clamp(u.searchParams.get('days'), 1, 3650, 30);
    const n = clamp(u.searchParams.get('n'), 1, 50, 1);
    const out = [];
    for (let i = 0; i < n; i++) {
      const c = randStr(4) + '-' + randStr(4) + '-' + randStr(4);
      store.codes[c] = { tier, days, used: null, at: Date.now() };
      out.push(c);
    }
    dirty = true;
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    return res.end(out.join('\n'));
  }
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('chess server ok');
});

const wss = new WebSocketServer({ server });
server.listen(process.env.PORT || 8080);

wss.on('connection', (ws) => {
  ws.alive = true;
  ws.pid = 'anon' + Math.random().toString(36).slice(2, 10);
  ws.pname = 'Player';
  ws.stier = 0;
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
        ws.stier = clamp(m.stier, 0, 3, 0);
        const p = player(ws.pid, ws.pname);
        const prev = online.get(ws.pid);
        online.set(ws.pid, ws);
        const plan = p.plan && p.plan.until > Date.now() ? p.plan : null;
        send(ws, { t: 'hi', r: p.r, n: p.n, code: p.code, tier: plan ? plan.tier : 0, until: plan ? plan.until : 0 });
        if (!prev || prev === ws) presence(ws.pid, true);
        const g = active.get(ws.pid);
        if (g && !g.over) rebind(ws, g);
        else if (m.ig) send(ws, { t: 'no_game' });
        break;
      }
      case 'friends':
        send(ws, friendsPayload(ws.pid));
        break;
      case 'friend_add': {
        const me = player(ws.pid);
        const tid = findByCode(String(m.code || '').toUpperCase().trim());
        if (!tid) return send(ws, { t: 'friend_err', msg: 'كود غير صحيح' });
        if (tid === ws.pid) return send(ws, { t: 'friend_err', msg: 'هذا كودك أنت' });
        const t = player(tid);
        if (me.friends.includes(tid)) return send(ws, { t: 'friend_err', msg: 'هو صديقك بالفعل' });
        if (me.friends.length >= FRIEND_LIMIT[tierOf(ws.pid)]) return send(ws, { t: 'friend_err', msg: 'وصلت للحد الأقصى للأصدقاء، رقِّ اشتراكك لزيادته' });
        if (me.reqIn.includes(tid)) return makeFriends(ws.pid, tid);
        if (!t.reqIn.includes(ws.pid)) t.reqIn.push(ws.pid);
        if (!me.reqOut.includes(tid)) me.reqOut.push(tid);
        dirty = true;
        pushFriends(ws.pid);
        pushFriends(tid);
        const tw = online.get(tid);
        if (tw) send(tw, { t: 'friend_req', name: me.name });
        send(ws, { t: 'friend_ok', msg: 'تم إرسال طلب الصداقة' });
        break;
      }
      case 'friend_accept': {
        const me = player(ws.pid);
        const id = String(m.id || '');
        if (!me.reqIn.includes(id)) return;
        if (me.friends.length >= FRIEND_LIMIT[tierOf(ws.pid)]) return send(ws, { t: 'friend_err', msg: 'وصلت للحد الأقصى للأصدقاء' });
        if (player(id).friends.length >= FRIEND_LIMIT[tierOf(id)]) return send(ws, { t: 'friend_err', msg: 'الطرف الآخر وصل للحد الأقصى للأصدقاء' });
        makeFriends(ws.pid, id);
        const w = online.get(id);
        if (w) send(w, { t: 'friend_ok', msg: me.name + ' قبل طلب صداقتك' });
        break;
      }
      case 'friend_decline': {
        const me = player(ws.pid);
        const id = String(m.id || '');
        removeFrom(me.reqIn, id);
        if (db[id]) removeFrom(db[id].reqOut, ws.pid);
        dirty = true;
        pushFriends(ws.pid);
        pushFriends(id);
        break;
      }
      case 'friend_remove': {
        const me = player(ws.pid);
        const id = String(m.id || '');
        removeFrom(me.friends, id);
        if (db[id]) removeFrom(db[id].friends, ws.pid);
        dirty = true;
        pushFriends(ws.pid);
        pushFriends(id);
        break;
      }
      case 'challenge': {
        const me = player(ws.pid);
        const tid = String(m.to || '');
        if (!me.friends.includes(tid)) return send(ws, { t: 'challenge_err', msg: 'هذا اللاعب ليس في أصدقائك' });
        if (ws.game || active.has(ws.pid)) return send(ws, { t: 'challenge_err', msg: 'أنت في مباراة الآن' });
        const tw = online.get(tid);
        if (!tw || tw.readyState !== 1) return send(ws, { t: 'challenge_err', msg: 'صديقك غير متصل' });
        if (tw.game || active.has(tid)) return send(ws, { t: 'challenge_err', msg: 'صديقك في مباراة الآن' });
        const tc = clampTc(m);
        const cid = cidSeq++;
        const c = { cid, from: ws.pid, to: tid, min: tc.min, inc: tc.inc, timer: null };
        c.timer = setTimeout(() => {
          if (challenges.has(cid)) {
            challenges.delete(cid);
            send(ws, { t: 'challenge_declined', name: 'انتهت مهلة الطلب' });
            send(tw, { t: 'challenge_cancelled', cid });
          }
        }, 60000);
        challenges.set(cid, c);
        send(tw, { t: 'challenge', cid, from: { id: ws.pid, name: me.name }, min: tc.min, inc: tc.inc });
        send(ws, { t: 'challenge_sent', cid });
        break;
      }
      case 'challenge_accept': {
        const c = challenges.get(m.cid);
        if (!c || c.to !== ws.pid) return send(ws, { t: 'challenge_err', msg: 'انتهى الطلب' });
        dropChallenge(c);
        const fw = online.get(c.from);
        if (!fw || fw.readyState !== 1 || fw.game || ws.game) return send(ws, { t: 'challenge_err', msg: 'تعذر بدء المباراة' });
        leaveQueues(fw);
        leaveQueues(ws);
        startGame(fw, ws, c.min, c.inc);
        break;
      }
      case 'challenge_decline': {
        const c = challenges.get(m.cid);
        if (!c || c.to !== ws.pid) return;
        dropChallenge(c);
        send(online.get(c.from), { t: 'challenge_declined', name: ws.pname });
        break;
      }
      case 'quick':
        if (active.has(ws.pid)) return;
        quick(ws, clampTc(m));
        break;
      case 'join': {
        if (active.has(ws.pid)) return;
        leaveQueues(ws);
        const id = String(m.room || '').toUpperCase().slice(0, 12);
        if (!id) return;
        const r = rooms.get(id);
        if (r && r.ws !== ws && r.ws.pid !== ws.pid && r.ws.readyState === 1) {
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
      case 'chat': {
        const g = ws.game;
        if (g && Number.isInteger(m.i) && m.i >= 0 && m.i < 8) send(oppOf(ws), { t: 'chat', i: m.i });
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
          startGame(ws, o, tc.min, tc.inc, ws.lastSide === 'b');
        } else {
          send(o, { t: 'rematch_offer' });
        }
        break;
      }
      case 'redeem': {
        const code = String(m.code || '').toUpperCase().trim();
        const c = store.codes[code];
        if (!c || c.used) return send(ws, { t: 'plan_err', msg: 'الكود غير صالح أو مستخدم من قبل' });
        c.used = ws.pid;
        const p = player(ws.pid);
        const now = Date.now();
        const act = p.plan && p.plan.until > now;
        let tier = c.tier,
          until;
        if (act && p.plan.tier >= c.tier) {
          tier = p.plan.tier;
          until = p.plan.until + c.days * 86400000;
        } else {
          until = now + c.days * 86400000;
        }
        p.plan = { tier, until };
        dirty = true;
        send(ws, { t: 'plan', tier, until });
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
    if (online.get(ws.pid) === ws) {
      online.delete(ws.pid);
      presence(ws.pid, false);
    }
    leaveQueues(ws);
    for (const c of Array.from(challenges.values())) {
      if (c.from === ws.pid) {
        dropChallenge(c);
        send(online.get(c.to), { t: 'challenge_cancelled', cid: c.cid });
      }
    }
    const g = ws.game;
    if (g && !g.over && (g.w === ws || g.b === ws)) {
      if (g.moves < 2) {
        finish(g, '*', 'aborted');
        return;
      }
      const side = ws.side;
      send(oppOf(ws), { t: 'opp_disc' });
      clearTimeout(g.grace[side]);
      g.grace[side] = setTimeout(() => {
        if (!g.over) finish(g, side === 'w' ? '0-1' : '1-0', 'abandon');
      }, 30000);
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

console.log('chess server v3 running');
