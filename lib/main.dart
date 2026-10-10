import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess/chess.dart' as ch;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ChessApp());
}

// ───────────── colors ─────────────
const kBg = Color(0xFF302E2B);
const kPanel = Color(0xFF262421);
const kGreen = Color(0xFF81B64C);
const kGreenDark = Color(0xFF45753C);
const kLight = Color(0xFFEBECD0);
const kDark = Color(0xFF739552);

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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: kPanel, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Text('العب بـ', style: TextStyle(fontSize: 16)),
                  const Spacer(),
                  _side(true),
                  const SizedBox(width: 10),
                  _side(false),
                ]),
              ),
              const SizedBox(height: 16),
              _big('مبتدئ', 'ضد الكمبيوتر - سهل', () => _go(true, 1, 'مبتدئ')),
              _big('متوسط', 'ضد الكمبيوتر - متوسط',
                  () => _go(true, 2, 'متوسط')),
              _big('متقدم', 'ضد الكمبيوتر - صعب', () => _go(true, 3, 'متقدم')),
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
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(5),
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

// ───────────── AI (runs in isolate) ─────────────
const _vals = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};
const _files = 'abcdefgh';

int _evalPos(ch.Chess g) {
  int s = 0;
  for (int r = 0; r < 8; r++) {
    for (int f = 0; f < 8; f++) {
      final p = g.get('${_files[f]}${8 - r}');
      if (p == null) continue;
      var v = _vals[p.type.toString()]!;
      final c = 3.5 - ((3.5 - r).abs() + (3.5 - f).abs()) / 2;
      v += (c * 5).round();
      s += p.color == ch.Color.WHITE ? v : -v;
    }
  }
  return s;
}

int _search(ch.Chess g, int depth, int alpha, int beta) {
  if (g.in_checkmate) {
    return g.turn == ch.Color.WHITE ? -99999 - depth : 99999 + depth;
  }
  if (g.in_draw) return 0;
  if (depth == 0) return _evalPos(g);
  final ms = g.moves({'asObjects': true}) as List;
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
  final ms = (g.moves({'asObjects': true}) as List).toList()
    ..shuffle(Random());
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

// ───────────── piece model ─────────────
class Pc {
  final int id;
  String type;
  final bool white;
  String sq;
  Pc(this.id, this.type, this.white, this.sq);
}

// ───────────── game page ─────────────
class GamePage extends StatefulWidget {
  final bool vsAI;
  final int depth;
  final String level;
  final bool playerWhite;
  const GamePage(
      {super.key,
      required this.vsAI,
      required this.depth,
      required this.level,
      required this.playerWhite});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  ch.Chess game = ch.Chess();
  List<Pc> pcs = [];
  int _nextId = 0;
  String? selected;
  List<String> targets = [];
  String? lastFrom, lastTo;
  bool thinking = false;
  bool flipped = false;
  bool resultShown = false;
  int epoch = 0;
  int whiteSecs = 600, blackSecs = 600;
  final ScrollController _sc = ScrollController();

  bool get aiWhite => !widget.playerWhite;
  ch.Color get aiColor => aiWhite ? ch.Color.WHITE : ch.Color.BLACK;

  @override
  void initState() {
    super.initState();
    flipped = !widget.playerWhite;
    _rebuild();
    _tick();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAI());
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
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
      if (game.history.isEmpty) continue; // clock starts after first move
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
                    Text(m, style: const TextStyle(fontSize: 17)),
                    const SizedBox(height: 22),
                    _greenBtn('لعبة جديدة', () {
                      Navigator.pop(context);
                      _reset();
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
    epoch++;
    setState(() {
      game = ch.Chess();
      selected = null;
      targets = [];
      lastFrom = lastTo = null;
      whiteSecs = blackSecs = 600;
      thinking = false;
      resultShown = false;
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

  void _click() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  void _tap(String sq) {
    if (thinking || game.game_over || resultShown || _aiToMove) return;
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
    if (mover.type == 'k' && (_files.indexOf(to[0]) - _files.indexOf(from[0])).abs() == 2) {
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

  void _doMove(String from, String to, String? promo) {
    final ok = game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'});
    if (!ok) return;
    _click();
    setState(() {
      _applyMove(from, to, promo);
      lastFrom = from;
      lastTo = to;
      selected = null;
      targets = [];
    });
    _scrollMoves();
    _checkEnd();
    _maybeAI();
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
    if (thinking && widget.vsAI) return;
    if (game.history.isEmpty) return;
    epoch++;
    game.undo_move();
    if (widget.vsAI && game.turn == aiColor && game.history.isNotEmpty) {
      game.undo_move();
    }
    setState(() {
      selected = null;
      targets = [];
      lastFrom = lastTo = null;
      thinking = false;
      resultShown = false;
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
            AspectRatio(aspectRatio: 1, child: _board()),
            const SizedBox(height: 6),
            _playerBar(bottomWhite),
            const Spacer(),
            _navBar(),
          ],
        ),
      ),
    );
  }

  Widget _moveStrip() {
    final sans = _sans();
    final items = <Widget>[];
    for (int i = 0; i < sans.length; i += 2) {
      items.add(Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(children: [
          Text('${i ~/ 2 + 1}. ',
              style: const TextStyle(color: Colors.white38, fontSize: 14)),
          Text(sans[i],
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          if (i + 1 < sans.length)
            Text(sans[i + 1],
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
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
    // pieces of the opposite color that this side captured
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
                    if (hl)
                      Container(color: const Color(0x80F6F669)),
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
            _nav(Icons.refresh, 'جديدة', _reset),
            _nav(Icons.swap_vert, 'قلب', () => setState(() => flipped = !flipped)),
            _nav(Icons.undo, 'تراجع', _undo),
            _nav(Icons.flag_outlined, 'استسلام', () {
              if (game.game_over || resultShown) return;
              final whiteResigns =
                  widget.vsAI ? widget.playerWhite : game.turn == ch.Color.WHITE;
              _end(whiteResigns ? 'استسلم الأبيض - فاز الأسود' : 'استسلم الأسود - فاز الأبيض');
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
            Text(t, style: const TextStyle(fontSize: 11, color: Colors.white54)),
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
    final fill = Paint()
      ..color = white ? const Color(0xFFFFFFFF) : const Color(0xFF4B4846);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF1A1A1A);
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = white ? const Color(0xFF1A1A1A) : const Color(0xFFEDEDED);

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
          Path()..addOval(Rect.fromCenter(center: const Offset(22.5, 15.5), width: 11, height: 15)),
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
            ..cubicTo(14, 25, 19, 24, 20.5, 18.5)
            ..cubicTo(18.5, 18.5, 16.5, 20, 14.5, 22)
            ..lineTo(11.5, 20)
            ..cubicTo(12, 16, 16, 12, 18, 8)
            ..lineTo(20.5, 9)
            ..cubicTo(22, 7, 25, 7, 27, 9)
            ..cubicTo(33, 12, 34, 22, 33, 33)
            ..close(),
        ]);
        details.addAll([
          Path()
            ..moveTo(20.8, 13.2)
            ..lineTo(21, 13.4),
          Path()
            ..moveTo(12.6, 20.6)
            ..lineTo(13.4, 20.6),
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(PiecePainter old) =>
      old.type != type || old.white != white;
}
