// Bluetooth game backend. It speaks the same message protocol as the online
// backend, so the game screen works unchanged. Moves travel directly between
// the two phones; there is no server and no rating.
import 'dart:async';
import 'dart:math';
import 'backend_api.dart';
import 'link_impl.dart';

Backend createBtBackend() => BtBackend();

int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;

class BtBackend implements Backend {
  void Function(Map m)? _emit;
  late LinkApi _link;
  String _myName = 'Player';
  String _peerName = 'Friend';
  int _min = 10;
  int _inc = 0;
  bool _isHost = false;
  bool _linked = false;
  final Map<String, String> _peers = {};

  bool _gameOn = false;
  bool _ended = false;
  String _side = 'w';
  int _n = 0;
  int _wt = 0;
  int _bt = 0;
  DateTime _turnStart = DateTime.now();
  String? _offer;
  bool _myRematch = false;
  bool _peerRematch = false;
  Timer? _timer;

  @override
  bool get connected => _linked;

  void _e(Map m) => _emit?.call(m);

  @override
  void start(void Function(Map m) emit) {
    _emit = emit;
    _link = createLink();
    _link.onEvent = _onLink;
  }

  @override
  void stop() {
    _timer?.cancel();
    _gameOn = false;
    _linked = false;
    try {
      _link.stop();
    } catch (_) {}
  }

  @override
  void send(Map m) {
    switch (m['t']) {
      case 'bt_host':
        _isHost = true;
        _myName = (m['name'] ?? 'Player').toString();
        _min = _i(m['min'], 10);
        _inc = _i(m['inc']);
        _peers.clear();
        _link.host(_myName);
        break;
      case 'bt_search':
        _isHost = false;
        _myName = (m['name'] ?? 'Player').toString();
        _peers.clear();
        _link.search(_myName);
        break;
      case 'bt_connect':
        _isHost = false;
        _myName = (m['name'] ?? _myName).toString();
        _e({'t': 'bt_status', 'text': 'جاري الاتصال...'});
        _link.connect((m['id'] ?? '').toString(), _myName);
        break;
      case 'bt_stop':
        stop();
        break;
      case 'move':
        _myMove(m);
        break;
      case 'resign':
        _finish(_side == 'w' ? '0-1' : '1-0', 'resign', notify: true);
        break;
      case 'game_over':
        _finish((m['result'] ?? '*').toString(), (m['reason'] ?? '').toString(),
            notify: true);
        break;
      case 'draw_offer':
        if (_gameOn && !_ended && _n >= 2) {
          _offer = _side;
          _link.send({'k': 'draw_offer'});
        }
        break;
      case 'draw_accept':
        if (_offer != null && _offer != _side) {
          _finish('1/2-1/2', 'agreement', notify: true);
        }
        break;
      case 'draw_decline':
        if (_offer != null && _offer != _side) {
          _offer = null;
          _link.send({'k': 'draw_decline'});
        }
        break;
      case 'chat':
        final ci = _i(m['i'], -1);
        if (ci >= 0 && ci < 8) _link.send({'k': 'chat', 'i': ci});
        break;
      case 'rematch':
        _myRematch = true;
        _link.send({'k': 'rematch'});
        _maybeRematch();
        break;
      case 'leave':
        _link.send({'k': 'bye'});
        _gameOn = false;
        _timer?.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          try {
            _link.stop();
          } catch (_) {}
        });
        break;
    }
  }

  // ───────── link events ─────────
  void _emitPeers() {
    _e({
      't': 'bt_peers',
      'list': [
        for (final en in _peers.entries) {'id': en.key, 'name': en.value}
      ]
    });
  }

  void _onLink(String type, Map data) {
    switch (type) {
      case 'status':
        _e({'t': 'bt_status', 'text': (data['text'] ?? '').toString()});
        break;
      case 'peer_found':
        _peers[(data['id'] ?? '').toString()] = (data['name'] ?? '?').toString();
        _emitPeers();
        break;
      case 'peer_lost':
        _peers.remove((data['id'] ?? '').toString());
        _emitPeers();
        break;
      case 'connected':
        _linked = true;
        final n = (data['name'] ?? '').toString();
        if (n.isNotEmpty) _peerName = n;
        if (_isHost) {
          final hostWhite = Random().nextBool();
          _side = hostWhite ? 'w' : 'b';
          _link.send({
            'k': 'start',
            'color': hostWhite ? 'b' : 'w',
            'host': _myName,
            'min': _min,
            'inc': _inc,
          });
          _beginGame();
        } else {
          _e({'t': 'bt_status', 'text': 'تم الاتصال، بانتظار بدء المباراة...'});
        }
        break;
      case 'data':
        final msg = data['msg'];
        if (msg is Map) _onPeer(Map<String, dynamic>.from(msg));
        break;
      case 'disconnected':
        _peerGone();
        break;
      case 'error':
        _e({'t': 'bt_error', 'msg': (data['msg'] ?? '').toString()});
        break;
    }
  }

  void _peerGone() {
    _linked = false;
    if (_gameOn && !_ended) {
      _finish(_side == 'w' ? '1-0' : '0-1', 'abandon', notify: false);
    } else {
      _e({'t': 'bt_status', 'text': 'انقطع الاتصال'});
    }
  }

  void _onPeer(Map<String, dynamic> m) {
    switch (m['k']) {
      case 'start':
        _side = m['color'] == 'b' ? 'b' : 'w';
        final h = (m['host'] ?? '').toString();
        if (h.isNotEmpty) _peerName = h;
        _min = _i(m['min'], 10);
        _inc = _i(m['inc']);
        _beginGame();
        break;
      case 'move':
        if (!_gameOn || _ended) return;
        _n++;
        _wt = _i(m['wt'], _wt);
        _bt = _i(m['bt'], _bt);
        _turnStart = DateTime.now();
        _offer = null;
        _e({
          't': 'move',
          'from': m['from'],
          'to': m['to'],
          'promo': m['promo'],
          'wt': _wt,
          'bt': _bt,
        });
        break;
      case 'end':
        _finish((m['result'] ?? '*').toString(), (m['reason'] ?? '').toString(),
            notify: false);
        break;
      case 'draw_offer':
        _offer = _side == 'w' ? 'b' : 'w';
        _e({'t': 'draw_offer'});
        break;
      case 'draw_decline':
        _offer = null;
        _e({'t': 'draw_declined'});
        break;
      case 'chat':
        _e({'t': 'chat', 'i': _i(m['i'])});
        break;
      case 'rematch':
        _peerRematch = true;
        _e({'t': 'rematch_offer'});
        _maybeRematch();
        break;
      case 'bye':
        _peerGone();
        break;
    }
  }

  // ───────── game ─────────
  void _beginGame() {
    _gameOn = true;
    _ended = false;
    _n = 0;
    _wt = _min * 60000;
    _bt = _min * 60000;
    _offer = null;
    _myRematch = false;
    _peerRematch = false;
    _turnStart = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    final t = _min * 60 + _inc * 40;
    _e({
      't': 'start',
      'bt': true,
      'color': _side,
      'opp': {'name': _peerName, 'rating': 0, 'tier': 0},
      'you': {'rating': 0},
      'min': _min,
      'inc': _inc,
      'cat': t < 180 ? 'bullet' : (t < 600 ? 'blitz' : 'rapid'),
    });
  }

  void _maybeRematch() {
    if (_myRematch && _peerRematch && _isHost && _ended) {
      _side = _side == 'w' ? 'b' : 'w';
      _link.send({
        'k': 'start',
        'color': _side == 'w' ? 'b' : 'w',
        'host': _myName,
        'min': _min,
        'inc': _inc,
      });
      _beginGame();
    }
  }

  void _myMove(Map m) {
    if (!_gameOn || _ended) return;
    final turn = _n % 2 == 0 ? 'w' : 'b';
    if (turn != _side) return;
    int wt = _wt;
    int bt = _bt;
    final inc = _inc * 1000;
    if (_n >= 1) {
      final used = DateTime.now().difference(_turnStart).inMilliseconds;
      if (_side == 'w') {
        wt -= used;
      } else {
        bt -= used;
      }
      if ((_side == 'w' ? wt : bt) <= 0) {
        _finish(_side == 'w' ? '0-1' : '1-0', 'timeout', notify: true);
        return;
      }
    }
    if (_side == 'w') {
      wt += inc;
    } else {
      bt += inc;
    }
    _wt = wt;
    _bt = bt;
    _n++;
    _turnStart = DateTime.now();
    _offer = null;
    final promo = m['promo'];
    _link.send({
      'k': 'move',
      'from': m['from'],
      'to': m['to'],
      'promo': promo,
      'wt': wt,
      'bt': bt,
    });
    _e({'t': 'clock', 'wt': wt, 'bt': bt});
  }

  void _tick() {
    if (!_gameOn || _ended || _n < 1) return;
    final turn = _n % 2 == 0 ? 'w' : 'b';
    final base = turn == 'w' ? _wt : _bt;
    final rem = base - DateTime.now().difference(_turnStart).inMilliseconds;
    if (rem < -1500) {
      _finish(turn == 'w' ? '0-1' : '1-0', 'timeout', notify: true);
    }
  }

  void _finish(String result, String reason, {required bool notify}) {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    if (notify) {
      _link.send({'k': 'end', 'result': result, 'reason': reason});
    }
    _e({
      't': 'end',
      'result': result,
      'reason': reason,
      'delta': 0,
      'rating': 0,
      'rated': false,
    });
  }
}
