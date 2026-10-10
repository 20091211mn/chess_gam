import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess/chess.dart' as ch;
import 'package:web_socket_channel/web_socket_channel.dart';

// ───────────── online server (change after you deploy it) ─────────────
const kServerUrl = 'wss://YOUR-SERVER.onrender.com';

// ───────────── colors ─────────────
const kBg = Color(0xFF302E2B);
const kPanel = Color(0xFF262421);
const kGreen = Color(0xFF81B64C);
const kGreenDark = Color(0xFF45753C);
const kLight = Color(0xFFEBECD0);
const kDark = Color(0xFF739552);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Chess',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true)
            .copyWith(scaffoldBackgroundColor: kBg),
        home: const MenuPage(),
      );
}

// ───────────── network ─────────────
class Net {
  late final WebSocketChannel ch;
  void Function(Map m)? onMsg;
  final List<Map> _buf = [];
  String color = 'w';
  bool closed = false;

  Net(String url) {
    ch = WebSocketChannel.connect(Uri.parse(url));
    ch.stream.listen((d) {
      try {
        _deliver(jsonDecode(d as String) as Map);
      } catch (_) {}
    }, onDone: () => _deliver({'t': 'closed'}), onError: (_) => _deliver({'t': 'closed'}));
  }

  void _deliver(Map m) {
    if (onMsg != null) {
      onMsg!(m);
    } else {
      _buf.add(m);
    }
  }

  void setHandler(void Function(Map m) h) {
    onMsg = h;
    final copy = List<Map>.from(_buf);
    _buf.clear();
    for (final m in copy) {
      h(m);
    }
  }

  void send(Map m) {
    if (closed) return;
    try {
      ch.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  void close() {
    if (closed) return;
    closed = true;
    try {
      ch.sink.close();
    } catch (_) {}
  }
}

// ───────────── menu ─────────────
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool playWhite = true;

  void _go(bool ai, int depth, String level) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => GamePage(
              vsAI: ai, depth: depth, level: level, playerWhite: playWhite)));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                    width: 54,
                    height: 54,
                    child: CustomPaint(painter: PiecePainter('n', true))),
                const SizedBox(width: 10),
                const Text('شطرنج',
                    style:
                        TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 28),
              _big('العب أونلاين', 'ضد لاعب حقيقي', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OnlinePage()));
              }),
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: kPanel, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Text('العب بـ (ضد الكمبيوتر)',
                      style: TextStyle(fontSize: 15)),
                  const Spacer(),
                  _side(true),
                  const SizedBox(width: 10),
                  _side(false),
                ]),
              ),
              _big('مبتدئ', 'ضد الكمبيوتر - سهل', () => _go(true, 1, 'مبتدئ'),
                  alt: true),
              _big('متوسط', 'ضد الكمبيوتر - متوسط', () => _go(true, 2, 'متوسط'),
                  alt: true),
              _big('متقدم', 'ضد الكمبيوتر - صعب', () => _go(true, 3, 'متقدم'),
                  alt: true),
              _big('العب مع صديق', 'لاعبان على نفس الجهاز',
                  () => _go(false, 0, ''),
                  alt: true),
            ],
          ),
        ),
      );

  Widget _side(bool white) => GestureDetector(
        onTap: () => setState(() => playWhite = white),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: playWhite == white ? kGreen : Colors.transparent,
                width: 3),
          ),
          child: CustomPaint(painter: PiecePainter('k', white)),
        ),
      );

  Widget _big(String t, String sub, VoidCallback f, {bool alt = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: alt ? const Color(0xFF454240) : kGreen,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                  bottom: BorderSide(
                      color: alt ? Colors.black45 : kGreenDark, width: 5)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                    ]),
              ),
              const Icon(Icons.chevron_right, size: 30),
            ]),
          ),
        ),
      );
}

// ───────────── online lobby ─────────────
class OnlinePage extends StatefulWidget {
  const OnlinePage({super.key});
  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  final urlCtl = TextEditingController(text: kServerUrl);
  final roomCtl = TextEditingController();
  Net? net;
  String status = '';
  bool busy = false;
  bool handedOver = false;

  @override
  void dispose() {
    if (!handedOver) net?.close();
    urlCtl.dispose();
    roomCtl.dispose();
    super.dispose();
  }

  void _connect(Map join) {
    final url = urlCtl.text.trim();
    if (url.isEmpty) return;
    net?.close();
    setState(() {
      busy = true;
      status = 'جاري الاتصال بالسيرفر... (قد يستغرق دقيقة أول مرة)';
    });
    try {
      net = Net(url);
    } catch (_) {
      setState(() {
        busy = false;
        status = 'رابط السيرفر غير صالح';
      });
      return;
    }
    final n = net!;
    n.onMsg = (m) {
      if (!mounted) return;
      switch (m['t']) {
        case 'waiting':
          setState(() => status = 'في انتظار خصم...');
          break;
        case 'start':
          n.color = m['color'] == 'b' ? 'b' : 'w';
          n.onMsg = null;
          handedOver = true;
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => GamePage(
                      vsAI: false,
                      depth: 0,
                      level: '',
                      playerWhite: n.color == 'w',
                      net: n)));
          break;
        case 'closed':
          setState(() {
            busy = false;
            status = 'تعذر الاتصال بالسيرفر';
          });
          break;
      }
    };
    n.send(join);
  }

  void _cancel() {
    net?.close();
    net = null;
    setState(() {
      busy = false;
      status = '';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            backgroundColor: kPanel, title: const Text('لعب أونلاين')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(
            controller: urlCtl,
            enabled: !busy,
            decoration: const InputDecoration(
                labelText: 'رابط السيرفر',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 18),
          _btn('مباراة سريعة', busy ? null : () => _connect({'t': 'quick'})),
          const SizedBox(height: 18),
          TextField(
            controller: roomCtl,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'رمز الغرفة (اتفق عليه مع صديقك)',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          _btn('دخول الغرفة', busy
              ? null
              : () {
                  final r = roomCtl.text.trim();
                  if (r.isEmpty) {
                    setState(() => status = 'اكتب رمز الغرفة');
                    return;
                  }
                  _connect({'t': 'join', 'room': r});
                }, alt: true),
          const SizedBox(height: 22),
          if (status.isNotEmpty)
            Center(
                child: Text(status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16))),
          if (busy) ...[
            const SizedBox(height: 14),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 14),
            Center(
                child: TextButton(
                    onPressed: _cancel, child: const Text('إلغاء'))),
          ],
        ]),
      );

  Widget _btn(String t, VoidCallback? f, {bool alt = false}) => GestureDetector(
        onTap: f,
        child: Opacity(
          opacity: f == null ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: alt ? const Color(0xFF454240) : kGreen,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                  bottom: BorderSide(
                      color: alt ? Colors.black45 : kGreenDark, width: 4)),
            ),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

// ───────────── engine (runs in isolates) ─────────────
const _vals = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};
const _files = 'abcdefgh';

int _evalPos(ch.Chess g) {
  int s = 0;
  for (int r = 0; r < 8; r++) {
    for (int f = 0; f < 8; f++) {
      final p = g.get('${_files[f]}${8 - r}');
      if (p == null) continue;
      final t = p.type.toString();
      final white = p.color == ch.Color.WHITE;
      var v = _vals[t]!;
      final c = 3.5 - ((3.5 - r).abs() + (3.5 - f).abs()) / 2;
      if (t == 'n' || t == 'b') {
        v += (c * 8).round();
      } else if (t == 'p') {
        v += (c * 3).round();
        final adv = white ? (6 - r) : (r - 1);
        v += adv * 6;
      } else if (t == 'q' || t == 'r') {
        v += (c * 2).round();
      }
      s += white ? v : -v;
    }
  }
  return s;
}

List _sortedMoves(ch.Chess g) {
  final ms = (g.moves({'asObjects': true}) as List).toList();
  int o(dynamic m) => g.get(m.toAlgebraic as String) != null ? 1 : 0;
  ms.sort((a, b) => o(b) - o(a));
  return ms;
}

int _quiesce(ch.Chess g, int alpha, int beta, int qd) {
  final stand = _evalPos(g);
  if (qd == 0) return stand;
  final white = g.turn == ch.Color.WHITE;
  if (white) {
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
  } else {
    if (stand <= alpha) return stand;
    if (stand < beta) beta = stand;
  }
  final ms = (g.moves({'asObjects': true}) as List)
      .where((m) => g.get(m.toAlgebraic as String) != null)
      .toList();
  int best = stand;
  for (final m in ms) {
    g.move(m);
    final v = _quiesce(g, alpha, beta, qd - 1);
    g.undo_move();
    if (white) {
      if (v > best) best = v;
      if (best > alpha) alpha = best;
    } else {
      if (v < best) best = v;
      if (best < beta) beta = best;
    }
    if (beta <= alpha) break;
  }
  return best;
}

int _search(ch.Chess g, int depth, int alpha, int beta) {
  if (g.in_checkmate) {
    return g.turn == ch.Color.WHITE ? -99999 - depth : 99999 + depth;
  }
  if (g.in_draw) return 0;
  if (depth == 0) return _quiesce(g, alpha, beta, 3);
  final ms = _sortedMoves(g);
  final white = g.turn == ch.Color.WHITE;
  int best = white ? -1000000 : 1000000;
  for (final m in ms) {
    g.move(m);
    final v = _search(g, depth - 1, alpha, beta);
    g.undo_move();
    if (white) {
      if (v > best) best = v;
      if (best > alpha) alpha = best;
    } else {
      if (v < best) best = v;
      if (best < beta) beta = best;
    }
    if (beta <= alpha) break;
  }
  return best;
}

Map<String, String>? _bestMoveTask(Map<String, dynamic> a) {
  final g = ch.Chess.fromFEN(a['fen'] as String);
  final depth = a['depth'] as int;
  final white = g.turn == ch.Color.WHITE;
  final ms = _sortedMoves(g);
  // shuffle equal-priority moves a little so the computer is not predictable
  ms.shuffle(Random());
  dynamic best;
  int bestV = white ? -1000000 : 1000000;
  for (final m in ms) {
    g.move(m);
    final v = _search(g, depth - 1, -1000000, 1000000);
    g.undo_move();
    if (white ? v > bestV : v < bestV) {
      bestV = v;
      best = m;
    }
  }
  if (best == null) return null;
  return {
    'from': best.fromAlgebraic as String,
    'to': best.toAlgebraic as String
  };
}

// Move review: scores every legal move, compares the played one with the best.
Map<String, dynamic>? _analyzeTask(Map<String, dynamic> a) {
  final g = ch.Chess.fromFEN(a['fen'] as String);
  final depth = a['depth'] as int;
  final pf = a['from'] as String;
  final pt = a['to'] as String;
  final pp = (a['promo'] as String?) ?? 'q';
  final white = g.turn == ch.Color.WHITE;
  final ms = _sortedMoves(g);
  if (ms.isEmpty) return null;
  dynamic best;
  int bestV = white ? -2000000 : 2000000;
  int playedV = 0;
  bool found = false;
  final moverScores = <int>[];
  for (final m in ms) {
    g.move(m);
    final v = _search(g, depth - 1, -1000000, 1000000);
    g.undo_move();
    moverScores.add(white ? v : -v);
    final mp = m.promotion == null ? null : m.promotion.toString();
    if (!found &&
        m.fromAlgebraic == pf &&
        m.toAlgebraic == pt &&
        (mp == null || mp == pp)) {
      playedV = v;
      found = true;
    }
    if (white ? v > bestV : v < bestV) {
      bestV = v;
      best = m;
    }
  }
  if (!found) return null;
  moverScores.sort((x, y) => y - x);
  final moverBest = moverScores.first;
  final moverPlayed = white ? playedV : -playedV;
  final gap = moverScores.length > 1 ? moverBest - moverScores[1] : 0;
  String bestSan = '';
  final bf = best.fromAlgebraic as String;
  final bt = best.toAlgebraic as String;
  try {
    g.move(best);
    final sans = g.san_moves();
    bestSan = sans.isNotEmpty ? sans.last.toString() : '';
    g.undo_move();
  } catch (_) {}
  return {
    'loss': moverBest - moverPlayed,
    'gap': gap,
    'n': ms.length,
    'evalAfter': playedV,
    'bestFrom': bf,
    'bestTo': bt,
    'bestSan': bestSan,
  };
}

// ───────────── models ─────────────
class Pc {
  final int id;
  String type;
  final bool white;
  String sq;
  Pc(this.id, this.type, this.white, this.sq);
}

class Rev {
  final String san;
  final bool white;
  String? grade;
  int loss = 0;
  int evalAfter = 0;
  String bestSan = '';
  String? bestFrom, bestTo;
  String to;
  Rev(this.san, this.white, this.to);
}

class GI {
  final String sym;
  final Color color;
  final String label;
  const GI(this.sym, this.color, this.label);
}

const Map<String, GI> kGrades = {
  'great': GI('!', Color(0xFF5C8BB0), 'نقلة رائعة'),
  'best': GI('★', Color(0xFF96BC4B), 'أفضل نقلة'),
  'excellent': GI('✓', Color(0xFF96BC4B), 'نقلة ممتازة'),
  'good': GI('✓', Color(0xFF81B64C), 'نقلة جيدة'),
  'inaccuracy': GI('?!', Color(0xFFF7C631), 'عدم دقة'),
  'mistake': GI('?', Color(0xFFE58F2A), 'خطأ'),
  'blunder': GI('??', Color(0xFFCA3431), 'خطأ فادح'),
};

String _gradeOf(int loss, int gap, int n) {
  if (loss <= 0) return (gap >= 200 && n > 1) ? 'great' : 'best';
  if (loss <= 25) return 'excellent';
  if (loss <= 70) return 'good';
  if (loss <= 150) return 'inaccuracy';
  if (loss <= 300) return 'mistake';
  return 'blunder';
}

// ───────────── game page ─────────────
class GamePage extends StatefulWidget {
  final bool vsAI;
  final int depth;
  final String level;
  final bool playerWhite;
  final Net? net;
  const GamePage(
      {super.key,
      required this.vsAI,
      required this.depth,
      required this.level,
      required this.playerWhite,
      this.net});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  ch.Chess game = ch.Chess();
  List<Pc> pcs = [];
  List<Rev> reviews = [];
  int _nextId = 0;
  String? selected;
  List<String> targets = [];
  String? lastFrom, lastTo;
  bool thinking = false;
  bool flipped = false;
  bool resultShown = false;
  bool showBest = false;
  int epoch = 0;
  int whiteSecs = 600, blackSecs = 600;
  final ScrollController _sc = ScrollController();

  bool get online => widget.net != null;
  bool get aiWhite => !widget.playerWhite;
  ch.Color get aiColor => aiWhite ? ch.Color.WHITE : ch.Color.BLACK;

  @override
  void initState() {
    super.initState();
    flipped = !widget.playerWhite;
    _rebuild();
    _tick();
    widget.net?.setHandler(_onNet);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAI());
  }

  @override
  void dispose() {
    widget.net?.onMsg = null;
    widget.net?.close();
    _sc.dispose();
    super.dispose();
  }

  void _onNet(Map m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        _doMove(m['from'] as String, m['to'] as String, m['promo'] as String?,
            fromNet: true);
        break;
      case 'resign':
        _end('استسلم الخصم - فزت!');
        break;
      case 'left':
        _end('غادر الخصم - فزت!');
        break;
      case 'closed':
        if (!game.game_over && !resultShown) _end('انقطع الاتصال بالسيرفر');
        break;
    }
  }

  String _sq(int r, int f) => '${_files[f]}${8 - r}';

  void _rebuild() {
    pcs = [];
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = game.get(_sq(r, f));
        if (p != null) {
          pcs.add(Pc(_nextId++, p.type.toString(), p.color == ch.Color.WHITE,
              _sq(r, f)));
        }
      }
    }
  }

  void _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (game.game_over || resultShown) continue;
      if (game.history.isEmpty) continue;
      setState(() {
        if (game.turn == ch.Color.WHITE) {
          whiteSecs--;
        } else {
          blackSecs--;
        }
      });
      if (whiteSecs <= 0 || blackSecs <= 0) {
        _end(whiteSecs <= 0
            ? 'انتهى الوقت - فاز الأسود'
            : 'انتهى الوقت - فاز الأبيض');
      }
    }
  }

  void _end(String m) {
    if (resultShown || !mounted) return;
    resultShown = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (_) => Dialog(
                backgroundColor: kPanel,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('انتهت اللعبة',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(m,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17)),
                    const SizedBox(height: 22),
                    _greenBtn(online ? 'خروج' : 'لعبة جديدة', () {
                      Navigator.pop(context);
                      if (online) {
                        Navigator.pop(context);
                      } else {
                        _reset();
                      }
                    }),
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('عرض الرقعة')),
                  ]),
                ),
              ));
    });
  }

  Widget _greenBtn(String t, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: kGreen,
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                  bottom: BorderSide(color: kGreenDark, width: 4))),
          child: Text(t,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      );

  void _reset() {
    if (online) return;
    epoch++;
    setState(() {
      game = ch.Chess();
      selected = null;
      targets = [];
      lastFrom = lastTo = null;
      whiteSecs = blackSecs = 600;
      thinking = false;
      resultShown = false;
      showBest = false;
      reviews = [];
      _rebuild();
    });
    _maybeAI();
  }

  void _checkEnd() {
    if (game.in_checkmate) {
      _end(game.turn == ch.Color.WHITE
          ? 'كش مات - فاز الأسود'
          : 'كش مات - فاز الأبيض');
    } else if (game.in_stalemate) {
      _end('تعادل بالجمود (ستالميت)');
    } else if (game.in_threefold_repetition) {
      _end('تعادل بالتكرار');
    } else if (game.in_draw) {
      _end('تعادل');
    }
  }

  bool get _aiToMove => widget.vsAI && game.turn == aiColor;
  bool get _notMyTurnOnline =>
      online && (game.turn == ch.Color.WHITE) != widget.playerWhite;

  void _click() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  void _tap(String sq) {
    if (thinking ||
        game.game_over ||
        resultShown ||
        _aiToMove ||
        _notMyTurnOnline) {
      return;
    }
    if (selected != null && targets.contains(sq)) {
      _userMove(selected!, sq);
      return;
    }
    final p = game.get(sq);
    if (p != null && p.color == game.turn) {
      final ms = game.moves({'asObjects': true}) as List;
      setState(() {
        selected = sq;
        targets = [
          for (final m in ms)
            if (m.fromAlgebraic == sq) m.toAlgebraic as String
        ];
      });
    } else {
      setState(() {
        selected = null;
        targets = [];
      });
    }
  }

  Future<void> _userMove(String from, String to) async {
    final p = game.get(from);
    String? promo;
    if (p != null &&
        p.type.toString() == 'p' &&
        (to[1] == '8' || to[1] == '1')) {
      promo = await _askPromo(p.color == ch.Color.WHITE);
      if (promo == null) return;
    }
    _doMove(from, to, promo);
  }

  Future<String?> _askPromo(bool white) => showModalBottomSheet<String>(
        context: context,
        backgroundColor: kPanel,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final t in ['q', 'r', 'b', 'n'])
                  GestureDetector(
                    onTap: () => Navigator.pop(context, t),
                    child: Container(
                      width: 66,
                      height: 66,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: kDark, borderRadius: BorderRadius.circular(8)),
                      child: CustomPaint(painter: PiecePainter(t, white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  void _applyMove(String from, String to, String? promo) {
    final mover = pcs.firstWhere((p) => p.sq == from);
    final capIdx = pcs.indexWhere((p) => p.sq == to);
    if (capIdx >= 0) {
      pcs.removeAt(capIdx);
    } else if (mover.type == 'p' && from[0] != to[0]) {
      pcs.removeWhere((p) => p.sq == '${to[0]}${from[1]}'); // en passant
    }
    if (mover.type == 'k' &&
        (_files.indexOf(to[0]) - _files.indexOf(from[0])).abs() == 2) {
      final rank = from[1];
      final rf = to[0] == 'g' ? 'h' : 'a';
      final rt = to[0] == 'g' ? 'f' : 'd';
      final rook = pcs.firstWhere((p) => p.sq == '$rf$rank');
      rook.sq = '$rt$rank';
    }
    mover.sq = to;
    if (mover.type == 'p' && (to[1] == '8' || to[1] == '1')) {
      mover.type = promo ?? 'q';
    }
  }

  void _doMove(String from, String to, String? promo, {bool fromNet = false}) {
    final fenBefore = game.fen;
    final moverWhite = game.turn == ch.Color.WHITE;
    final ok = game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'});
    if (!ok) return;
    if (online && !fromNet) {
      widget.net!.send({'t': 'move', 'from': from, 'to': to, 'promo': promo});
    }
    String san = '$from$to';
    try {
      final l = game.san_moves();
      if (l.isNotEmpty) san = l.last.toString();
    } catch (_) {}
    final rev = Rev(san, moverWhite, to);
    reviews.add(rev);
    _click();
    setState(() {
      _applyMove(from, to, promo);
      lastFrom = from;
      lastTo = to;
      selected = null;
      targets = [];
      showBest = false;
    });
    _scrollMoves();
    _analyze(fenBefore, rev, from, to, promo);
    _checkEnd();
    _maybeAI();
  }

  Future<void> _analyze(
      String fen, Rev rev, String from, String to, String? promo) async {
    final r = await compute(_analyzeTask,
        {'fen': fen, 'depth': 3, 'from': from, 'to': to, 'promo': promo});
    if (!mounted || r == null) return;
    final loss = (r['loss'] as int);
    setState(() {
      rev.loss = loss < 0 ? 0 : loss;
      rev.evalAfter = r['evalAfter'] as int;
      rev.bestSan = r['bestSan'] as String;
      rev.bestFrom = r['bestFrom'] as String;
      rev.bestTo = r['bestTo'] as String;
      rev.grade = _gradeOf(rev.loss, r['gap'] as int, r['n'] as int);
    });
  }

  Future<void> _maybeAI() async {
    if (!widget.vsAI || game.game_over || game.turn != aiColor || thinking) {
      return;
    }
    final my = epoch;
    setState(() => thinking = true);
    await Future.delayed(const Duration(milliseconds: 450));
    final r = await compute(
        _bestMoveTask, {'fen': game.fen, 'depth': widget.depth});
    if (!mounted || my != epoch) return;
    setState(() => thinking = false);
    if (r != null) _doMove(r['from']!, r['to']!, 'q');
  }

  void _undo() {
    if (online) return;
    if (thinking && widget.vsAI) return;
    if (game.history.isEmpty) return;
    epoch++;
    game.undo_move();
    if (reviews.isNotEmpty) reviews.removeLast();
    if (widget.vsAI && game.turn == aiColor && game.history.isNotEmpty) {
      game.undo_move();
      if (reviews.isNotEmpty) reviews.removeLast();
    }
    setState(() {
      selected = null;
      targets = [];
      lastFrom = lastTo = null;
      thinking = false;
      resultShown = false;
      showBest = false;
      _rebuild();
    });
    _maybeAI();
  }

  List<String> _sans() {
    try {
      return List<String>.from(game.san_moves());
    } catch (_) {
      return [];
    }
  }

  void _scrollMoves() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) {
        _sc.animateTo(_sc.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String _fmt(int s) {
    if (s < 0) s = 0;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ───────── UI ─────────
  @override
  Widget build(BuildContext context) {
    final bottomWhite = !flipped;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _moveStrip(),
            const SizedBox(height: 6),
            _playerBar(!bottomWhite),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (c, _) {
              final bs = c.maxWidth - 18;
              return SizedBox(
                height: bs,
                child: Row(children: [
                  _evalBar(bs),
                  const SizedBox(width: 2),
                  SizedBox(width: bs, height: bs, child: _board()),
                ]),
              );
            }),
            const SizedBox(height: 6),
            _playerBar(bottomWhite),
            Expanded(
              child: SingleChildScrollView(child: _reviewCard()),
            ),
            _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _evalBar(double h) {
    int cp = 0;
    for (final r in reviews.reversed) {
      if (r.grade != null) {
        cp = r.evalAfter;
        break;
      }
    }
    final frac = (1 / (1 + exp(-cp / 250))).clamp(0.03, 0.97);
    final whiteAtBottom = !flipped;
    final label = cp.abs() >= 90000
        ? 'M'
        : (cp.abs() / 100).toStringAsFixed(1);
    final labelOnWhite = cp >= 0;
    final labelAtBottom = labelOnWhite == whiteAtBottom;
    return Container(
      width: 16,
      height: h,
      decoration: BoxDecoration(
          color: const Color(0xFF403D39),
          borderRadius: BorderRadius.circular(3)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(children: [
          Align(
            alignment:
                whiteAtBottom ? Alignment.bottomCenter : Alignment.topCenter,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                height: h * frac,
                color: Colors.white),
          ),
          Align(
            alignment:
                labelAtBottom ? Alignment.bottomCenter : Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: labelOnWhite ? Colors.black87 : Colors.white70)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _reviewCard() {
    double acc(bool white) {
      final l =
          reviews.where((r) => r.white == white && r.grade != null).toList();
      if (l.isEmpty) return -1;
      double s = 0;
      for (final r in l) {
        s += 100 * exp(-min(r.loss, 3000) / 300.0);
      }
      return s / l.length;
    }

    Widget body;
    if (reviews.isEmpty) {
      body = const Text('العب نقلة لتظهر تقييمها هنا',
          style: TextStyle(color: Colors.white54, fontSize: 14));
    } else {
      final r = reviews.last;
      final g = r.grade == null ? null : kGrades[r.grade!];
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (g != null) _badge(g, 26) else const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                g == null ? '${r.san} - جاري التحليل...' : '${r.san} - ${g.label}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: g?.color ?? Colors.white70)),
          ),
        ]),
        if (r.grade != null &&
            (r.grade == 'inaccuracy' ||
                r.grade == 'mistake' ||
                r.grade == 'blunder') &&
            r.bestSan.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => setState(() => showBest = !showBest),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: Colors.white60),
                const SizedBox(width: 6),
                Text('الأفضل كان: ${r.bestSan}',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(showBest ? '(إخفاء)' : '(إظهار على الرقعة)',
                    style: const TextStyle(fontSize: 12, color: kGreen)),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [
          _accChip('الأبيض', acc(true)),
          const SizedBox(width: 10),
          _accChip('الأسود', acc(false)),
        ]),
      ]);
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
          color: kPanel, borderRadius: BorderRadius.circular(8)),
      child: body,
    );
  }

  Widget _accChip(String who, double a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: kBg, borderRadius: BorderRadius.circular(6)),
        child: Text(
            a < 0 ? '$who: --' : '$who: ${a.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      );

  Widget _badge(GI g, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: g.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: size * 0.07),
        ),
        child: Text(g.sym,
            style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1)),
      );

  Widget _moveStrip() {
    final sans = _sans();
    final items = <Widget>[];
    for (int i = 0; i < sans.length; i += 2) {
      Color? colorOf(int idx) {
        if (idx >= reviews.length) return null;
        final g = reviews[idx].grade;
        if (g == 'inaccuracy' || g == 'mistake' || g == 'blunder') {
          return kGrades[g]!.color;
        }
        return null;
      }

      items.add(Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(children: [
          Text('${i ~/ 2 + 1}. ',
              style: const TextStyle(color: Colors.white38, fontSize: 14)),
          Text(sans[i],
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorOf(i))),
          const SizedBox(width: 6),
          if (i + 1 < sans.length)
            Text(sans[i + 1],
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorOf(i + 1))),
        ]),
      ));
    }
    return Container(
      height: 34,
      color: kPanel,
      child: Row(children: [
        IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 20)),
        Expanded(
          child: items.isEmpty
              ? const Text('ابدأ اللعب',
                  style: TextStyle(color: Colors.white38, fontSize: 13))
              : ListView(
                  controller: _sc,
                  scrollDirection: Axis.horizontal,
                  children: items),
        ),
      ]),
    );
  }

  static const _init = {'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1};

  Widget _playerBar(bool white) {
    final mine = pcs.where((p) => p.white == white).toList();
    final theirs = pcs.where((p) => p.white != white).toList();
    final captured = <String>[];
    for (final t in ['q', 'r', 'b', 'n', 'p']) {
      final have = theirs.where((p) => p.type == t).length;
      final lost = (_init[t]! - have).clamp(0, 8);
      for (int i = 0; i < lost; i++) {
        captured.add(t);
      }
    }
    int sum(List<Pc> l) => l.fold(0, (a, p) => a + _vals[p.type]!);
    final diff = (sum(mine) - sum(theirs)) ~/ 100;
    final active = !game.game_over && ((game.turn == ch.Color.WHITE) == white);
    final secs = white ? whiteSecs : blackSecs;
    String name;
    if (widget.vsAI) {
      name = (white == aiWhite) ? 'الكمبيوتر (${widget.level})' : 'أنت';
    } else if (online) {
      name = (white == widget.playerWhite) ? 'أنت' : 'الخصم';
    } else {
      name = white ? 'الأبيض' : 'الأسود';
    }
    final isAI = widget.vsAI && white == aiWhite;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: white ? Colors.white : const Color(0xFF3A3835),
              borderRadius: BorderRadius.circular(4)),
          child: Icon(isAI ? Icons.smart_toy : Icons.person,
              color: white ? Colors.black87 : Colors.white70),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  if (isAI && thinking)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ]),
                SizedBox(
                  height: 18,
                  child: Row(children: [
                    for (final t in captured)
                      SizedBox(
                          width: t == 'p' ? 11 : 16,
                          height: 18,
                          child:
                              CustomPaint(painter: PiecePainter(t, !white))),
                    if (diff > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('+$diff',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white54)),
                      ),
                  ]),
                ),
              ]),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: active ? Colors.white : kPanel,
              borderRadius: BorderRadius.circular(5)),
          child: Text(_fmt(secs),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: secs < 20
                      ? Colors.redAccent
                      : (active ? Colors.black : Colors.white54))),
        ),
      ]),
    );
  }

  Widget _board() => LayoutBuilder(builder: (ctx, cons) {
        final S = cons.maxWidth;
        final cell = S / 8;
        Offset pos(String sq) {
          final f = _files.indexOf(sq[0]);
          final r = 8 - int.parse(sq[1]);
          return Offset((flipped ? 7 - f : f) * cell,
              (flipped ? 7 - r : r) * cell);
        }

        final whiteTurn = game.turn == ch.Color.WHITE;
        String? kingSq;
        if (game.in_check) {
          for (final p in pcs) {
            if (p.type == 'k' && p.white == whiteTurn) kingSq = p.sq;
          }
        }
        final lastRev = reviews.isEmpty ? null : reviews.last;
        final bestA = (showBest && lastRev != null) ? lastRev.bestFrom : null;
        final bestB = (showBest && lastRev != null) ? lastRev.bestTo : null;
        final squares = <Widget>[];
        for (int dr = 0; dr < 8; dr++) {
          for (int dc = 0; dc < 8; dc++) {
            final f = flipped ? 7 - dc : dc;
            final r = flipped ? 7 - dr : dr;
            final sq = _sq(r, f);
            final dark = (r + f) % 2 == 1;
            final fg = dark ? kLight : kDark;
            final hl = sq == lastFrom || sq == lastTo || sq == selected;
            squares.add(Positioned(
              left: dc * cell,
              top: dr * cell,
              width: cell,
              height: cell,
              child: GestureDetector(
                onTap: () => _tap(sq),
                child: Container(
                  color: dark ? kDark : kLight,
                  child: Stack(children: [
                    if (hl) Container(color: const Color(0x80F6F669)),
                    if (sq == bestA || sq == bestB)
                      Container(color: const Color(0x884A90E2)),
                    if (sq == kingSq)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(colors: [
                            Color(0xFFFF0000),
                            Color(0xAAE62929),
                            Color(0x00E62929)
                          ], stops: [
                            0.0,
                            0.45,
                            0.85
                          ]),
                        ),
                      ),
                    if (dc == 0)
                      Positioned(
                          left: 2,
                          top: 1,
                          child: Text('${8 - r}',
                              style: TextStyle(
                                  fontSize: cell * 0.2,
                                  fontWeight: FontWeight.w800,
                                  color: fg))),
                    if (dr == 7)
                      Positioned(
                          right: 2,
                          bottom: 0,
                          child: Text(_files[f],
                              style: TextStyle(
                                  fontSize: cell * 0.2,
                                  fontWeight: FontWeight.w800,
                                  color: fg))),
                  ]),
                ),
              ),
            ));
          }
        }
        // grade badge on the destination square of the last move
        Widget? badge;
        if (lastRev != null && lastRev.grade != null) {
          final g = kGrades[lastRev.grade!]!;
          final p = pos(lastRev.to);
          final bsz = cell * 0.42;
          badge = Positioned(
            left: min(p.dx + cell * 0.62, S - bsz),
            top: max(p.dy - cell * 0.06, 0),
            child: _badge(g, bsz),
          );
        }
        return SizedBox(
          width: S,
          height: S,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              ...squares,
              Positioned.fill(
                child: Stack(children: [
                  for (final pc in pcs)
                    AnimatedPositioned(
                      key: ValueKey(pc.id),
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOutCubic,
                      left: pos(pc.sq).dx,
                      top: pos(pc.sq).dy,
                      width: cell,
                      height: cell,
                      child: IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.all(cell * 0.03),
                          child: CustomPaint(
                              painter: PiecePainter(pc.type, pc.white)),
                        ),
                      ),
                    ),
                ]),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(children: [
                    for (final t in targets)
                      Positioned(
                        left: pos(t).dx,
                        top: pos(t).dy,
                        width: cell,
                        height: cell,
                        child: Center(
                          child: pcs.any((p) => p.sq == t)
                              ? Container(
                                  width: cell * 0.92,
                                  height: cell * 0.92,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0x40000000),
                                          width: cell * 0.09)),
                                )
                              : Container(
                                  width: cell * 0.3,
                                  height: cell * 0.3,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0x30000000)),
                                ),
                        ),
                      ),
                    if (badge != null) badge,
                  ]),
                ),
              ),
            ]),
          ),
        );
      });

  Widget _navBar() => Container(
        color: kPanel,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!online) _nav(Icons.refresh, 'جديدة', _reset),
            _nav(Icons.swap_vert, 'قلب',
                () => setState(() => flipped = !flipped)),
            if (!online) _nav(Icons.undo, 'تراجع', _undo),
            _nav(Icons.flag_outlined, 'استسلام', () {
              if (game.game_over || resultShown) return;
              if (online) {
                widget.net!.send({'t': 'resign'});
                _end('استسلمت - فاز الخصم');
                return;
              }
              final whiteResigns = widget.vsAI
                  ? widget.playerWhite
                  : game.turn == ch.Color.WHITE;
              _end(whiteResigns
                  ? 'استسلم الأبيض - فاز الأسود'
                  : 'استسلم الأسود - فاز الأبيض');
            }),
          ],
        ),
      );

  Widget _nav(IconData i, String t, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 26, color: Colors.white70),
            const SizedBox(height: 2),
            Text(t,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ),
      );
}

// ───────────── vector pieces (drawn in code, no assets) ─────────────
Path _rr(double x, double y, double w, double h, double r) => Path()
  ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
Path _c(double x, double y, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
Path _poly(List<double> p) {
  final path = Path()..moveTo(p[0], p[1]);
  for (int i = 2; i < p.length; i += 2) {
    path.lineTo(p[i], p[i + 1]);
  }
  return path..close();
}

class PiecePainter extends CustomPainter {
  final String type;
  final bool white;
  PiecePainter(this.type, this.white);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 45, size.height / 45);

    // soft ground shadow
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(22.5, 37), width: 28, height: 4.5),
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: white
            ? const [Color(0xFFFFFFFF), Color(0xFFD2D2D2)]
            : const [Color(0xFF6E6A67), Color(0xFF2B2927)],
      ).createShader(const Rect.fromLTWH(0, 0, 45, 45));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF1A1A1A);
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = white ? const Color(0xFF1A1A1A) : const Color(0xFFEDEDED);
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = white ? const Color(0x00FFFFFF) : const Color(0x33FFFFFF);

    final shapes = <Path>[];
    final details = <Path>[];
    switch (type) {
      case 'p':
        shapes.addAll([
          _rr(12.5, 32, 20, 4.5, 2),
          Path()
            ..moveTo(16, 32)
            ..cubicTo(16, 27, 20, 25, 20, 21)
            ..lineTo(25, 21)
            ..cubicTo(25, 25, 29, 27, 29, 32)
            ..close(),
          _rr(17.5, 19.5, 10, 3, 1.5),
          _c(22.5, 14, 5.2),
        ]);
        break;
      case 'r':
        shapes.addAll([
          _rr(11, 32.5, 23, 4.5, 1.5),
          _poly([13.5, 32.5, 15, 17, 30, 17, 31.5, 32.5]),
          _poly([13, 17, 13, 8, 17.5, 8, 17.5, 11.5, 20.5, 11.5, 20.5, 8,
            24.5, 8, 24.5, 11.5, 27.5, 11.5, 27.5, 8, 32, 8, 32, 17]),
        ]);
        details.add(Path()
          ..moveTo(15.5, 21)
          ..lineTo(29.5, 21));
        break;
      case 'b':
        shapes.addAll([
          _rr(11.5, 33, 22, 4, 1.5),
          Path()
            ..moveTo(14.5, 33)
            ..cubicTo(14.5, 28, 19, 27, 19.5, 22)
            ..lineTo(25.5, 22)
            ..cubicTo(26, 27, 30.5, 28, 30.5, 33)
            ..close(),
          Path()
            ..addOval(Rect.fromCenter(
                center: const Offset(22.5, 15.5), width: 11, height: 15)),
          _c(22.5, 6.2, 2.4),
        ]);
        details.add(Path()
          ..moveTo(19.8, 17)
          ..lineTo(25.2, 11));
        break;
      case 'n':
        shapes.addAll([
          _rr(11.5, 33, 22, 4, 1.5),
          Path()
            ..moveTo(14, 33)
            ..cubicTo(13.5, 28, 15.5, 25, 18.5, 22.5)
            ..cubicTo(17, 22.2, 14.5, 23.2, 12.2, 24)
            ..lineTo(10.3, 21.6)
            ..cubicTo(10.8, 18.2, 13.5, 15.5, 15.5, 12.5)
            ..lineTo(15.3, 7.5)
            ..lineTo(18.6, 10)
            ..cubicTo(19.8, 8.4, 22.5, 7.5, 25, 8.4)
            ..cubicTo(31.5, 11, 34.5, 21, 33, 33)
            ..close(),
        ]);
        details.addAll([
          Path()
            ..moveTo(17.6, 14.2)
            ..lineTo(17.8, 14.4),
          Path()
            ..moveTo(11.3, 21)
            ..lineTo(11.6, 21.2),
          Path()
            ..moveTo(24, 10.8)
            ..quadraticBezierTo(29.5, 14.5, 28.5, 24),
        ]);
        break;
      case 'q':
        shapes.addAll([
          _rr(10.5, 33, 24, 4, 1.5),
          _poly([13, 33, 9, 14, 16, 23, 15.5, 9.5, 21, 22, 22.5, 8, 24, 22,
            29.5, 9.5, 29, 23, 36, 14, 32, 33]),
          _c(9, 13, 2.3),
          _c(15.5, 8.5, 2.3),
          _c(22.5, 7, 2.3),
          _c(29.5, 8.5, 2.3),
          _c(36, 13, 2.3),
        ]);
        details.add(Path()
          ..moveTo(14, 29)
          ..lineTo(31, 29));
        break;
      case 'k':
        shapes.addAll([
          _rr(10.5, 33, 24, 4, 1.5),
          Path()
            ..moveTo(12.5, 33)
            ..cubicTo(10, 25, 14, 18.5, 22.5, 18.5)
            ..cubicTo(31, 18.5, 35, 25, 32.5, 33)
            ..close(),
          _rr(21, 4, 3, 13, 1),
          _rr(17.5, 7.5, 10, 3, 1),
        ]);
        details.add(Path()
          ..moveTo(15, 29)
          ..lineTo(30, 29));
        break;
    }
    for (final s in shapes) {
      canvas.drawPath(s, fill);
      canvas.drawPath(s, stroke);
    }
    for (final d in details) {
      canvas.drawPath(d, detail);
    }
    // subtle highlight on the left side of dark pieces
    if (!white) {
      canvas.drawPath(
          Path()
            ..moveTo(15.5, 31)
            ..lineTo(16.5, 26),
          shine);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.type != type || old.white != white;
}
