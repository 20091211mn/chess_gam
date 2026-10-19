// Online backend on Firebase (Auth + Firestore).
// It speaks the same small message protocol the app already uses, so the
// screens do not care whether the other side is a server or Firebase.
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'backend_api.dart';
import 'firebase_options_gen.dart';

typedef Json = Map<String, dynamic>;

Backend createBackend() => FirebaseBackend();

const List<int> _friendLimit = [10, 30, 100, 300];

int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
int _nowMs() => DateTime.now().millisecondsSinceEpoch;

String _catOf(int min, int inc) {
  final t = min * 60 + inc * 40;
  return t < 180 ? 'bullet' : (t < 600 ? 'blitz' : 'rapid');
}

int _elo(int ra, int rb, double score, int games) {
  final e = 1 / (1 + pow(10, (rb - ra) / 400));
  final k = games < 10 ? 40 : (ra < 2200 ? 24 : 16);
  return (k * (score - e)).round();
}

class FirebaseBackend implements Backend {
  void Function(Map m)? _emit;
  bool _up = false;
  bool _booted = false;
  bool _listening = false;
  final List<Map> _pendingMsgs = [];
  Future<void> _chain = Future.value();

  late FirebaseFirestore _db;
  String _uid = '';
  String _name = 'Player';
  int _stier = 0;
  Json _me = {};
  String _code = '';

  final List<StreamSubscription> _subs = [];
  Timer? _beat;
  int _beatN = 0;

  // friends
  List<Json> _inReqs = [];
  List<Json> _outReqs = [];
  bool _inInit = false;
  final Map<String, Json> _users = {};

  // matchmaking
  StreamSubscription? _qsub;
  Timer? _qtimer;
  bool _pairing = false;
  bool _joining = false;

  // challenge I sent
  StreamSubscription? _csub;
  Timer? _ctimer;
  String? _myChallenge;
  final Set<String> _seenChallenges = {};

  // current game
  String? _gid;
  DocumentReference<Json>? _gref;
  StreamSubscription? _gsub;
  Timer? _gtimer;
  String _side = 'w';
  int _nMoves = 0;
  Json _gd = {};
  DateTime _turnStart = DateTime.now();
  String? _lastOffer;
  int _chatN = 0;
  bool _ended = false;
  bool _endBusy = false;
  bool _oppAway = false;
  bool _rematchSeen = false;
  String? _nextSeen;
  int _tickN = 0;

  @override
  bool get connected => _up;

  void _e(Map m) => _emit?.call(m);

  @override
  void start(void Function(Map m) emit) {
    _emit = emit;
    _boot();
  }

  @override
  void send(Map m) {
    if (!_booted) {
      _pendingMsgs.add(m);
      return;
    }
    _handle(m);
  }

  @override
  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _beat?.cancel();
    _qsub?.cancel();
    _qtimer?.cancel();
    _csub?.cancel();
    _ctimer?.cancel();
    _leaveGame();
    _listening = false;
    _up = false;
  }

  Future<void> _boot() async {
    if (!firebaseConfigured) {
      _e({
        't': 'unavailable',
        'msg': 'Firebase غير مُعدّ بعد (ملف google-services.json غير موجود)'
      });
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
      }
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      user ??= (await auth.signInAnonymously()).user;
      _uid = user!.uid;
      _db = FirebaseFirestore.instance;
      _booted = true;
      final copy = List<Map>.from(_pendingMsgs);
      _pendingMsgs.clear();
      for (final m in copy) {
        _handle(m);
      }
    } catch (e) {
      _e({'t': 'unavailable', 'msg': 'تعذر الاتصال بـ Firebase: $e'});
    }
  }

  void _handle(Map m) {
    _chain = _chain.then((_) async {
      try {
        await _dispatch(m);
      } catch (e) {
        _e({'t': 'friend_err', 'msg': 'خطأ: $e'});
      }
    });
  }

  Future<void> _dispatch(Map m) async {
    switch (m['t']) {
      case 'hello':
        await _hello(m);
        break;
      case 'friends':
        await _pushFriends(refresh: true);
        break;
      case 'friend_add':
        await _friendAdd(m);
        break;
      case 'friend_accept':
        await _friendAccept(m);
        break;
      case 'friend_decline':
        await _friendDecline(m);
        break;
      case 'friend_remove':
        await _friendRemove(m);
        break;
      case 'challenge':
        await _challenge(m);
        break;
      case 'challenge_accept':
        await _challengeAccept(m);
        break;
      case 'challenge_decline':
        await _challengeDecline(m);
        break;
      case 'quick':
        await _search(_i(m['min'], 10), _i(m['inc']));
        break;
      case 'join':
        await _search(_i(m['min'], 10), _i(m['inc']),
            room: (m['room'] ?? '').toString().toUpperCase().trim());
        break;
      case 'cancel':
        await _cancelSearch();
        break;
      case 'move':
        await _move(m);
        break;
      case 'resign':
        await _endGame(_side == 'w' ? '0-1' : '1-0', 'resign');
        break;
      case 'game_over':
        await _endGame(
            (m['result'] ?? '*').toString(), (m['reason'] ?? '').toString());
        break;
      case 'draw_offer':
        if (_nMoves >= 2 && _gd['status'] == 'active') {
          await _gameUpdate({'offer': _side});
        }
        break;
      case 'draw_accept':
        if (_gd['offer'] != null && _gd['offer'] != _side) {
          await _endGame('1/2-1/2', 'agreement');
        }
        break;
      case 'draw_decline':
        if (_gd['offer'] != null && _gd['offer'] != _side) {
          await _gameUpdate({'offer': null});
        }
        break;
      case 'chat':
        final ci = _i(m['i'], -1);
        if (ci >= 0 && ci < 8) {
          await _gameUpdate({
            'chat': {'n': _nowMs(), 'i': ci, 'by': _side}
          });
        }
        break;
      case 'rematch':
        await _rematch();
        break;
      case 'leave':
        _leaveGame();
        break;
      case 'redeem':
        await _redeem(m);
        break;
      case 'top':
        await _top(m);
        break;
    }
  }

  // ───────────── profile ─────────────
  List<int> _plan() {
    final p = _me['plan'];
    if (p is Map) {
      final until = _i(p['until']);
      if (until > _nowMs()) return [_i(p['tier']), until];
    }
    return [0, 0];
  }

  int _myTier() {
    final t = _plan()[0];
    final s = _stier.clamp(0, 3).toInt();
    return t > s ? t : s;
  }

  int _tierOfUser(Json u) {
    final p = u['plan'];
    int t = 0;
    if (p is Map && _i(p['until']) > _nowMs()) t = _i(p['tier']);
    final s = _i(u['stier']).clamp(0, 3).toInt();
    return t > s ? t : s;
  }

  Future<String> _newCode() async {
    const alpha = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    for (int k = 0; k < 20; k++) {
      final code =
          List.generate(6, (_) => alpha[rnd.nextInt(alpha.length)]).join();
      final ref = _db.collection('codes').doc(code);
      final s = await ref.get();
      if (!s.exists) {
        await ref.set({'uid': _uid});
        return code;
      }
    }
    return 'X${_nowMs() % 100000}';
  }

  Future<void> _ensureProfile() async {
    final ref = _db.collection('users').doc(_uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final code = await _newCode();
      await ref.set({
        'name': _name,
        'code': code,
        'r': {'bullet': 800, 'blitz': 800, 'rapid': 800},
        'n': {'bullet': 0, 'blitz': 0, 'rapid': 0},
        'seen': _nowMs(),
        'plan': null,
        'gid': null,
        'stier': _stier,
      });
    } else {
      await ref.update({'name': _name, 'seen': _nowMs(), 'stier': _stier});
    }
    final s2 = await ref.get();
    _me = Json.from(s2.data() ?? {});
    _code = (_me['code'] ?? '').toString();
    _users[_uid] = _me;
  }

  Future<void> _hello(Map m) async {
    _name = (m['name'] ?? 'Player').toString();
    _stier = _i(m['stier']);
    await _ensureProfile();
    final plan = _plan();
    _e({
      't': 'hi',
      'r': _me['r'] ?? {},
      'n': _me['n'] ?? {},
      'code': _code,
      'tier': plan[0],
      'until': plan[1]
    });
    _up = true;
    _startListeners();
    if (_gid == null) {
      final gid = _me['gid'];
      if (gid is String && gid.isNotEmpty) {
        await _joinGame(gid, resume: true);
      } else if (m['ig'] == true) {
        _e({'t': 'no_game'});
      }
    }
  }

  void _startListeners() {
    if (_listening) return;
    _listening = true;

    _subs.add(_db
        .collection('requests')
        .where('to', isEqualTo: _uid)
        .snapshots()
        .listen((qs) {
      final fresh = <Json>[];
      for (final d in qs.docs) {
        final j = Json.from(d.data());
        j['id'] = d.id;
        fresh.add(j);
      }
      if (_inInit) {
        for (final c in qs.docChanges) {
          if (c.type == DocumentChangeType.added) {
            final dd = c.doc.data();
            if (dd != null && dd['status'] == 'pending') {
              _e({'t': 'friend_req', 'name': (dd['fromName'] ?? '').toString()});
            }
          }
        }
      }
      _inInit = true;
      _inReqs = fresh;
      _pushFriends();
    }, onError: (_) {}));

    _subs.add(_db
        .collection('requests')
        .where('from', isEqualTo: _uid)
        .snapshots()
        .listen((qs) {
      final fresh = <Json>[];
      for (final d in qs.docs) {
        final j = Json.from(d.data());
        j['id'] = d.id;
        fresh.add(j);
      }
      _outReqs = fresh;
      _pushFriends();
    }, onError: (_) {}));

    _subs.add(_db
        .collection('challenges')
        .where('to', isEqualTo: _uid)
        .snapshots()
        .listen((qs) {
      for (final c in qs.docChanges) {
        final d = c.doc.data();
        if (d == null) continue;
        if (c.type == DocumentChangeType.added && d['status'] == 'pending') {
          final fresh = _nowMs() - _i(d['at']) < 60000;
          if (fresh && _seenChallenges.add(c.doc.id)) {
            _e({
              't': 'challenge',
              'cid': c.doc.id,
              'from': {'id': d['from'], 'name': d['fromName']},
              'min': d['min'],
              'inc': d['inc']
            });
          }
        } else if (c.type == DocumentChangeType.modified &&
            d['status'] == 'cancelled') {
          _e({'t': 'challenge_cancelled', 'cid': c.doc.id});
        }
      }
    }, onError: (_) {}));

    _beat = Timer.periodic(const Duration(seconds: 15), (_) => _heartbeat());
  }

  Future<void> _heartbeat() async {
    _beatN++;
    try {
      await _db.collection('users').doc(_uid).update({'seen': _nowMs()});
      if (_beatN % 2 == 0) await _pushFriends(refresh: true);
    } catch (_) {}
  }

  // ───────────── friends ─────────────
  List<String> _friendIds() {
    final ids = <String>[];
    for (final r in [..._inReqs, ..._outReqs]) {
      if (r['status'] == 'accepted') {
        final other = (r['from'] == _uid ? r['to'] : r['from']).toString();
        if (!ids.contains(other)) ids.add(other);
      }
    }
    return ids;
  }

  Future<void> _loadUsers(List<String> ids, {bool force = false}) async {
    final need =
        ids.where((id) => force || !_users.containsKey(id)).toSet().toList();
    for (int i = 0; i < need.length; i += 30) {
      final chunk = need.sublist(i, min(i + 30, need.length));
      final qs = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in qs.docs) {
        _users[d.id] = Json.from(d.data());
      }
    }
    _users[_uid] = _me;
  }

  Future<void> _pushFriends({bool refresh = false}) async {
    if (!_up && _me.isEmpty) return;
    final ids = _friendIds();
    try {
      await _loadUsers(ids, force: refresh);
    } catch (_) {}
    final now = _nowMs();
    final list = <Map>[];
    for (final id in ids) {
      final u = _users[id];
      if (u == null) continue;
      final gid = u['gid'];
      list.add({
        'id': id,
        'name': (u['name'] ?? '?').toString(),
        'online': now - _i(u['seen']) < 45000,
        'inGame': gid is String && gid.isNotEmpty,
        'r': u['r'] ?? {},
        'tier': _tierOfUser(u),
      });
    }
    final reqIn = <Map>[];
    for (final r in _inReqs) {
      if (r['status'] == 'pending') {
        reqIn.add({'id': r['from'], 'name': (r['fromName'] ?? '?').toString()});
      }
    }
    final reqOut = <Map>[];
    for (final r in _outReqs) {
      if (r['status'] == 'pending') {
        reqOut.add({'id': r['to'], 'name': (r['toName'] ?? '?').toString()});
      }
    }
    _e({
      't': 'friends',
      'code': _code,
      'list': list,
      'reqIn': reqIn,
      'reqOut': reqOut
    });
  }

  void _err(String msg) => _e({'t': 'friend_err', 'msg': msg});

  Future<void> _friendAdd(Map m) async {
    final code = (m['code'] ?? '').toString().toUpperCase().trim();
    if (code.isEmpty) return;
    final cs = await _db.collection('codes').doc(code).get();
    if (!cs.exists) return _err('كود غير صحيح');
    final tid = (cs.data()?['uid'] ?? '').toString();
    if (tid == _uid) return _err('هذا كودك أنت');
    final ids = _friendIds();
    if (ids.contains(tid)) return _err('هو صديقك بالفعل');
    if (ids.length >= _friendLimit[_myTier()]) {
      return _err('وصلت للحد الأقصى للأصدقاء، رقِّ اشتراكك لزيادته');
    }
    for (final r in _inReqs) {
      if (r['from'] == tid && r['status'] == 'pending') {
        await _db
            .collection('requests')
            .doc('${tid}_$_uid')
            .update({'status': 'accepted'});
        _e({'t': 'friend_ok', 'msg': 'أصبحتما صديقين'});
        return;
      }
    }
    for (final r in _outReqs) {
      if (r['to'] == tid && r['status'] == 'pending') {
        return _err('أرسلت له طلباً من قبل');
      }
    }
    final tu = await _db.collection('users').doc(tid).get();
    await _db.collection('requests').doc('${_uid}_$tid').set({
      'from': _uid,
      'to': tid,
      'fromName': _name,
      'toName': (tu.data()?['name'] ?? '?').toString(),
      'status': 'pending',
      'at': _nowMs(),
    });
    _e({'t': 'friend_ok', 'msg': 'تم إرسال طلب الصداقة'});
  }

  Future<void> _friendAccept(Map m) async {
    final id = (m['id'] ?? '').toString();
    if (_friendIds().length >= _friendLimit[_myTier()]) {
      return _err('وصلت للحد الأقصى للأصدقاء');
    }
    await _db
        .collection('requests')
        .doc('${id}_$_uid')
        .update({'status': 'accepted'});
  }

  Future<void> _friendDecline(Map m) async {
    final id = (m['id'] ?? '').toString();
    await _db.collection('requests').doc('${id}_$_uid').delete();
  }

  Future<void> _friendRemove(Map m) async {
    final id = (m['id'] ?? '').toString();
    final docs = <String>[];
    for (final r in [..._inReqs, ..._outReqs]) {
      final other = (r['from'] == _uid ? r['to'] : r['from']).toString();
      if (other == id) docs.add(r['id'].toString());
    }
    for (final d in docs) {
      try {
        await _db.collection('requests').doc(d).delete();
      } catch (_) {}
    }
  }

  // ───────────── challenges ─────────────
  void _cerr(String msg) => _e({'t': 'challenge_err', 'msg': msg});

  Future<void> _challenge(Map m) async {
    final tid = (m['to'] ?? '').toString();
    if (!_friendIds().contains(tid)) return _cerr('هذا اللاعب ليس في أصدقائك');
    if (_gid != null) return _cerr('أنت في مباراة الآن');
    await _loadUsers([tid], force: true);
    final u = _users[tid];
    if (u == null) return _cerr('تعذر العثور على اللاعب');
    if (_nowMs() - _i(u['seen']) >= 45000) return _cerr('صديقك غير متصل');
    final og = u['gid'];
    if (og is String && og.isNotEmpty) return _cerr('صديقك في مباراة الآن');
    final min = _i(m['min'], 10);
    final inc = _i(m['inc']);
    final ref = _db.collection('challenges').doc();
    await ref.set({
      'from': _uid,
      'fromName': _name,
      'to': tid,
      'min': min,
      'inc': inc,
      'status': 'pending',
      'gid': null,
      'at': _nowMs(),
    });
    _myChallenge = ref.id;
    _e({'t': 'challenge_sent', 'cid': ref.id});
    _csub?.cancel();
    final friendName = (u['name'] ?? '').toString();
    _csub = ref.snapshots().listen((s) async {
      final d = s.data();
      if (d == null) return;
      final st = d['status'];
      if (st == 'accepted' && d['gid'] is String) {
        _csub?.cancel();
        _ctimer?.cancel();
        _myChallenge = null;
        await _joinGame(d['gid'] as String);
      } else if (st == 'declined') {
        _csub?.cancel();
        _ctimer?.cancel();
        _myChallenge = null;
        _e({'t': 'challenge_declined', 'name': friendName});
      }
    }, onError: (_) {});
    _ctimer?.cancel();
    _ctimer = Timer(const Duration(seconds: 60), () async {
      if (_myChallenge == ref.id) {
        try {
          await ref.update({'status': 'cancelled'});
        } catch (_) {}
        _csub?.cancel();
        _myChallenge = null;
        _e({'t': 'challenge_declined', 'name': 'انتهت مهلة الطلب'});
      }
    });
  }

  Future<void> _challengeAccept(Map m) async {
    final cid = (m['cid'] ?? '').toString();
    if (_gid != null) return _cerr('أنت في مباراة الآن');
    final ref = _db.collection('challenges').doc(cid);
    final first = await ref.get();
    final fd = first.data();
    if (fd == null || fd['status'] != 'pending') return _cerr('انتهى الطلب');
    final fromUid = (fd['from'] ?? '').toString();
    await _loadUsers([fromUid, _uid], force: true);
    final gid = await _db.runTransaction<String?>((tx) async {
      final s = await tx.get(ref);
      final d = s.data();
      if (d == null || d['status'] != 'pending') return null;
      final g = _db.collection('games').doc();
      tx.set(g, _gameData(fromUid, _uid, _i(d['min'], 10), _i(d['inc'])));
      tx.update(ref, {'status': 'accepted', 'gid': g.id});
      return g.id;
    });
    if (gid == null) return _cerr('انتهى الطلب');
    await _joinGame(gid);
  }

  Future<void> _challengeDecline(Map m) async {
    final cid = (m['cid'] ?? '').toString();
    try {
      await _db.collection('challenges').doc(cid).update({'status': 'declined'});
    } catch (_) {}
  }

  // ───────────── games ─────────────
  Json _gameData(String u1, String u2, int min, int inc, {bool? u1White}) {
    final a = _users[u1] ?? <String, dynamic>{};
    final b = _users[u2] ?? <String, dynamic>{};
    final white1 = u1White ?? Random().nextBool();
    final w = white1 ? u1 : u2;
    final bl = white1 ? u2 : u1;
    final wu = white1 ? a : b;
    final bu = white1 ? b : a;
    final cat = _catOf(min, inc);
    int rOf(Json u) {
      final r = u['r'];
      return r is Map ? _i(r[cat], 800) : 800;
    }

    return {
      'w': w,
      'b': bl,
      'wn': (wu['name'] ?? 'Player').toString(),
      'bn': (bu['name'] ?? 'Player').toString(),
      'wr': rOf(wu),
      'br': rOf(bu),
      'wtier': _tierOfUser(wu),
      'btier': _tierOfUser(bu),
      'min': min,
      'inc': inc,
      'cat': cat,
      'moves': '',
      'wt': min * 60000,
      'bt': min * 60000,
      'status': 'active',
      'result': null,
      'reason': null,
      'offer': null,
      'rematch': {'w': false, 'b': false},
      'chat': {'n': 0, 'i': 0, 'by': ''},
      'rated': {},
      'next': null,
      'createdAt': FieldValue.serverTimestamp(),
      'lastAt': null,
    };
  }

  List<String> _movesOf(Json d) {
    final s = (d['moves'] ?? '').toString().trim();
    return s.isEmpty ? <String>[] : s.split(' ');
  }

  Future<void> _cancelSearch() async {
    _qsub?.cancel();
    _qtimer?.cancel();
    _qsub = null;
    _qtimer = null;
    try {
      await _db.collection('queue').doc(_uid).delete();
    } catch (_) {}
  }

  Future<void> _search(int min, int inc, {String? room}) async {
    if (_gid != null) return;
    await _cancelSearch();
    final isRoom = room != null && room.isNotEmpty;
    final key = isRoom ? 'room_$room' : '$min+$inc';
    final cat = _catOf(min, inc);
    final r = _me['r'];
    final myR = r is Map ? _i(r[cat], 800) : 800;
    final q = _db.collection('queue').doc(_uid);
    await q.set({
      'uid': _uid,
      'name': _name,
      'key': key,
      'rating': myR,
      'min': min,
      'inc': inc,
      'gid': null,
      'ts': _nowMs(),
    });
    _e({'t': 'waiting'});
    _qsub = q.snapshots().listen((s) async {
      final d = s.data();
      if (d == null) return;
      final gid = d['gid'];
      if (gid is String && gid.isNotEmpty) {
        await _cancelSearch();
        await _joinGame(gid);
      }
    }, onError: (_) {});
    _qtimer = Timer.periodic(const Duration(seconds: 2),
        (_) => _tryPair(key, myR, min, inc));
    _tryPair(key, myR, min, inc);
  }

  Future<void> _tryPair(String key, int myR, int min, int inc) async {
    if (_pairing || _gid != null || _joining) return;
    _pairing = true;
    try {
      final qs = await _db
          .collection('queue')
          .where('key', isEqualTo: key)
          .limit(20)
          .get();
      final now = _nowMs();
      QueryDocumentSnapshot<Json>? best;
      int bd = 1 << 30;
      for (final d in qs.docs) {
        if (d.id == _uid) continue;
        final x = d.data();
        if (x['gid'] != null) continue;
        if (now - _i(x['ts']) > 90000) continue;
        final diff = (_i(x['rating'], 800) - myR).abs();
        if (diff < bd) {
          bd = diff;
          best = d;
        }
      }
      if (best == null) return;
      final oid = best.id;
      await _loadUsers([oid, _uid], force: true);
      final gdata = _gameData(_uid, oid, min, inc);
      final mine = _db.collection('queue').doc(_uid);
      final theirs = _db.collection('queue').doc(oid);
      await _db.runTransaction<void>((tx) async {
        final a = await tx.get(mine);
        final b = await tx.get(theirs);
        if (!a.exists || !b.exists) return;
        if (a.data()?['gid'] != null || b.data()?['gid'] != null) return;
        final g = _db.collection('games').doc();
        tx.set(g, gdata);
        tx.update(mine, {'gid': g.id});
        tx.update(theirs, {'gid': g.id});
      });
    } catch (_) {
    } finally {
      _pairing = false;
    }
  }

  void _leaveGame() {
    _gsub?.cancel();
    _gtimer?.cancel();
    _gsub = null;
    _gtimer = null;
    _gid = null;
    _gref = null;
    _gd = {};
    _nMoves = 0;
    _ended = false;
    _endBusy = false;
    _oppAway = false;
  }

  Future<void> _clearMyGid() async {
    try {
      await _db.collection('users').doc(_uid).update({'gid': null});
    } catch (_) {}
    _me['gid'] = null;
  }

  Future<void> _joinGame(String gid, {bool resume = false}) async {
    if (_joining) return;
    _joining = true;
    try {
      _leaveGame();
      final ref = _db.collection('games').doc(gid);
      final s = await ref.get();
      final d = s.data();
      if (d == null) {
        await _clearMyGid();
        if (resume) _e({'t': 'no_game'});
        return;
      }
      if (resume && d['status'] != 'active') {
        await _clearMyGid();
        _e({'t': 'no_game'});
        return;
      }
      _gid = gid;
      _gref = ref;
      _gd = Json.from(d);
      _side = d['w'] == _uid ? 'w' : 'b';
      final list = _movesOf(d);
      _nMoves = list.length;
      _ended = d['status'] == 'ended';
      _lastOffer = d['offer']?.toString();
      final ch = d['chat'];
      _chatN = ch is Map ? _i(ch['n']) : 0;
      _oppAway = false;
      _rematchSeen = false;
      _nextSeen = null;
      _tickN = 0;
      _turnStart = DateTime.now();

      final w = _side == 'w';
      final msg = <String, dynamic>{
        't': resume ? 'resume' : 'start',
        'color': _side,
        'opp': {
          'name': w ? d['bn'] : d['wn'],
          'rating': w ? d['br'] : d['wr'],
          'tier': w ? d['btier'] : d['wtier'],
        },
        'you': {'rating': w ? d['wr'] : d['br']},
        'min': d['min'],
        'inc': d['inc'],
        'cat': d['cat'],
      };
      if (resume) {
        int wt = _i(d['wt']);
        int bt = _i(d['bt']);
        final la = d['lastAt'];
        if (_nMoves >= 1 && d['status'] == 'active' && la is Timestamp) {
          final el = DateTime.now()
              .difference(la.toDate())
              .inMilliseconds
              .clamp(0, 600000)
              .toInt();
          if (_nMoves % 2 == 0) {
            wt -= el;
          } else {
            bt -= el;
          }
          _turnStart = DateTime.now().subtract(Duration(milliseconds: el));
        }
        msg['moves'] = list;
        msg['wt'] = wt;
        msg['bt'] = bt;
      }
      await _db.collection('users').doc(_uid).update({'gid': gid});
      _me['gid'] = gid;
      _e(msg);
      _gsub = ref.snapshots().listen(_onGame, onError: (_) {});
      _gtimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } finally {
      _joining = false;
    }
  }

  void _onGame(DocumentSnapshot<Json> snap) {
    final d = snap.data();
    if (d == null) return;
    _gd = Json.from(d);
    final list = _movesOf(d);
    if (list.length > _nMoves) {
      for (int i = _nMoves; i < list.length; i++) {
        final mover = i % 2 == 0 ? 'w' : 'b';
        if (mover != _side) {
          final u = list[i];
          if (u.length >= 4) {
            _e({
              't': 'move',
              'from': u.substring(0, 2),
              'to': u.substring(2, 4),
              'promo': u.length > 4 ? u.substring(4, 5) : null,
              'wt': d['wt'],
              'bt': d['bt'],
            });
          }
        }
      }
      _nMoves = list.length;
      _turnStart = DateTime.now();
    }

    final offer = d['offer']?.toString();
    if (offer != _lastOffer) {
      if (offer != null && offer != _side) _e({'t': 'draw_offer'});
      if (offer == null && _lastOffer == _side && d['status'] == 'active') {
        _e({'t': 'draw_declined'});
      }
      _lastOffer = offer;
    }

    final ch = d['chat'];
    if (ch is Map) {
      final n = _i(ch['n']);
      if (n > _chatN) {
        _chatN = n;
        if (ch['by'] != _side) _e({'t': 'chat', 'i': _i(ch['i'])});
      }
    }

    final rm = d['rematch'];
    if (rm is Map) {
      final opp = _side == 'w' ? 'b' : 'w';
      if (rm[opp] == true && rm[_side] != true && !_rematchSeen) {
        _rematchSeen = true;
        _e({'t': 'rematch_offer'});
      }
    }

    if (d['status'] == 'ended' && !_ended) {
      _ended = true;
      _applyEnd(d);
    }

    final nx = d['next'];
    if (nx is String && nx.isNotEmpty && nx != _nextSeen) {
      _nextSeen = nx;
      _joinGame(nx);
    }
  }

  void _tick() {
    if (_gid == null || _ended || _gd['status'] != 'active') return;
    _tickN++;
    if (_nMoves >= 1) {
      final turn = _nMoves % 2 == 0 ? 'w' : 'b';
      final base = turn == 'w' ? _i(_gd['wt']) : _i(_gd['bt']);
      final rem = base - DateTime.now().difference(_turnStart).inMilliseconds;
      if (rem < -1500) {
        _endGame(turn == 'w' ? '0-1' : '1-0', 'timeout');
      }
    }
    if (_tickN % 5 == 0) _checkOpp();
  }

  Future<void> _checkOpp() async {
    final oid = (_side == 'w' ? _gd['b'] : _gd['w']).toString();
    try {
      final s = await _db.collection('users').doc(oid).get();
      final age = _nowMs() - _i(s.data()?['seen']);
      if (age > 45000 && !_oppAway) {
        _oppAway = true;
        _e({'t': 'opp_disc'});
      } else if (age <= 45000 && _oppAway) {
        _oppAway = false;
        _e({'t': 'opp_back'});
      }
      if (age > 75000 && !_ended) {
        if (_nMoves < 2) {
          await _endGame('*', 'aborted');
        } else {
          await _endGame(_side == 'w' ? '1-0' : '0-1', 'abandon');
        }
      }
    } catch (_) {}
  }

  Future<void> _gameUpdate(Map<String, dynamic> upd) async {
    final ref = _gref;
    if (ref == null) return;
    try {
      await ref.update(upd);
    } catch (_) {}
  }

  Future<void> _endGame(String result, String reason) async {
    final ref = _gref;
    if (ref == null || _endBusy || _ended) return;
    _endBusy = true;
    try {
      await _db.runTransaction<void>((tx) async {
        final s = await tx.get(ref);
        final d = s.data();
        if (d == null || d['status'] != 'active') return;
        tx.update(ref, {
          'status': 'ended',
          'result': result,
          'reason': reason,
          'endedAt': _nowMs(),
        });
      });
      final s = await ref.get();
      final d = s.data();
      if (d != null && d['status'] == 'ended' && !_ended) {
        _ended = true;
        _applyEnd(Json.from(d));
      }
    } catch (_) {
    } finally {
      _endBusy = false;
    }
  }

  Future<void> _applyEnd(Json d) async {
    _gtimer?.cancel();
    final result = (d['result'] ?? '*').toString();
    final reason = (d['reason'] ?? '').toString();
    final cat = (d['cat'] ?? 'blitz').toString();
    final w = _side == 'w';
    final rated = _movesOf(d).length >= 2 && result != '*';
    int delta = 0;
    int newR = _i(w ? d['wr'] : d['br'], 800);
    if (rated) {
      final myR = _i(w ? d['wr'] : d['br'], 800);
      final opR = _i(w ? d['br'] : d['wr'], 800);
      final double score =
          result == '1/2-1/2' ? 0.5 : (((result == '1-0') == w) ? 1.0 : 0.0);
      final nmap = _me['n'];
      final games = nmap is Map ? _i(nmap[cat]) : 0;
      delta = _elo(myR, opR, score, games);
      newR = max(100, myR + delta);
      final gref = _gref;
      if (gref != null) {
        try {
          final applied = await _db.runTransaction<bool>((tx) async {
            final gs = await tx.get(gref);
            final gd = gs.data() ?? <String, dynamic>{};
            final rm = gd['rated'];
            if (rm is Map && rm[_uid] == true) return false;
            tx.update(gref, {'rated.$_uid': true});
            tx.update(_db.collection('users').doc(_uid), {
              'r.$cat': newR,
              'n.$cat': FieldValue.increment(1),
            });
            return true;
          });
          if (applied) {
            final r = Json.from((_me['r'] as Map?) ?? {});
            r[cat] = newR;
            _me['r'] = r;
            final n = Json.from((_me['n'] as Map?) ?? {});
            n[cat] = _i(n[cat]) + 1;
            _me['n'] = n;
            _users[_uid] = _me;
          }
        } catch (_) {}
      }
    }
    await _clearMyGid();
    _e({
      't': 'end',
      'result': result,
      'reason': reason,
      'delta': delta,
      'rating': newR,
      'rated': rated,
    });
  }

  Future<void> _move(Map m) async {
    final ref = _gref;
    if (ref == null || _ended) return;
    final from = (m['from'] ?? '').toString();
    final to = (m['to'] ?? '').toString();
    final promo = m['promo']?.toString() ?? '';
    final uci = from + to + promo;
    int? wtOut;
    int? btOut;
    await _db.runTransaction<void>((tx) async {
      final s = await tx.get(ref);
      final d = s.data();
      if (d == null || d['status'] != 'active') return;
      final str = (d['moves'] ?? '').toString().trim();
      final cnt = str.isEmpty ? 0 : str.split(' ').length;
      final turn = cnt % 2 == 0 ? 'w' : 'b';
      if (turn != _side) return;
      int wt = _i(d['wt']);
      int bt = _i(d['bt']);
      final inc = _i(d['inc']) * 1000;
      if (cnt >= 1) {
        final used = DateTime.now().difference(_turnStart).inMilliseconds;
        if (_side == 'w') {
          wt -= used;
        } else {
          bt -= used;
        }
        if ((_side == 'w' ? wt : bt) <= 0) {
          tx.update(ref, {
            'status': 'ended',
            'result': _side == 'w' ? '0-1' : '1-0',
            'reason': 'timeout',
            'endedAt': _nowMs(),
          });
          return;
        }
      }
      if (_side == 'w') {
        wt += inc;
      } else {
        bt += inc;
      }
      tx.update(ref, {
        'moves': str.isEmpty ? uci : '$str $uci',
        'wt': wt,
        'bt': bt,
        'offer': null,
        'lastAt': FieldValue.serverTimestamp(),
      });
      wtOut = wt;
      btOut = bt;
    });
    if (wtOut != null && btOut != null) {
      _e({'t': 'clock', 'wt': wtOut, 'bt': btOut});
    }
  }

  Future<void> _rematch() async {
    final ref = _gref;
    if (ref == null) return;
    await ref.update({'rematch.$_side': true});
    final snap = await ref.get();
    final d0 = snap.data();
    if (d0 == null) return;
    await _loadUsers([d0['w'].toString(), d0['b'].toString()], force: true);
    await _db.runTransaction<void>((tx) async {
      final s = await tx.get(ref);
      final d = s.data();
      if (d == null) return;
      final rm = d['rematch'];
      if (!(rm is Map && rm['w'] == true && rm['b'] == true)) return;
      if (d['next'] != null) return;
      final g = _db.collection('games').doc();
      // the old black player becomes white
      tx.set(
          g,
          _gameData(d['b'].toString(), d['w'].toString(), _i(d['min'], 10),
              _i(d['inc']),
              u1White: true));
      tx.update(ref, {'next': g.id});
    });
  }

  // ───────────── plans / leaderboard ─────────────
  Future<void> _redeem(Map m) async {
    final code = (m['code'] ?? '').toString().toUpperCase().trim();
    if (code.isEmpty) return;
    final ref = _db.collection('giftcodes').doc(code);
    final res = await _db.runTransaction<List<int>?>((tx) async {
      final s = await tx.get(ref);
      final d = s.data();
      if (d == null || d['used'] != null) return null;
      final tier = _i(d['tier'], 1).clamp(1, 3).toInt();
      final days = _i(d['days'], 30).clamp(1, 3650).toInt();
      final now = _nowMs();
      final cur = _plan();
      int t = tier;
      int until;
      if (cur[1] > now && cur[0] >= tier) {
        t = cur[0];
        until = cur[1] + days * 86400000;
      } else {
        until = now + days * 86400000;
      }
      tx.update(ref, {'used': _uid, 'usedAt': now});
      tx.update(_db.collection('users').doc(_uid), {
        'plan': {'tier': t, 'until': until}
      });
      return [t, until];
    });
    if (res == null) {
      _e({'t': 'plan_err', 'msg': 'الكود غير صالح أو مستخدم من قبل'});
      return;
    }
    _me['plan'] = {'tier': res[0], 'until': res[1]};
    _e({'t': 'plan', 'tier': res[0], 'until': res[1]});
  }

  Future<void> _top(Map m) async {
    final c = (m['cat'] ?? 'blitz').toString();
    final cat = (c == 'bullet' || c == 'rapid') ? c : 'blitz';
    final qs = await _db
        .collection('users')
        .orderBy('r.$cat', descending: true)
        .limit(40)
        .get();
    final list = <Map>[];
    for (final d in qs.docs) {
      final x = d.data();
      final nm = x['n'];
      final rm = x['r'];
      final n = nm is Map ? _i(nm[cat]) : 0;
      if (n > 0) {
        list.add({
          'name': (x['name'] ?? '?').toString(),
          'r': rm is Map ? _i(rm[cat], 800) : 800,
          'n': n,
        });
      }
      if (list.length >= 20) break;
    }
    _e({'t': 'top', 'cat': cat, 'list': list});
  }
}
