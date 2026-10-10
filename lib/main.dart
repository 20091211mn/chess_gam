import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Chess',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const MenuPage(),
      );
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});
  void _go(BuildContext c, bool ai, int depth) => Navigator.push(
      c, MaterialPageRoute(builder: (_) => GamePage(vsAI: ai, depth: depth)));
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF312E2B),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('♞ شطرنج',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            _btn(context, 'ضد الكمبيوتر (سهل)', () => _go(context, true, 1)),
            _btn(context, 'ضد الكمبيوتر (متوسط)', () => _go(context, true, 2)),
            _btn(context, 'ضد الكمبيوتر (صعب)', () => _go(context, true, 3)),
            _btn(context, 'لاعبان على نفس الجهاز', () => _go(context, false, 0)),
          ]),
        ),
      );
  Widget _btn(BuildContext c, String t, VoidCallback f) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 260,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF81B64C)),
            onPressed: f,
            child: Text(t, style: const TextStyle(fontSize: 17)),
          ),
        ),
      );
}

const _glyph = {
  'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚',
};
const _val = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};

class GamePage extends StatefulWidget {
  final bool vsAI;
  final int depth;
  const GamePage({super.key, required this.vsAI, required this.depth});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  ch.Chess game = ch.Chess();
  String? selected;
  List<String> targets = [];
  String? lastFrom, lastTo;
  bool thinking = false;
  int whiteSecs = 600, blackSecs = 600;
  bool timerOn = true;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (game.game_over || !timerOn) continue;
      setState(() {
        if (game.turn == ch.Color.WHITE) {
          whiteSecs--;
        } else {
          blackSecs--;
        }
      });
      if (whiteSecs <= 0 || blackSecs <= 0) {
        timerOn = false;
        _msg(whiteSecs <= 0 ? 'انتهى وقت الأبيض - فاز الأسود' : 'انتهى وقت الأسود - فاز الأبيض');
      }
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(m),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _reset();
                    },
                    child: const Text('لعبة جديدة')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق')),
              ],
            ));
  }

  void _reset() => setState(() {
        game = ch.Chess();
        selected = null;
        targets = [];
        lastFrom = lastTo = null;
        whiteSecs = blackSecs = 600;
        timerOn = true;
      });

  String _sq(int r, int f) => '${'abcdefgh'[f]}${8 - r}';

  void _checkEnd() {
    if (game.in_checkmate) {
      timerOn = false;
      _msg(game.turn == ch.Color.WHITE ? 'كش مات - فاز الأسود' : 'كش مات - فاز الأبيض');
    } else if (game.in_stalemate) {
      _msg('تعادل (ستالميت)');
    } else if (game.in_draw) {
      _msg('تعادل');
    }
  }

  void _tap(String sq) {
    if (thinking || game.game_over) return;
    if (widget.vsAI && game.turn == ch.Color.BLACK) return;
    final p = game.get(sq);
    if (selected != null && targets.contains(sq)) {
      _play(selected!, sq);
      return;
    }
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

  void _play(String from, String to) {
    game.move({'from': from, 'to': to, 'promotion': 'q'});
    setState(() {
      lastFrom = from;
      lastTo = to;
      selected = null;
      targets = [];
    });
    _checkEnd();
    if (widget.vsAI && !game.game_over && game.turn == ch.Color.BLACK) {
      setState(() => thinking = true);
      Future.delayed(const Duration(milliseconds: 300), _aiMove);
    }
  }

  int _eval() {
    int s = 0;
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = game.get(_sq(r, f));
        if (p == null) continue;
        var v = _val[p.type.toString()]!;
        // small centre bonus
        final c = 3.5 - ((3.5 - r).abs() + (3.5 - f).abs()) / 2;
        v += (c * 4).round();
        s += p.color == ch.Color.WHITE ? v : -v;
      }
    }
    return s;
  }

  int _search(int depth, int alpha, int beta) {
    if (game.in_checkmate) {
      return game.turn == ch.Color.WHITE ? -99999 - depth : 99999 + depth;
    }
    if (game.in_draw) return 0;
    if (depth == 0) return _eval();
    final ms = game.moves({'asObjects': true}) as List;
    final white = game.turn == ch.Color.WHITE;
    int best = white ? -1000000 : 1000000;
    for (final m in ms) {
      game.move(m);
      final v = _search(depth - 1, alpha, beta);
      game.undo_move();
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

  void _aiMove() {
    final ms = (game.moves({'asObjects': true}) as List).toList()..shuffle();
    dynamic bestMove;
    int best = 1000000;
    for (final m in ms) {
      game.move(m);
      final v = _search(widget.depth - 1, -1000000, 1000000);
      game.undo_move();
      if (v < best) {
        best = v;
        bestMove = m;
      }
    }
    if (bestMove != null) {
      final f = bestMove.fromAlgebraic as String;
      final t = bestMove.toAlgebraic as String;
      game.move(bestMove);
      lastFrom = f;
      lastTo = t;
    }
    if (!mounted) return;
    setState(() => thinking = false);
    _checkEnd();
  }

  String _fmt(int s) {
    if (s < 0) s = 0;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _clock(String name, int secs, bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: active ? const Color(0xFF81B64C) : const Color(0xFF262421),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Text(_fmt(secs),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final whiteTurn = game.turn == ch.Color.WHITE;
    return Scaffold(
      backgroundColor: const Color(0xFF312E2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF262421),
        title: Text(widget.vsAI ? 'ضد الكمبيوتر' : 'لاعبان'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: thinking
                ? null
                : () {
                    setState(() {
                      game.undo_move();
                      if (widget.vsAI) game.undo_move();
                      selected = null;
                      targets = [];
                      lastFrom = lastTo = null;
                    });
                  },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reset),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _clock('الأسود', blackSecs, !whiteTurn && !game.game_over),
            const SizedBox(height: 10),
            AspectRatio(aspectRatio: 1, child: _board()),
            const SizedBox(height: 10),
            _clock('الأبيض', whiteSecs, whiteTurn && !game.game_over),
            const SizedBox(height: 10),
            Text(
              thinking
                  ? 'الكمبيوتر يفكر...'
                  : game.in_check
                      ? 'كش!'
                      : whiteTurn
                          ? 'دور الأبيض'
                          : 'دور الأسود',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board() => Column(
        children: List.generate(
            8,
            (r) => Expanded(
                  child: Row(
                    children: List.generate(8, (f) {
                      final sq = _sq(r, f);
                      final p = game.get(sq);
                      final dark = (r + f) % 2 == 1;
                      Color bg = dark
                          ? const Color(0xFF769656)
                          : const Color(0xFFEEEED2);
                      if (sq == lastFrom || sq == lastTo) {
                        bg = dark
                            ? const Color(0xFFBACA2B)
                            : const Color(0xFFF6F669);
                      }
                      if (sq == selected) bg = const Color(0xFFF6F669);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _tap(sq),
                          child: Container(
                            color: bg,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (p != null)
                                  LayoutBuilder(
                                    builder: (_, c) => Text(
                                      _glyph[p.type.toString()]!,
                                      style: TextStyle(
                                        fontSize: c.maxWidth * 0.8,
                                        height: 1,
                                        color: p.color == ch.Color.WHITE
                                            ? Colors.white
                                            : Colors.black,
                                        shadows: p.color == ch.Color.WHITE
                                            ? const [
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 3),
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 3)
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                if (targets.contains(sq))
                                  Container(
                                    width: p == null ? 14 : 40,
                                    height: p == null ? 14 : 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: p == null
                                          ? Colors.black26
                                          : null,
                                      border: p == null
                                          ? null
                                          : Border.all(
                                              color: Colors.black38,
                                              width: 4),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                )),
      );
}
