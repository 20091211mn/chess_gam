// Simple chess relay server: pairs two players and forwards moves.
const { WebSocketServer } = require('ws');

const wss = new WebSocketServer({ port: process.env.PORT || 8080 });
const rooms = new Map(); // room id -> waiting socket
let waiting = null; // quick-match waiting socket

const send = (ws, o) => {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(o));
};

function pair(a, b) {
  const aWhite = Math.random() < 0.5;
  a.opp = b;
  b.opp = a;
  send(a, { t: 'start', color: aWhite ? 'w' : 'b' });
  send(b, { t: 'start', color: aWhite ? 'b' : 'w' });
}

wss.on('connection', (ws) => {
  ws.alive = true;
  ws.on('pong', () => (ws.alive = true));

  ws.on('message', (raw) => {
    let m;
    try {
      m = JSON.parse(raw);
    } catch {
      return;
    }
    if (m.t === 'quick') {
      if (waiting && waiting !== ws && waiting.readyState === 1) {
        const w = waiting;
        waiting = null;
        pair(w, ws);
      } else {
        waiting = ws;
        send(ws, { t: 'waiting' });
      }
    } else if (m.t === 'join') {
      const id = String(m.room || '').toUpperCase().slice(0, 12);
      if (!id) return;
      const w = rooms.get(id);
      if (w && w !== ws && w.readyState === 1) {
        rooms.delete(id);
        w.waitId = null;
        pair(w, ws);
      } else {
        rooms.set(id, ws);
        ws.waitId = id;
        send(ws, { t: 'waiting' });
      }
    } else if (ws.opp && (m.t === 'move' || m.t === 'resign')) {
      send(ws.opp, m);
    }
  });

  ws.on('close', () => {
    if (waiting === ws) waiting = null;
    if (ws.waitId && rooms.get(ws.waitId) === ws) rooms.delete(ws.waitId);
    if (ws.opp) {
      send(ws.opp, { t: 'left' });
      ws.opp.opp = null;
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

console.log('chess server running');
