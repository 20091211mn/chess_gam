import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chess/chess.dart' as ch;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'backend_api.dart';
import 'backend_impl.dart';

// ───────────── online server (change after you deploy it) ─────────────
const kServerUrl = 'wss://YOUR-SERVER.onrender.com';

// ───────────── colors ─────────────
const kBg = Color(0xFF302E2B);
const kPanel = Color(0xFF262421);
const kGreen = Color(0xFF81B64C);
const kGreenDark = Color(0xFF45753C);
const kLight = Color(0xFFEBECD0);
const kDark = Color(0xFF739552);
int gTheme = 0;
const List<List<Color>> kThemes = [
  [Color(0xFFEBECD0), Color(0xFF739552)],
  [Color(0xFFF0D9B5), Color(0xFFB58863)],
  [Color(0xFFDEE3E6), Color(0xFF8CA2AD)],
  [Color(0xFFEEEEEE), Color(0xFF9B7EBD)],
  [Color(0xFFFFFFDD), Color(0xFF86A666)],
  [Color(0xFFE5D4B7), Color(0xFFA67C52)],
  [Color(0xFFD6EAF8), Color(0xFF5B8DB8)],
  [Color(0xFFFFE0E0), Color(0xFFC06C84)],
];

class TC {
  final int min;
  final int inc;
  final String label;
  const TC(this.min, this.inc, this.label);
}

const List<TC> kTCs = [
  TC(1, 0, '1 د'),
  TC(1, 1, '1 | 1'),
  TC(2, 1, '2 | 1'),
  TC(3, 0, '3 د'),
  TC(3, 2, '3 | 2'),
  TC(5, 0, '5 د'),
  TC(10, 0, '10 د'),
  TC(15, 10, '15 | 10'),
  TC(30, 0, '30 د'),
];

const Map<String, String> kCatLabel = {
  'bullet': 'Bullet',
  'blitz': 'Blitz',
  'rapid': 'Rapid',
};

String catOf(int min, int inc) {
  final t = min * 60 + inc * 40;
  return t < 180 ? 'bullet' : (t < 600 ? 'blitz' : 'rapid');
}

const List<String> kTierName = ['مجاني', 'فضي', 'ذهبي', 'ماسي'];
const List<String> kTierBadge = ['', '🥈', '🥇', '💎'];
const List<Color> kTierColor = [
  Color(0xFF9E9E9E),
  Color(0xFFC0C0C0),
  Color(0xFFFFC107),
  Color(0xFF4FC3F7),
];
const List<int> kFriendLimit = [10, 30, 100, 300];
const List<int> kHistoryLimit = [10, 50, 100, 300];
const List<String> kPlanIds = [
  '',
  'silver_monthly',
  'gold_monthly',
  'diamond_monthly'
];
const List<List<String>> kPlanFeatures = [
  [],
  [
    'بدون إعلانات',
    'تلميحات غير محدودة',
    'ملخص مراجعة غير محدود',
    'كل ألوان الرقعة (8)',
    'يفتح اللاعب "خالد" (1600)',
    'حتى 30 صديقاً',
    'سجل آخر 50 مباراة',
    'شارة 🥈 بجانب اسمك',
  ],
  [
    'كل مزايا الفضي',
    'يفتح اللاعب "الخبير" (1900)',
    'حتى 100 صديق',
    'سجل آخر 100 مباراة',
    'شارة 🥇 بجانب اسمك',
  ],
  [
    'كل مزايا الذهبي',
    'يفتح اللاعب "تيتان" (2200)',
    'حتى 300 صديق',
    'سجل آخر 300 مباراة',
    'شارة 💎 بجانب اسمك',
  ],
];
const List<String> kChat = [
  'مرحباً 👋',
  'حظاً موفقاً',
  'نقلة جيدة!',
  'شكراً',
  'أحسنت 👏',
  'دقيقة من فضلك',
  'هل نتعادل؟',
  'مباراة ممتعة',
];

class Bot {
  final String name;
  final int rating;
  final int depth;
  final int blunder;
  final Color color;
  final int tier;
  const Bot(this.name, this.rating, this.depth, this.blunder, this.color,
      [this.tier = 0]);
}

const List<Bot> kBots = [
  Bot('نور', 400, 1, 45, Color(0xFF8E7CC3)),
  Bot('سالم', 700, 1, 20, Color(0xFF6FA8DC)),
  Bot('عمر', 1000, 2, 15, Color(0xFF93C47D)),
  Bot('ليلى', 1300, 2, 5, Color(0xFFF6B26B)),
  Bot('خالد', 1600, 3, 2, Color(0xFFE06666), 1),
  Bot('الخبير', 1900, 99, 0, Color(0xFFB45F06), 2),
  Bot('تيتان', 2200, 98, 0, Color(0xFF674EA7), 3),
];

class Prefs {
  static SharedPreferences? prefs;
  static bool sound = true;
  static bool autoQueen = false;
  static bool showLegal = true;
  static bool showCoords = true;
  static int increment = 0;
  static int minutes = 10;
  static int tcIdx = 6;
  static String name = 'لاعب';
  static String pid = '';
  static String serverUrl = kServerUrl;
  static bool usedOnline = false;
  static int storeTier = 0;
  static int serverTier = 0;
  static int serverUntil = 0;
  static String lastError = '';
  static bool safeMode = false;
  static int bonusHints = 0;
  static int puzzlesSolved = 0;
  static int reviewsOpened = 0;
  static int streak = 0;
  static int trialUntil = 0;
  static int trialAds = 0;
  static int trialCool = 0;

  static int get tier {
    int t = storeTier;
    if (serverUntil > DateTime.now().millisecondsSinceEpoch &&
        serverTier > t) {
      t = serverTier;
    }
    if (t < 1 && trialUntil > DateTime.now().millisecondsSinceEpoch) t = 1;
    return t.clamp(0, 3).toInt();
  }

  static bool get trialActive =>
      trialUntil > DateTime.now().millisecondsSinceEpoch;

  static bool get hasPaidPlan {
    final now = DateTime.now().millisecondsSinceEpoch;
    return storeTier > 0 || (serverUntil > now && serverTier > 0);
  }

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    prefs = p;
    sound = p.getBool('sound') ?? true;
    autoQueen = p.getBool('autoQueen') ?? false;
    showLegal = p.getBool('showLegal') ?? true;
    showCoords = p.getBool('showCoords') ?? true;
    tcIdx = (p.getInt('tc') ?? 6).clamp(0, kTCs.length - 1).toInt();
    minutes = kTCs[tcIdx].min;
    increment = kTCs[tcIdx].inc;
    final rnd = Random();
    name = p.getString('name') ?? 'لاعب${100 + rnd.nextInt(900)}';
    pid = p.getString('pid') ??
        List.generate(
                16, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[rnd.nextInt(36)])
            .join();
    serverUrl = p.getString('server') ?? kServerUrl;
    usedOnline = p.getBool('uo') ?? false;
    storeTier = p.getInt('stier') ?? 0;
    serverTier = p.getInt('svtier') ?? 0;
    serverUntil = p.getInt('svuntil') ?? 0;
    lastError = p.getString('lasterr') ?? '';
    safeMode = p.getBool('safe') ?? false;
    bonusHints = p.getInt('bonus') ?? 0;
    puzzlesSolved = p.getInt('psolved') ?? 0;
    reviewsOpened = p.getInt('rvopen') ?? 0;
    streak = p.getInt('streak') ?? 0;
    trialUntil = p.getInt('trialuntil') ?? 0;
    trialAds = p.getInt('trialads') ?? 0;
    trialCool = p.getInt('trialcool') ?? 0;
    final nowD = DateTime.now();
    String dstr(DateTime d) => '${d.year}-${d.month}-${d.day}';
    final lastDay = p.getString('lastday') ?? '';
    if (lastDay != dstr(nowD)) {
      streak = (lastDay == dstr(nowD.subtract(const Duration(days: 1))))
          ? streak + 1
          : 1;
      p.setString('lastday', dstr(nowD));
      p.setInt('streak', streak);
    }
    gTheme = p.getInt('theme') ?? 0;
    if (gTheme < 0 || gTheme >= kThemes.length) gTheme = 0;
    if (gTheme >= 3 && tier < 1) gTheme = 0;
    save();
  }

  static void save() {
    final p = prefs;
    if (p == null) return;
    p.setBool('sound', sound);
    p.setBool('autoQueen', autoQueen);
    p.setBool('showLegal', showLegal);
    p.setBool('showCoords', showCoords);
    p.setInt('tc', tcIdx);
    p.setString('name', name);
    p.setString('pid', pid);
    p.setString('server', serverUrl);
    p.setBool('uo', usedOnline);
    p.setInt('stier', storeTier);
    p.setInt('svtier', serverTier);
    p.setInt('svuntil', serverUntil);
    p.setString('lasterr', lastError);
    p.setBool('safe', safeMode);
    p.setInt('bonus', bonusHints);
    p.setInt('psolved', puzzlesSolved);
    p.setInt('rvopen', reviewsOpened);
    p.setInt('trialuntil', trialUntil);
    p.setInt('trialads', trialAds);
    p.setInt('trialcool', trialCool);
    p.setInt('theme', gTheme);
  }

  static void setTc(int i) {
    tcIdx = i;
    minutes = kTCs[i].min;
    increment = kTCs[i].inc;
    save();
  }

  static int rating(String c) => prefs?.getInt('lr_$c') ?? 800;
  static void setRating(String c, int v) {
    prefs?.setInt('lr_$c', v);
  }

  static int oRating(String c) => prefs?.getInt('or_$c') ?? 800;
  static void setORating(String c, int v) {
    prefs?.setInt('or_$c', v);
  }

  static List<Map<String, dynamic>> mistakes() {
    final raw = prefs?.getString('mist');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void addMistake(Map<String, dynamic> m) {
    final l = mistakes();
    l.removeWhere((x) => x['fen'] == m['fen']);
    l.insert(0, m);
    while (l.length > 40) {
      l.removeLast();
    }
    prefs?.setString('mist', jsonEncode(l));
  }

  static void removeMistake(String fen) {
    final l = mistakes();
    l.removeWhere((x) => x['fen'] == fen);
    prefs?.setString('mist', jsonEncode(l));
  }

  static List<int> ratingHistory(String kind, String cat) {
    final raw = prefs?.getString('rh_${kind}_$cat') ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((e) => int.tryParse(e) ?? 800).toList();
  }

  static void addRatingPoint(String kind, String cat, int v) {
    final l = ratingHistory(kind, cat);
    if (l.isEmpty) l.add(800);
    l.add(v);
    while (l.length > 60) {
      l.removeAt(0);
    }
    prefs?.setString('rh_${kind}_$cat', l.join(','));
  }

  static int stat(String k) => prefs?.getInt(k) ?? 0;

  static void bump(String prefix, int outcome) {
    final p = prefs;
    if (p == null) return;
    final k = prefix + (outcome > 0 ? '_w' : (outcome < 0 ? '_l' : '_d'));
    p.setInt(k, (p.getInt(k) ?? 0) + 1);
  }

  static void resetStats() {
    final p = prefs;
    if (p == null) return;
    for (final k in ['ai_w', 'ai_l', 'ai_d', 'on_w', 'on_l', 'on_d']) {
      p.remove(k);
    }
  }

  // free users have daily limits (hints, reviews)
  static bool useDaily(String key, int limit) {
    final p = prefs;
    if (p == null) return true;
    final now = DateTime.now();
    final day = '${now.year}-${now.month}-${now.day}';
    if (p.getString('dd_$key') != day) {
      p.setString('dd_$key', day);
      p.setInt('dn_$key', 0);
    }
    final n = p.getInt('dn_$key') ?? 0;
    if (n >= limit) return false;
    p.setInt('dn_$key', n + 1);
    return true;
  }

  static List<Map<String, dynamic>> history() {
    final raw = prefs?.getString('hist');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static void addHistory(Map<String, dynamic> g) {
    final l = history();
    l.insert(0, g);
    final cap = kHistoryLimit[tier];
    while (l.length > cap) {
      l.removeLast();
    }
    prefs?.setString('hist', jsonEncode(l));
  }
}

AppLifecycleListener? _lifecycleGuard;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Prefs.load();
  } catch (_) {}
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    Prefs.lastError = d.exceptionAsString();
    Prefs.save();
  };
  WidgetsBinding.instance.platformDispatcher.onError = (e, st) {
    Prefs.lastError = '$e';
    Prefs.save();
    return true;
  };
  // crash guard: if the previous launch never finished, start in safe mode
  final lp = Prefs.prefs;
  if (lp != null && (lp.getBool('launching') ?? false)) {
    Prefs.safeMode = true;
    Prefs.save();
  }
  lp?.setBool('launching', true);
  Future.delayed(const Duration(seconds: 8), () {
    Prefs.prefs?.setBool('launching', false);
  });
  _lifecycleGuard = AppLifecycleListener(onPause: () {
    Prefs.prefs?.setBool('launching', false);
  });
  Store.init();
  Future.delayed(const Duration(seconds: 2), Ads.init);
  if (Prefs.usedOnline) Hub.ensure();
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
        navigatorKey: navKey,
        builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox()),
        home: const MenuPage(),
      );
}

// ───────────── network ─────────────
class Net {
  late final WebSocketChannel chan;
  void Function(Map m)? onMsg;
  bool closed = false;

  Net(String url) {
    chan = WebSocketChannel.connect(Uri.parse(url));
    chan.stream.listen((d) {
      try {
        final m = jsonDecode(d as String);
        if (m is Map) onMsg?.call(m);
      } catch (_) {}
    },
        onDone: () => onMsg?.call({'t': 'closed'}),
        onError: (_) => onMsg?.call({'t': 'closed'}));
  }

  void send(Map m) {
    if (closed) return;
    try {
      chan.sink.add(jsonEncode(m));
    } catch (_) {}
  }

  void close() {
    if (closed) return;
    closed = true;
    try {
      chan.sink.close();
    } catch (_) {}
  }
}

class OnlineGame {
  String color = 'w';
  String oppName = 'الخصم';
  int oppRating = 0;
  int oppTier = 0;
  int myRating = 0;
  int min = 10;
  int inc = 0;
  String cat = 'blitz';

  void apply(Map m) {
    color = m['color'] == 'b' ? 'b' : 'w';
    final o = m['opp'];
    if (o is Map) {
      oppName = (o['name'] ?? 'الخصم').toString();
      oppRating = (o['rating'] as num?)?.toInt() ?? 0;
      oppTier = (o['tier'] as num?)?.toInt() ?? 0;
    }
    final y = m['you'];
    if (y is Map) myRating = (y['rating'] as num?)?.toInt() ?? 0;
    min = (m['min'] as num?)?.toInt() ?? min;
    inc = (m['inc'] as num?)?.toInt() ?? inc;
    cat = (m['cat'] ?? cat).toString();
  }
}

// ───────────── subscriptions (store) ─────────────
class Store {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static bool available = false;
  static Map<String, ProductDetails> products = {};
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static const Map<String, int> ids = {
    'silver_monthly': 1,
    'gold_monthly': 2,
    'diamond_monthly': 3,
  };
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static bool _gotActive = false;
  static String lastError = '';

  static Future<void> init() async {
    if (Prefs.safeMode) {
      tick.value++;
      return;
    }
    try {
      available = await _iap.isAvailable();
      if (!available) {
        tick.value++;
        return;
      }
      _sub ??= _iap.purchaseStream.listen(_onPurchases,
          onError: (Object e) {
        lastError = '$e';
      });
      final r = await _iap.queryProductDetails(ids.keys.toSet());
      for (final d in r.productDetails) {
        products[d.id] = d;
      }
      await _iap.restorePurchases();
      Future.delayed(const Duration(seconds: 6), () {
        if (!_gotActive && Prefs.storeTier != 0) {
          Prefs.storeTier = 0;
          Prefs.save();
          Hub.refreshHello();
          tick.value++;
        }
      });
    } catch (e) {
      lastError = '$e';
    }
    tick.value++;
  }

  static Future<void> _onPurchases(List<PurchaseDetails> list) async {
    int best = 0;
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        final t = ids[p.productID] ?? 0;
        if (t > best) best = t;
      }
      if (p.status == PurchaseStatus.error) {
        Hub.toast('تعذر إتمام عملية الشراء');
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    if (best > 0) {
      _gotActive = true;
      if (best != Prefs.storeTier) {
        Prefs.storeTier = best;
        Prefs.save();
        Hub.refreshHello();
        Hub.toast('تم تفعيل اشتراكك: ${kTierName[best]}');
      }
    }
    tick.value++;
  }

  static Future<void> buy(String id) async {
    final pd = products[id];
    if (!available || pd == null) {
      Hub.toast('الاشتراك غير متاح الآن. يتطلب التثبيت من المتجر أو استخدم كود هدية.');
      return;
    }
    try {
      await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: pd));
    } catch (e) {
      Hub.toast('تعذر بدء عملية الشراء');
    }
  }

  static Future<void> restore() async {
    if (!available) {
      Hub.toast('المتجر غير متاح');
      return;
    }
    try {
      await _iap.restorePurchases();
      Hub.toast('جاري استعادة المشتريات...');
    } catch (_) {}
  }
}

// ───────────── hub: one persistent connection ─────────────
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

class Hub {
  static Backend? be;
  static bool want = false;
  static bool inGame = false;
  static bool _up = false;
  static String status = '';
  static List friends = [];
  static List reqIn = [];
  static List reqOut = [];
  static String myCode = '';
  static OnlineGame? game;
  static void Function(Map m)? gameHandler;
  static void Function(Map m)? pageHandler;
  static final List<Map> pending = [];
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static Timer? _rt;

  static bool get connected => be != null && _up;

  static Map _helloMsg() => {
        't': 'hello',
        'id': Prefs.pid,
        'name': Prefs.name,
        'stier': Prefs.storeTier,
        'ig': inGame,
      };

  static void ensure() {
    want = true;
    if (be != null) return;
    final b = createBackend();
    be = b;
    b.start((m) {
      if (!identical(be, b)) return;
      _onMsg(m);
    });
    b.send(_helloMsg());
    b.send({'t': 'friends'});
  }

  static void refreshHello() {
    be?.send(_helloMsg());
  }

  static void send(Map m) {
    ensure();
    be?.send(m);
  }

  static void reset() {
    _rt?.cancel();
    final old = be;
    be = null;
    _up = false;
    old?.stop();
    ensure();
    tick.value++;
  }

  static void toast(String t) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
        SnackBar(content: Text(t), duration: const Duration(seconds: 3)));
  }

  static void setGameHandler(void Function(Map m) h) {
    gameHandler = h;
    final copy = List<Map>.from(pending);
    pending.clear();
    for (final m in copy) {
      h(m);
    }
  }

  static void clearGame() {
    gameHandler = null;
    inGame = false;
    game = null;
    pending.clear();
  }

  static void _pushGame(OnlineGame g) {
    inGame = true;
    navKey.currentState?.push(MaterialPageRoute(
        builder: (_) => GamePage(
            vsAI: false,
            depth: 0,
            level: '',
            playerWhite: g.color == 'w',
            minutes: g.min,
            inc: g.inc,
            og: g)));
  }

  static void _showChallenge(Map m) {
    final ctx = navKey.currentContext;
    if (ctx == null) return;
    final from = (m['from'] is Map)
        ? ((m['from'] as Map)['name'] ?? 'صديق').toString()
        : 'صديق';
    final mn = (m['min'] as num?)?.toInt() ?? 10;
    final inc = (m['inc'] as num?)?.toInt() ?? 0;
    final cid = m['cid'];
    showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dctx) => AlertDialog(
              backgroundColor: kPanel,
              title: const Text('طلب مباراة'),
              content: Text(
                  '$from يتحداك لمباراة $mn | $inc (${kCatLabel[catOf(mn, inc)]})'),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(dctx);
                      send({'t': 'challenge_decline', 'cid': cid});
                    },
                    child: const Text('رفض')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(dctx);
                      send({'t': 'challenge_accept', 'cid': cid});
                    },
                    child: const Text('قبول')),
              ],
            ));
  }

  static void _onMsg(Map m) {
    switch (m['t']) {
      case 'hi':
        _up = true;
        final r = m['r'];
        if (r is Map) {
          for (final c in ['bullet', 'blitz', 'rapid']) {
            final v = r[c];
            if (v is num) Prefs.setORating(c, v.toInt());
          }
        }
        Prefs.serverTier = (m['tier'] as num?)?.toInt() ?? 0;
        Prefs.serverUntil = (m['until'] as num?)?.toInt() ?? 0;
        if (m['code'] != null) myCode = m['code'].toString();
        Prefs.save();
        tick.value++;
        break;
      case 'friends':
        friends = (m['list'] as List?) ?? [];
        reqIn = (m['reqIn'] as List?) ?? [];
        reqOut = (m['reqOut'] as List?) ?? [];
        if (m['code'] != null) myCode = m['code'].toString();
        tick.value++;
        break;
      case 'presence':
        for (final f in friends) {
          if (f is Map && f['id'] == m['id']) f['online'] = m['online'];
        }
        tick.value++;
        break;
      case 'friend_req':
        toast('طلب صداقة جديد من ${m['name']}');
        break;
      case 'friend_ok':
      case 'friend_err':
      case 'challenge_err':
      case 'plan_err':
        toast((m['msg'] ?? '').toString());
        break;
      case 'challenge':
        _showChallenge(m);
        break;
      case 'challenge_sent':
        toast('تم إرسال طلب المباراة، بانتظار الرد...');
        break;
      case 'challenge_declined':
        toast('${m['name']} رفض المباراة');
        break;
      case 'challenge_cancelled':
        toast('أُلغي طلب المباراة');
        break;
      case 'plan':
        Prefs.serverTier = (m['tier'] as num?)?.toInt() ?? 0;
        Prefs.serverUntil = (m['until'] as num?)?.toInt() ?? 0;
        Prefs.save();
        toast('تم تفعيل الاشتراك: ${kTierName[Prefs.tier]}');
        tick.value++;
        break;
      case 'waiting':
        status = 'waiting';
        tick.value++;
        break;
      case 'top':
        pageHandler?.call(m);
        break;
      case 'start':
        status = '';
        tick.value++;
        if (gameHandler != null) {
          gameHandler!(m);
        } else {
          final g = OnlineGame()..apply(m);
          game = g;
          _pushGame(g);
        }
        break;
      case 'resume':
        if (gameHandler != null) {
          gameHandler!(m);
        } else {
          pending.add(m);
          if (!inGame) {
            final g = OnlineGame()..apply(m);
            game = g;
            _pushGame(g);
          }
        }
        break;
      case 'move':
      case 'clock':
      case 'end':
      case 'draw_offer':
      case 'draw_declined':
      case 'rematch_offer':
      case 'chat':
      case 'opp_disc':
      case 'opp_back':
      case 'no_game':
        if (gameHandler != null) {
          gameHandler!(m);
        } else if (inGame) {
          pending.add(m);
        }
        break;
      case 'unavailable':
        _up = false;
        be = null;
        status = '';
        tick.value++;
        toast((m['msg'] ?? 'اللعب الأونلاين غير متاح').toString());
        break;
      case 'closed':
        _up = false;
        be = null;
        status = '';
        tick.value++;
        gameHandler?.call(m);
        if (want) {
          _rt?.cancel();
          _rt = Timer(const Duration(seconds: 3), ensure);
        }
        break;
    }
  }
}

// ───────────── menu ─────────────
Widget bigButton(String t, String sub, VoidCallback f, {bool alt = false}) =>
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

class TcPicker extends StatefulWidget {
  final VoidCallback? onChanged;
  const TcPicker({super.key, this.onChanged});
  @override
  State<TcPicker> createState() => _TcPickerState();
}

class _TcPickerState extends State<TcPicker> {
  Widget _group(String title, List<int> idx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, color: Colors.white60)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final i in idx)
              ChoiceChip(
                label: Text(kTCs[i].label),
                selected: Prefs.tcIdx == i,
                selectedColor: kGreen,
                onSelected: (_) {
                  setState(() => Prefs.setTc(i));
                  widget.onChanged?.call();
                },
              ),
          ]),
          const SizedBox(height: 8),
        ],
      );

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: kPanel, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('وقت اللعب', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          _group('Bullet', [0, 1, 2]),
          _group('Blitz', [3, 4, 5]),
          _group('Rapid', [6, 7, 8]),
        ]),
      );
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Store.tick.addListener(_r);
    Hub.tick.addListener(_r);
  }

  @override
  void dispose() {
    Store.tick.removeListener(_r);
    Hub.tick.removeListener(_r);
    super.dispose();
  }

  Future<void> _rename() async {
    final c = TextEditingController(text: Prefs.name);
    final v = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: kPanel,
              title: const Text('اسم اللاعب'),
              content: TextField(controller: c, maxLength: 16, autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                TextButton(
                    onPressed: () => Navigator.pop(context, c.text.trim()),
                    child: const Text('حفظ')),
              ],
            ));
    if (v != null && v.isNotEmpty) {
      setState(() {
        Prefs.name = v;
        Prefs.save();
      });
      Hub.refreshHello();
    }
  }

  Widget _ratingChip(String c) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: kBg, borderRadius: BorderRadius.circular(6)),
          child: Column(children: [
            Text(kCatLabel[c]!,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
            Text('${Prefs.rating(c)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  Widget _profile() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: kPanel, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: kGreen, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.person, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${Prefs.name} ${kTierBadge[Prefs.tier]}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('الخطة: ${kTierName[Prefs.tier]}',
                        style: TextStyle(
                            fontSize: 12, color: kTierColor[Prefs.tier])),
                  ]),
            ),
            IconButton(onPressed: _rename, icon: const Icon(Icons.edit, size: 20)),
          ]),
          const SizedBox(height: 10),
          const Text('تقييمك (ضد الكمبيوتر)',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 6),
          Row(children: [
            _ratingChip('bullet'),
            _ratingChip('blitz'),
            _ratingChip('rapid'),
          ]),
        ]),
      );

  void _go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: const SafeArea(child: AdBanner()),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
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
              const SizedBox(height: 18),
              _profile(),
              TcPicker(onChanged: () => setState(() {})),
              bigButton('العب أونلاين', 'ضد لاعبين حقيقيين بتقييم',
                  () => _go(const OnlinePage())),
              bigButton('الأصدقاء', 'أضف أصدقاءك وتحدَّهم لمباراة',
                  () => _go(const FriendsPage()),
                  alt: true),
              bigButton('العب ضد الكمبيوتر', 'لاعبون بتقييمات من 400 إلى 2200',
                  () => _go(const BotsPage()),
                  alt: true),
              bigButton('العب مع صديق', 'لاعبان على نفس الجهاز', () {
                _go(GamePage(
                    vsAI: false,
                    depth: 0,
                    level: '',
                    playerWhite: true,
                    minutes: Prefs.minutes,
                    inc: Prefs.increment));
              }, alt: true),
              bigButton(
                  'الاشتراكات',
                  Prefs.tier == 0
                      ? 'فضي • ذهبي • ماسي'
                      : 'خطتك الحالية: ${kTierName[Prefs.tier]} ${kTierBadge[Prefs.tier]}',
                  () => _go(const PlansPage())),
              bigButton('سجل المباريات', 'راجع مبارياتك بالتحليل وانسخ PGN',
                  () => _go(const HistoryPage()),
                  alt: true),
              bigButton('تعلّم من أخطائك',
                  '${Prefs.mistakes().length} موقف للتدريب',
                  () => _go(const MistakesPage()),
                  alt: true),
              bigButton('الإنجازات', 'سلسلة ${Prefs.streak} يوم',
                  () => _go(const AchievementsPage()),
                  alt: true),
              bigButton('الإحصائيات والإعدادات', 'سجلك وخيارات اللعبة',
                  () => _go(const SettingsPage()),
                  alt: true),
            ],
          ),
        ),
      );
}

// ───────────── ads (free plan only) ─────────────
// set to true while testing to show Google's test ads
const bool kTestAds = false;
// CI diagnostic: build with --dart-define=ADS_INIT=false to skip ads initialisation
const bool kAdsInit = bool.fromEnvironment('ADS_INIT', defaultValue: true);
const String kBannerId = 'ca-app-pub-7019939648590037/6914424873';
const String kTestBannerId = 'ca-app-pub-3940256099942544/6300978111';

class AdsDiag {
  static String init = 'لم تبدأ بعد';
  static String banner = 'لا يوجد طلب بعد';
  static String interstitial = '-';
  static String rewarded = '-';

  static void _p() {
    // visible in logcat (used by the CI emulator test)
    print(
        'ADS_DIAG init=$init | banner=$banner | rewarded=$rewarded | interstitial=$interstitial');
  }

  static void setInit(String v) {
    init = v;
    _p();
  }

  static void setBanner(String v) {
    banner = v;
    _p();
  }

  static void setInter(String v) {
    interstitial = v;
    _p();
  }

  static void setRewarded(String v) {
    rewarded = v;
    _p();
  }
}

class Ads {
  static final ValueNotifier<bool> ready = ValueNotifier(false);
  static bool _started = false;

  static void _consent() {
    try {
      final dynamic ci = ConsentInformation.instance;
      ci.requestConsentInfoUpdate(ConsentRequestParameters(), () async {
        try {
          final dynamic ok = await ci.isConsentFormAvailable();
          if (ok == true) {
            ConsentForm.loadAndShowConsentFormIfRequired((dynamic e) {});
          }
        } catch (_) {}
      }, (dynamic e) {});
    } catch (_) {}
  }

  static Future<void> init() async {
    if (_started || !kAdsInit || Prefs.safeMode || !Platform.isAndroid) {
      if (!_started) AdsDiag.setInit('معطلة');
      return;
    }
    _started = true;
    AdsDiag.setInit('جاري التهيئة');
    try {
      _consent();
      await MobileAds.instance.initialize();
      ready.value = true;
      AdsDiag.setInit('جاهزة ✓');
      AdsX.preload();
    } catch (e) {
      AdsDiag.setInit('فشل: $e');
    }
  }
}

// Google's test ids. Replace them with your own units from AdMob when you create them.
const String kInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
const String kRewardedId = 'ca-app-pub-7019939648590037/9320106686';
const String kTestRewardedId = 'ca-app-pub-3940256099942544/5224354917';
// true = the rewarded button shows Google's TEST rewarded ad (works before AdMob approves the account).
// Set it to false before you release the app to real users.
const bool kTestRewarded = true;

// free trial: watch kTrialAds rewarded ads -> kTrialDays days of the Silver plan
const int kTrialAds = 3;
const int kTrialDays = 3;

class AdsX {
  static InterstitialAd? _inter;
  static RewardedAd? _rew;
  static int _games = 0;

  static bool get ok =>
      Platform.isAndroid && !Prefs.safeMode && kAdsInit && Ads.ready.value;

  static void preload() {
    if (!ok || Prefs.tier > 0) return;
    if (_inter == null) {
      AdsDiag.setInter('جاري الطلب');
      InterstitialAd.load(
        adUnitId: kInterstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _inter = ad;
            AdsDiag.setInter('جاهز ✓');
          },
          onAdFailedToLoad: (e) {
            _inter = null;
            AdsDiag.setInter('فشل: $e');
          },
        ),
      );
    }
    if (_rew == null) {
      AdsDiag.setRewarded('جاري الطلب');
      RewardedAd.load(
        adUnitId: (kTestAds || kTestRewarded) ? kTestRewardedId : kRewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rew = ad;
            AdsDiag.setRewarded('جاهز ✓');
          },
          onAdFailedToLoad: (e) {
            _rew = null;
            AdsDiag.setRewarded('فشل: $e');
          },
        ),
      );
    }
  }

  static void gameFinished() {
    if (Prefs.tier > 0) return;
    _games++;
  }

  // shown between games, at most every 3rd game, free plan only
  static void maybeShowBetweenGames() {
    if (!ok || Prefs.tier > 0 || _games < 3) return;
    final ad = _inter;
    if (ad == null) {
      preload();
      return;
    }
    _games = 0;
    _inter = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preload();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        preload();
      },
    );
    ad.show();
  }

  static bool get rewardedReady => _rew != null;

  static void showRewarded(void Function() onReward) {
    final ad = _rew;
    if (ad == null) {
      preload();
      Hub.toast('لا يوجد إعلان جاهز الآن، حاول بعد قليل');
      return;
    }
    _rew = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        preload();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        preload();
      },
    );
    ad.show(onUserEarnedReward: (a, r) {
      onReward();
    });
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Ads.ready.addListener(_onReady);
    _onReady();
  }

  void _onReady() {
    if (Ads.ready.value && _ad == null) _load();
  }

  void _load() {
    if (!Platform.isAndroid || Prefs.tier > 0 || Prefs.safeMode) return;
    AdsDiag.setBanner('جاري الطلب');
    final ad = BannerAd(
      adUnitId: kTestAds ? kTestBannerId : kBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          AdsDiag.setBanner('تم التحميل ✓');
          if (mounted) {
            setState(() => _loaded = true);
          } else {
            a.dispose();
          }
        },
        onAdFailedToLoad: (a, e) {
          a.dispose();
          AdsDiag.setBanner('فشل: $e');
          _retry();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  int _tries = 0;

  void _retry() {
    if (_tries >= 5) return;
    _tries++;
    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted || _loaded) return;
      _ad = null;
      _load();
    });
  }

  @override
  void dispose() {
    Ads.ready.removeListener(_onReady);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (Prefs.tier > 0 || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad)),
    );
  }
}

// ───────────── bots ─────────────
class BotsPage extends StatefulWidget {
  const BotsPage({super.key});
  @override
  State<BotsPage> createState() => _BotsPageState();
}

class _BotsPageState extends State<BotsPage> {
  bool playWhite = true;

  Widget _side(bool white) => GestureDetector(
        onTap: () => setState(() => playWhite = white),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kPanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: playWhite == white ? kGreen : Colors.transparent,
                width: 3),
          ),
          child: CustomPaint(painter: PiecePainter('k', white)),
        ),
      );

  void _open(Bot b) {
    if (Prefs.tier < b.tier) {
      Hub.toast('هذا اللاعب يتطلب اشتراك ${kTierName[b.tier]}');
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const PlansPage()));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => GamePage(
                vsAI: true,
                depth: b.depth,
                level: b.name,
                botRating: b.rating,
                blunder: b.blunder,
                playerWhite: playWhite,
                minutes: Prefs.minutes,
                inc: Prefs.increment)));
  }

  Widget _tile(Bot b) {
    final locked = Prefs.tier < b.tier;
    return GestureDetector(
      onTap: () => _open(b),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: kPanel, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: b.color, borderRadius: BorderRadius.circular(8)),
            child: Text(b.name.substring(0, 1),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                      locked
                          ? 'يتطلب اشتراك ${kTierName[b.tier]} ${kTierBadge[b.tier]}'
                          : 'تقييم تقديري',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(6)),
            child: Text('${b.rating}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          Icon(locked ? Icons.lock : Icons.chevron_right),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = kTCs[Prefs.tcIdx];
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar: AppBar(
          backgroundColor: kPanel, title: const Text('العب ضد الكمبيوتر')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Text('العب بـ', style: TextStyle(fontSize: 16)),
          const Spacer(),
          _side(true),
          const SizedBox(width: 10),
          _side(false),
        ]),
        const SizedBox(height: 10),
        Text(
            'الوقت: ${tc.label} (${kCatLabel[catOf(tc.min, tc.inc)]}) - غيّره من الشاشة الرئيسية',
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 14),
        for (final b in kBots) _tile(b),
      ]),
    );
  }
}

// ───────────── plans (subscriptions) ─────────────
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});
  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final codeCtl = TextEditingController();
  Timer? _poll;
  int _pollN = 0;

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Prefs.usedOnline = true;
    Prefs.save();
    Store.tick.addListener(_r);
    Hub.tick.addListener(_r);
    Hub.ensure();
    AdsX.preload();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollN++;
      if (_pollN % 15 == 0 && !AdsX.rewardedReady) AdsX.preload();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    Store.tick.removeListener(_r);
    Hub.tick.removeListener(_r);
    codeCtl.dispose();
    super.dispose();
  }

  void _onTrialAd() {
    Prefs.trialAds++;
    if (Prefs.trialAds >= kTrialAds) {
      final now = DateTime.now().millisecondsSinceEpoch;
      Prefs.trialAds = 0;
      Prefs.trialUntil = now + kTrialDays * 86400000;
      Prefs.trialCool = Prefs.trialUntil + 7 * 86400000;
      Hub.toast('تم تفعيل الخطة الفضية لمدة $kTrialDays أيام!');
    }
    Prefs.save();
    if (mounted) setState(() {});
  }

  Widget _trialCard() {
    if (Prefs.hasPaidPlan || !Platform.isAndroid || Prefs.safeMode) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final active = Prefs.trialUntil > now;
    final cool = !active && Prefs.trialCool > now;
    String sub;
    if (active) {
      final h = ((Prefs.trialUntil - now) / 3600000).ceil();
      sub = 'التجربة فعّالة الآن: تنتهي بعد $h ساعة';
    } else if (cool) {
      final d = ((Prefs.trialCool - now) / 86400000).ceil();
      sub = 'يمكنك تجربة مجانية أخرى بعد $d يوم';
    } else {
      sub =
          'شاهد $kTrialAds إعلانات لتحصل على $kTrialDays أيام من الخطة الفضية مجاناً';
    }
    final canWatch = !active && !cool;
    final ready = AdsX.rewardedReady;
    final failed = AdsDiag.rewarded.contains('فشل');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF2F3B2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGreen, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.card_giftcard, color: kGreen),
          const SizedBox(width: 8),
          Text('جرّب الفضي $kTrialDays أيام مجاناً',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(sub, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        if (canWatch) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
              value: Prefs.trialAds / kTrialAds, minHeight: 6),
          const SizedBox(height: 4),
          Text('${Prefs.trialAds}/$kTrialAds إعلانات',
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          if (failed && !ready)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'الإعلانات غير متاحة الآن (تُفعَّل بعد موافقة AdMob على حسابك). سنعيد المحاولة تلقائياً.',
                  style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: ready
                ? () => AdsX.showRewarded(_onTrialAd)
                : () {
                    AdsX.preload();
                    Hub.toast(failed
                        ? 'الإعلانات غير متاحة الآن، حاول لاحقاً'
                        : 'جاري تجهيز الإعلان... حاول بعد لحظات');
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: ready ? kGreen : const Color(0xFF454240),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  ready
                      ? 'شاهد إعلاناً'
                      : (failed ? 'إعادة المحاولة' : 'جاري تجهيز الإعلان...'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _card(int t) {
    final id = kPlanIds[t];
    final pd = Store.products[id];
    final active = Prefs.tier >= t;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kTierColor[t], width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(kTierBadge[t], style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Text(kTierName[t],
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: kTierColor[t])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(pd?.price ?? '--',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Text('شهرياً',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
          ]),
        ]),
        const SizedBox(height: 10),
        for (final f in kPlanFeatures[t])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check, size: 16, color: kGreen),
              const SizedBox(width: 6),
              Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
            ]),
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: active ? null : () => Store.buy(id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: active ? const Color(0xFF454240) : kGreen,
                borderRadius: BorderRadius.circular(8)),
            child: Text(active ? 'مفعّل' : 'اشترك',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final until = Prefs.serverUntil;
    String untilTxt = '';
    if (until > DateTime.now().millisecondsSinceEpoch && Prefs.serverTier > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(until);
      untilTxt = ' (كود هدية حتى ${d.year}/${d.month}/${d.day})';
    }
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar: AppBar(backgroundColor: kPanel, title: const Text('الاشتراكات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: kPanel, borderRadius: BorderRadius.circular(10)),
          child: Text(
              'خطتك الحالية: ${kTierName[Prefs.tier]} ${kTierBadge[Prefs.tier]}$untilTxt',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const Text(
            'المجاني: مع إعلانات بانر، 5 تلميحات يومياً، ملخص مراجعة واحد يومياً، 3 ألوان رقعة، حتى 10 أصدقاء.',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 12),
        _trialCard(),
        _card(1),
        _card(2),
        _card(3),
        if (!Store.available)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
                'الشراء من المتجر غير متاح على هذه النسخة. الاشتراك يتطلب تثبيت التطبيق من Google Play أو App Store. يمكنك استخدام كود هدية بالأسفل.',
                style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
          ),
        TextButton(
            onPressed: Store.restore,
            child: const Text('استعادة المشتريات')),
        const SizedBox(height: 8),
        const Text('لديك كود هدية؟', style: TextStyle(fontSize: 15)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: codeCtl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final c = codeCtl.text.trim();
              if (c.isEmpty) return;
              Hub.send({'t': 'redeem', 'code': c});
              codeCtl.clear();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                  color: kGreen, borderRadius: BorderRadius.circular(8)),
              child: const Text('تفعيل',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ───────────── friends ─────────────
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final codeCtl = TextEditingController();

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Prefs.usedOnline = true;
    Prefs.save();
    Hub.tick.addListener(_r);
    Hub.ensure();
    Hub.send({'t': 'friends'});
  }

  @override
  void dispose() {
    Hub.tick.removeListener(_r);
    codeCtl.dispose();
    super.dispose();
  }

  Future<void> _copy(String t, String msg) async {
    await Clipboard.setData(ClipboardData(text: t));
    Hub.toast(msg);
  }

  Future<void> _challenge(Map f) async {
    final sel = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: kPanel,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('تحدَّ ${f['name']} - اختر الوقت',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  for (int i = 0; i < kTCs.length; i++)
                    ListTile(
                      title: Text(
                          '${kTCs[i].label}   •   ${kCatLabel[catOf(kTCs[i].min, kTCs[i].inc)]}'),
                      onTap: () => Navigator.pop(ctx, i),
                    ),
                ]),
              ),
            ));
    if (sel == null) return;
    Hub.send({
      't': 'challenge',
      'to': f['id'],
      'min': kTCs[sel].min,
      'inc': kTCs[sel].inc
    });
  }

  Widget _friendTile(Map f) {
    final on = f['online'] == true;
    final busy = f['inGame'] == true;
    final tier = ((f['tier'] as num?)?.toInt() ?? 0).clamp(0, 3).toInt();
    final r = f['r'];
    final blitz = (r is Map && r['blitz'] is num) ? (r['blitz'] as num).toInt() : 800;
    final nm = (f['name'] ?? '?').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: kPanel, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Stack(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(6)),
            child: Text(nm.isEmpty ? '?' : nm.substring(0, 1),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: on ? kGreen : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: kPanel, width: 2)),
            ),
          ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$nm ${kTierBadge[tier]}',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
                'Blitz $blitz  •  ${busy ? 'في مباراة' : (on ? 'متصل' : 'غير متصل')}',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.bolt),
          color: kGreen,
          onPressed: (on && !busy) ? () => _challenge(f) : null,
        ),
        IconButton(
          icon: const Icon(Icons.person_remove_outlined, size: 20),
          onPressed: () async {
            final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                      backgroundColor: kPanel,
                      title: Text('حذف $nm من الأصدقاء؟'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('لا')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('نعم')),
                      ],
                    ));
            if (ok == true) Hub.send({'t': 'friend_remove', 'id': f['id']});
          },
        ),
      ]),
    );
  }

  Widget _reqTile(Map f) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: kPanel, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(
              child: Text('${f['name']} يريد إضافتك',
                  style: const TextStyle(fontSize: 15))),
          IconButton(
              icon: const Icon(Icons.check_circle, color: kGreen),
              onPressed: () => Hub.send({'t': 'friend_accept', 'id': f['id']})),
          IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
              onPressed: () => Hub.send({'t': 'friend_decline', 'id': f['id']})),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final code = Hub.myCode;
    final limit = kFriendLimit[Prefs.tier];
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar: AppBar(backgroundColor: kPanel, title: const Text('الأصدقاء')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!Hub.connected)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF5A3A12),
                borderRadius: BorderRadius.circular(8)),
            child: const Text(
                'غير متصل بالسيرفر. تأكد من رابط السيرفر في شاشة "العب أونلاين".',
                style: TextStyle(fontSize: 13)),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: kPanel, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('كود الصداقة الخاص بك',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(code.isEmpty ? '...' : code,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4)),
              ),
              IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: code.isEmpty
                      ? null
                      : () => _copy(code, 'تم نسخ الكود')),
            ]),
            TextButton(
                onPressed: code.isEmpty
                    ? null
                    : () => _copy(
                        'العب الشطرنج معي! أضفني بكود الصداقة: $code',
                        'تم نسخ رسالة الدعوة'),
                child: const Text('نسخ رسالة دعوة لإرسالها لصديقك')),
          ]),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: codeCtl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'كود صديقك',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              final c = codeCtl.text.trim();
              if (c.isEmpty) return;
              Hub.send({'t': 'friend_add', 'code': c});
              codeCtl.clear();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                  color: kGreen, borderRadius: BorderRadius.circular(8)),
              child:
                  const Text('إضافة', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        if (Hub.reqIn.isNotEmpty) ...[
          const Text('طلبات الصداقة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final f in Hub.reqIn) if (f is Map) _reqTile(f),
          const SizedBox(height: 10),
        ],
        Text('الأصدقاء (${Hub.friends.length}/$limit)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (Hub.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('لا يوجد أصدقاء بعد. شارك كودك أو أضف كود صديقك.',
                style: TextStyle(color: Colors.white54)),
          ),
        for (final f in Hub.friends) if (f is Map) _friendTile(f),
        if (Hub.reqOut.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
              'طلبات مرسلة: ${Hub.reqOut.map((e) => (e is Map ? e['name'] : '').toString()).join('، ')}',
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ]),
    );
  }
}

// ───────────── online lobby ─────────────
class OnlinePage extends StatefulWidget {
  const OnlinePage({super.key});
  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  final urlCtl = TextEditingController(text: Prefs.serverUrl);
  final roomCtl = TextEditingController();

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Prefs.usedOnline = true;
    Prefs.save();
    Hub.tick.addListener(_r);
    Hub.ensure();
  }

  @override
  void dispose() {
    Hub.tick.removeListener(_r);
    urlCtl.dispose();
    roomCtl.dispose();
    super.dispose();
  }

  void _saveUrl() {
    Prefs.serverUrl = urlCtl.text.trim();
    Prefs.save();
    Hub.reset();
    Hub.toast('تم حفظ رابط السيرفر');
  }

  void _search(Map msg) {
    Hub.status = 'searching';
    Hub.tick.value++;
    Hub.send(msg);
  }

  void _cancel() {
    Hub.send({'t': 'cancel'});
    Hub.status = '';
    Hub.tick.value++;
  }

  Widget _ratingChip(String c) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: kPanel, borderRadius: BorderRadius.circular(6)),
          child: Column(children: [
            Text(kCatLabel[c]!,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
            Text('${Prefs.oRating(c)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tc = kTCs[Prefs.tcIdx];
    final searching = Hub.status == 'waiting' || Hub.status == 'searching';
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar:
          AppBar(backgroundColor: kPanel, title: const Text('لعب أونلاين')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: Hub.connected ? kGreen : Colors.redAccent,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(Hub.connected ? 'متصل بالسيرفر' : 'غير متصل',
              style: const TextStyle(fontSize: 14)),
          const Spacer(),
          TextButton(onPressed: Hub.reset, child: const Text('إعادة الاتصال')),
        ]),
        const SizedBox(height: 6),
        const Text('تقييمك أونلاين',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 6),
        Row(children: [
          _ratingChip('bullet'),
          _ratingChip('blitz'),
          _ratingChip('rapid'),
        ]),
        const SizedBox(height: 14),
        if (!searching) TcPicker(onChanged: () => setState(() {})),
        if (searching)
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: kPanel, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('جاري البحث عن خصم (${tc.label})...',
                  style: const TextStyle(fontSize: 16)),
              TextButton(onPressed: _cancel, child: const Text('إلغاء')),
            ]),
          ),
        _btn('مباراة سريعة (${tc.label})',
            searching ? null : () => _search({'t': 'quick', 'min': tc.min, 'inc': tc.inc})),
        const SizedBox(height: 14),
        TextField(
          controller: roomCtl,
          enabled: !searching,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'رمز الغرفة (اتفق عليه مع صديقك)',
              border: OutlineInputBorder(),
              isDense: true),
        ),
        const SizedBox(height: 10),
        _btn(
            'دخول الغرفة',
            searching
                ? null
                : () {
                    final r = roomCtl.text.trim();
                    if (r.isEmpty) {
                      Hub.toast('اكتب رمز الغرفة');
                      return;
                    }
                    _search(
                        {'t': 'join', 'room': r, 'min': tc.min, 'inc': tc.inc});
                  },
            alt: true),
        const SizedBox(height: 10),
        _btn(
            'الأصدقاء',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FriendsPage())),
            alt: true),
        const SizedBox(height: 10),
        _btn(
            'لوحة الصدارة',
            () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaderboardPage())),
            alt: true),
        const SizedBox(height: 14),
        ExpansionTile(
          title: const Text('إعدادات السيرفر'),
          children: [
            TextField(
              controller: urlCtl,
              decoration: const InputDecoration(
                  labelText: 'رابط السيرفر (wss://...)',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 8),
            _btn('حفظ وإعادة الاتصال', _saveUrl, alt: true),
          ],
        ),
      ]),
    );
  }

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

// ───────────── leaderboard ─────────────
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String cat = 'blitz';
  List list = [];
  String status = 'جاري التحميل...';

  @override
  void initState() {
    super.initState();
    Hub.pageHandler = (m) {
      if (!mounted) return;
      setState(() {
        list = (m['list'] as List?) ?? [];
        status = list.isEmpty ? 'لا يوجد لاعبون بعد' : '';
      });
    };
    Hub.send({'t': 'top', 'cat': cat});
  }

  @override
  void dispose() {
    Hub.pageHandler = null;
    super.dispose();
  }

  void _setCat(String c) {
    setState(() {
      cat = c;
      status = 'جاري التحميل...';
    });
    Hub.send({'t': 'top', 'cat': c});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
        appBar: AppBar(
            backgroundColor: kPanel, title: const Text('لوحة الصدارة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 8, children: [
            for (final c in ['bullet', 'blitz', 'rapid'])
              ChoiceChip(
                label: Text(kCatLabel[c]!),
                selected: cat == c,
                selectedColor: kGreen,
                onSelected: (_) => _setCat(c),
              ),
          ]),
          const SizedBox(height: 12),
          if (status.isNotEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(status),
            )),
          for (int i = 0; i < list.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: kPanel, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                SizedBox(
                    width: 34,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800))),
                Expanded(
                    child: Text('${(list[i] as Map)['name']}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16))),
                Text('${(list[i] as Map)['n']} مباراة  ',
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
                Text('${(list[i] as Map)['r']}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      );
}

// ───────────── history ─────────────
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = Prefs.history();
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar: AppBar(
          backgroundColor: kPanel, title: const Text('سجل المباريات')),
      body: list.isEmpty
          ? const Center(
              child: Text('لا توجد مباريات بعد',
                  style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final g = list[i];
                final res = (g['r'] ?? '*').toString();
                final me = (g['me'] ?? '').toString();
                String label = 'تعادل';
                Color col = Colors.amber;
                if (res == '1-0' || res == '0-1') {
                  final whiteWon = res == '1-0';
                  if (me.isEmpty) {
                    label = whiteWon ? 'فاز الأبيض' : 'فاز الأسود';
                    col = Colors.white70;
                  } else {
                    final won = whiteWon == (me == 'w');
                    label = won ? 'فوز' : 'خسارة';
                    col = won ? kGreen : Colors.redAccent;
                  }
                }
                final d = DateTime.fromMillisecondsSinceEpoch(
                    (g['d'] as num?)?.toInt() ?? 0);
                String two(int x) => x.toString().padLeft(2, '0');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: kPanel, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(
                        width: 6,
                        height: 40,
                        decoration: BoxDecoration(
                            color: col,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${g['o'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(
                                '$label  •  ${d.year}/${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white54)),
                          ]),
                    ),
                    if (g['uci'] is List && (g['uci'] as List).length >= 2)
                      IconButton(
                        icon: const Icon(Icons.analytics_outlined, size: 22),
                        color: kGreen,
                        onPressed: () {
                          if (Prefs.tier == 0 && !Prefs.useDaily('review2', 2)) {
                            Hub.toast('وصلت للحد اليومي (2). الاشتراك يفتح المراجعة بلا حدود');
                            Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                    builder: (_) => const PlansPage()));
                            return;
                          }
                          Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                  builder: (_) => ReviewPage(rec: g)));
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: (g['pgn'] ?? '').toString()));
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('تم نسخ PGN'),
                              duration: Duration(seconds: 1)));
                        }
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }
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

List _sortedMoves(ch.Chess g, {bool rnd = false}) {
  final ms = (g.moves({'asObjects': true}) as List).toList();
  if (ms.length < 2) return ms;
  final r = rnd ? Random() : null;
  final keyed = <List>[];
  for (final m in ms) {
    final cp = g.get(m.toAlgebraic as String);
    int sc = 0;
    if (cp != null) sc = 10 + (_vals[cp.type.toString()]! ~/ 100);
    sc = sc * 100 + (r == null ? 0 : r.nextInt(100));
    keyed.add([sc, m]);
  }
  keyed.sort((a, b) => (b[0] as int) - (a[0] as int));
  return [for (final k in keyed) k[1]];
}

int _quiesce(ch.Chess g, int alpha, int beta, int qd) {
  final all = g.moves({'asObjects': true}) as List;
  final white = g.turn == ch.Color.WHITE;
  if (all.isEmpty) {
    if (g.in_check) return white ? -99999 : 99999;
    return 0;
  }
  final stand = _evalPos(g);
  if (qd == 0) return stand;
  if (white) {
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
  } else {
    if (stand <= alpha) return stand;
    if (stand < beta) beta = stand;
  }
  int best = stand;
  for (final m in all) {
    if (g.get(m.toAlgebraic as String) == null) continue;
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

final Stopwatch _sw = Stopwatch();
int _limitMs = 0;
bool _timeUp = false;

int _search(ch.Chess g, int depth, int alpha, int beta) {
  if (_limitMs > 0 && _sw.elapsedMilliseconds > _limitMs) {
    _timeUp = true;
    return 0;
  }
  if (depth == 0) return _quiesce(g, alpha, beta, 2);
  final ms = _sortedMoves(g);
  final white = g.turn == ch.Color.WHITE;
  if (ms.isEmpty) {
    if (g.in_check) return white ? -99999 - depth : 99999 + depth;
    return 0;
  }
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
  final blunder = (a['blunder'] as int?) ?? 0;
  final white = g.turn == ch.Color.WHITE;
  final ms = _sortedMoves(g, rnd: true);
  if (ms.isEmpty) return null;
  if (blunder > 0 && Random().nextInt(100) < blunder) {
    final m = ms[Random().nextInt(ms.length)];
    return {
      'from': m.fromAlgebraic as String,
      'to': m.toAlgebraic as String
    };
  }
  dynamic best;
  int alpha = -1000000;
  int beta = 1000000;
  int bestV = white ? -1000000 : 1000000;
  for (final m in ms) {
    g.move(m);
    final v = _search(g, depth - 1, alpha, beta);
    g.undo_move();
    if (best == null || (white ? v > bestV : v < bestV)) {
      bestV = v;
      best = m;
      if (white) {
        if (v > alpha) alpha = v;
      } else {
        if (v < beta) beta = v;
      }
    }
  }
  return {
    'from': best.fromAlgebraic as String,
    'to': best.toAlgebraic as String
  };
}

// Expert level: iterative deepening with a time limit.
Map<String, String>? _bestMoveTimed(Map<String, dynamic> a) {
  final g = ch.Chess.fromFEN(a['fen'] as String);
  var ms = _sortedMoves(g, rnd: true);
  if (ms.isEmpty) return null;
  final white = g.turn == ch.Color.WHITE;
  _limitMs = a['ms'] as int;
  _timeUp = false;
  _sw
    ..reset()
    ..start();
  dynamic best = ms.first;
  for (int d = 1; d <= 8; d++) {
    dynamic bestD;
    int alpha = -1000000;
    int beta = 1000000;
    int bestV = white ? -1000000 : 1000000;
    for (final m in ms) {
      g.move(m);
      final v = _search(g, d - 1, alpha, beta);
      g.undo_move();
      if (_timeUp) break;
      if (bestD == null || (white ? v > bestV : v < bestV)) {
        bestV = v;
        bestD = m;
        if (white) {
          if (v > alpha) alpha = v;
        } else {
          if (v < beta) beta = v;
        }
      }
    }
    if (_timeUp || bestD == null) break;
    best = bestD;
    final first = bestD;
    ms = [first, ...ms.where((m) => m != first)];
    if (bestV.abs() > 90000) break;
  }
  return {
    'from': best.fromAlgebraic as String,
    'to': best.toAlgebraic as String
  };
}

// Move review: alpha-beta at the root (fast); only the played move is
// searched exactly when it is clearly worse than the best move.
Map<String, dynamic>? _analyzeTask(Map<String, dynamic> a) {
  final g = ch.Chess.fromFEN(a['fen'] as String);
  final depth = a['depth'] as int;
  final pf = a['from'] as String;
  final pt = a['to'] as String;
  final pp = (a['promo'] as String?) ?? 'q';
  final white = g.turn == ch.Color.WHITE;
  final ms = _sortedMoves(g);
  if (ms.isEmpty) return null;
  dynamic playedMove;
  for (final m in ms) {
    final mp = m.promotion == null ? null : m.promotion.toString();
    if (m.fromAlgebraic == pf &&
        m.toAlgebraic == pt &&
        (mp == null || mp == pp)) {
      playedMove = m;
      break;
    }
  }
  if (playedMove == null) return null;
  final movedPiece = g.get(pf);
  final capturedPiece = g.get(pt);
  final movedVal =
      movedPiece == null ? 0 : _vals[movedPiece.type.toString()]!;
  final capVal =
      capturedPiece == null ? 0 : _vals[capturedPiece.type.toString()]!;
  const margin = 200;
  dynamic best;
  int bestV = white ? -1000000 : 1000000; // white point of view
  final exact = <int>[]; // mover point of view
  int? playedV;
  for (final m in ms) {
    int lo = -1000000;
    int hi = 1000000;
    if (best != null) {
      if (white) {
        lo = bestV - margin;
      } else {
        hi = bestV + margin;
      }
    }
    g.move(m);
    final v = _search(g, depth - 1, lo, hi);
    g.undo_move();
    final isExact = best == null || (white ? v > lo : v < hi);
    if (isExact) {
      exact.add(white ? v : -v);
      if (identical(m, playedMove)) playedV = v;
      if (best == null || (white ? v > bestV : v < bestV)) {
        best = m;
        bestV = v;
      }
    }
  }
  int pv;
  if (playedV != null) {
    pv = playedV;
  } else {
    g.move(playedMove);
    pv = _search(g, depth - 1, -1000000, 1000000);
    g.undo_move();
  }
  exact.sort((x, y) => y - x);
  final moverBest = white ? bestV : -bestV;
  final moverPlayed = white ? pv : -pv;
  final gap = exact.length > 1 ? exact[0] - exact[1] : 250;
  bool sac = false;
  if (movedVal >= 300 && capVal < movedVal - 50) {
    try {
      g.move(playedMove);
      sac = (g.moves({'asObjects': true}) as List)
          .any((x) => x.toAlgebraic == pt);
      g.undo_move();
    } catch (_) {}
  }
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
    'evalAfter': pv,
    'bestFrom': bf,
    'bestTo': bt,
    'bestSan': bestSan,
    'sac': sac,
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
  'brilliant': GI('!!', Color(0xFF1BACA6), 'نقلة عبقرية'),
  'great': GI('!', Color(0xFF5C8BB0), 'نقلة رائعة'),
  'best': GI('★', Color(0xFF96BC4B), 'أفضل نقلة'),
  'excellent': GI('✓', Color(0xFF96BC4B), 'نقلة ممتازة'),
  'good': GI('✓', Color(0xFF81B64C), 'نقلة جيدة'),
  'inaccuracy': GI('?!', Color(0xFFF7C631), 'عدم دقة'),
  'mistake': GI('?', Color(0xFFE58F2A), 'خطأ'),
  'blunder': GI('??', Color(0xFFCA3431), 'خطأ فادح'),
};

String _gradeOf(int loss, int gap, int n, {bool sac = false}) {
  if (loss <= 0) {
    if (sac && gap >= 150) return 'brilliant';
    return (gap >= 200 && n > 1) ? 'great' : 'best';
  }
  if (loss <= 25) return 'excellent';
  if (loss <= 70) return 'good';
  if (loss <= 150) return 'inaccuracy';
  if (loss <= 300) return 'mistake';
  return 'blunder';
}

const Map<String, String> kOpenings = {
  'e4': "King's Pawn Opening",
  'd4': "Queen's Pawn Opening",
  'c4': 'English Opening',
  'Nf3': 'Reti Opening',
  'e4 e5': 'Open Game',
  'e4 e5 Nf3 Nc6': 'Open Game: Main Line',
  'e4 e5 Nf3 Nc6 Bb5': 'Ruy Lopez',
  'e4 e5 Nf3 Nc6 Bb5 a6': 'Ruy Lopez: Morphy Defense',
  'e4 e5 Nf3 Nc6 Bc4': 'Italian Game',
  'e4 e5 Nf3 Nc6 Bc4 Bc5': 'Giuoco Piano',
  'e4 e5 Nf3 Nc6 d4': 'Scotch Game',
  'e4 e5 Nf3 Nf6': 'Petrov Defense',
  'e4 e5 Nf3 d6': 'Philidor Defense',
  'e4 e5 f4': "King's Gambit",
  'e4 e5 Nc3': 'Vienna Game',
  'e4 c5': 'Sicilian Defense',
  'e4 c5 Nf3 d6': 'Sicilian Defense: Open',
  'e4 c5 Nf3 e6': 'Sicilian Defense: Kan / Taimanov',
  'e4 c5 Nf3 Nc6': 'Sicilian Defense: Old Sicilian',
  'e4 e6': 'French Defense',
  'e4 e6 d4 d5': 'French Defense: Main Line',
  'e4 c6': 'Caro-Kann Defense',
  'e4 d5': 'Scandinavian Defense',
  'e4 d6': 'Pirc Defense',
  'e4 g6': 'Modern Defense',
  'e4 Nf6': "Alekhine's Defense",
  'd4 d5': "Queen's Pawn Game",
  'd4 d5 c4': "Queen's Gambit",
  'd4 d5 c4 e6': "Queen's Gambit Declined",
  'd4 d5 c4 dxc4': "Queen's Gambit Accepted",
  'd4 d5 c4 c6': 'Slav Defense',
  'd4 d5 Bf4': 'London System',
  'd4 Nf6': 'Indian Defense',
  'd4 Nf6 Bf4': 'London System',
  'd4 Nf6 c4 g6': "King's Indian Defense",
  'd4 Nf6 c4 e6 Nc3 Bb4': 'Nimzo-Indian Defense',
  'd4 f5': 'Dutch Defense',
  'c4 e5': 'English Opening: Reversed Sicilian',
};

String _opening(List<String> sans) {
  final clean = sans.map((x) => x.replaceAll(RegExp(r'[+#]'), '')).toList();
  String best = '';
  int bestLen = 0;
  kOpenings.forEach((key, name) {
    final t = key.split(' ');
    if (t.length > clean.length || t.length <= bestLen) return;
    for (int i = 0; i < t.length; i++) {
      if (t[i] != clean[i]) return;
    }
    best = name;
    bestLen = t.length;
  });
  return best;
}

// ───────────── game page ─────────────
class GamePage extends StatefulWidget {
  final bool vsAI;
  final int depth;
  final String level;
  final bool playerWhite;
  final OnlineGame? og;
  final int minutes;
  final int inc;
  final int botRating;
  final int blunder;
  const GamePage(
      {super.key,
      required this.vsAI,
      required this.depth,
      required this.level,
      required this.playerWhite,
      this.og,
      this.minutes = 10,
      this.inc = 0,
      this.botRating = 0,
      this.blunder = 0});
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
  late int whiteSecs, blackSecs;
  String? hintA, hintB;
  late List<String> fens;
  late bool playerWhite;
  List<String> ucis = [];
  String? dragFrom;
  Offset? dragAt;
  bool _dialogOpen = false;
  String ratingNote = '';
  List<List<String>> moveSq = [];
  int? viewIdx;
  String resultTag = '*';
  final ScrollController _sc = ScrollController();

  bool get online => widget.og != null;
  bool reconnecting = false;
  bool oppAway = false;
  bool get aiWhite => !playerWhite;
  ch.Color get aiColor => aiWhite ? ch.Color.WHITE : ch.Color.BLACK;

  @override
  void initState() {
    super.initState();
    playerWhite = widget.playerWhite;
    flipped = !playerWhite;
    whiteSecs = blackSecs = widget.minutes * 60;
    fens = [game.fen];
    _rebuild();
    _tick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.og != null) {
        Hub.want = true;
        Hub.setGameHandler(_onNet);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAI());
  }

  @override
  void dispose() {
    if (widget.og != null) {
      if (!resultShown && !game.game_over) Hub.send({'t': 'resign'});
      Hub.send({'t': 'leave'});
      Hub.clearGame();
    }
    _sc.dispose();
    super.dispose();
  }

  void _onNet(Map m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        _doMove(m['from'] as String, m['to'] as String, m['promo'] as String?,
            fromNet: true);
        _syncClocks(m);
        break;
      case 'clock':
        _syncClocks(m);
        if (reconnecting) setState(() => reconnecting = false);
        break;
      case 'draw_offer':
        _drawOfferDialog();
        break;
      case 'draw_declined':
        _toast('رفض الخصم التعادل');
        break;
      case 'rematch_offer':
        _toast('الخصم يعرض إعادة المباراة');
        break;
      case 'chat':
        final ci = (m['i'] as num?)?.toInt() ?? -1;
        if (ci >= 0 && ci < kChat.length) {
          _toast('${widget.og!.oppName}: ${kChat[ci]}');
        }
        break;
      case 'opp_disc':
        setState(() => oppAway = true);
        break;
      case 'opp_back':
        setState(() => oppAway = false);
        break;
      case 'resume':
        _applyResume(m);
        break;
      case 'no_game':
        setState(() => reconnecting = false);
        if (!resultShown) _end('انتهت المباراة أثناء انقطاع الاتصال');
        break;
      case 'start':
        final n = widget.og!;
        n.apply(m);
        if (_dialogOpen) Navigator.pop(context);
        setState(() {
          playerWhite = n.color == 'w';
          reconnecting = false;
          oppAway = false;
        });
        _reset(force: true);
        break;
      case 'end':
        _onlineEnd(m);
        break;
      case 'closed':
        if (!resultShown) setState(() => reconnecting = true);
        break;
    }
  }

  void _applyResume(Map m) {
    final og = widget.og!;
    og.apply(m);
    final uList = (m['moves'] as List?) ?? [];
    final g = ch.Chess();
    final f = <String>[g.fen];
    final sq = <List<String>>[];
    for (final u in uList) {
      final us = u.toString();
      if (us.length < 4) continue;
      final from = us.substring(0, 2);
      final to = us.substring(2, 4);
      final promo = us.length > 4 ? us.substring(4, 5) : null;
      if (!g.move({'from': from, 'to': to, 'promotion': promo ?? 'q'})) break;
      f.add(g.fen);
      sq.add([from, to]);
    }
    epoch++;
    setState(() {
      game = g;
      fens = f;
      moveSq = sq;
      reviews = [];
      ucis = [for (final u in uList) u.toString()];
      playerWhite = og.color == 'w';
      flipped = !playerWhite;
      lastFrom = sq.isEmpty ? null : sq.last[0];
      lastTo = sq.isEmpty ? null : sq.last[1];
      selected = null;
      targets = [];
      viewIdx = null;
      showBest = false;
      hintA = hintB = null;
      reconnecting = false;
      oppAway = false;
      resultShown = false;
      _rebuild();
    });
    _syncClocks(m);
  }

  Widget _banner() => Container(
        width: double.infinity,
        color: const Color(0xFFB45F06),
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text(
            reconnecting
                ? 'انقطع الاتصال... جاري إعادة الاتصال'
                : 'الخصم انقطع اتصاله... بانتظار عودته (30 ثانية)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  bool _hintAllowed() {
    if (Prefs.useDaily('hint', 5)) return true;
    if (Prefs.bonusHints > 0) {
      Prefs.bonusHints--;
      Prefs.save();
      return true;
    }
    return false;
  }

  void _upsell(String msg, {bool rewarded = false}) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: kPanel,
              title: const Text('ميزة للمشتركين'),
              content: Text(msg),
              actions: [
                if (rewarded && Platform.isAndroid && !Prefs.safeMode)
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        AdsX.showRewarded(() {
                          Prefs.bonusHints += 3;
                          Prefs.save();
                          Hub.toast('حصلت على 3 تلميحات إضافية');
                        });
                      },
                      child: const Text('شاهد إعلاناً (+3 تلميحات)')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('لاحقاً')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PlansPage()));
                    },
                    child: const Text('عرض الاشتراكات')),
              ],
            ));
  }

  void _chatSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: kPanel,
        builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (int i = 0; i < kChat.length; i++)
                    ActionChip(
                      label: Text(kChat[i]),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Hub.send({'t': 'chat', 'i': i});
                      },
                    ),
                ]),
              ),
            ));
  }

  void _toast(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t), duration: const Duration(seconds: 2)));
  }

  void _syncClocks(Map m) {
    final wt = m['wt'];
    final bt = m['bt'];
    if (wt is num && bt is num) {
      setState(() {
        whiteSecs = (wt / 1000).ceil();
        blackSecs = (bt / 1000).ceil();
      });
    }
  }

  Future<void> _drawOfferDialog() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: kPanel,
              title: const Text('عرض تعادل'),
              content: const Text('الخصم يعرض عليك التعادل. هل تقبل؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('رفض')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('قبول')),
              ],
            ));
    Hub.send({'t': ok == true ? 'draw_accept' : 'draw_decline'});
  }

  void _onlineEnd(Map m) {
    final result = (m['result'] ?? '*').toString();
    final reason = (m['reason'] ?? '').toString();
    final delta = (m['delta'] as num?)?.toInt() ?? 0;
    final rating = (m['rating'] as num?)?.toInt() ?? 0;
    final rated = m['rated'] == true;
    final net = widget.og!;
    if (rated) {
      net.myRating = rating;
      Prefs.setORating(net.cat, rating);
      Prefs.addRatingPoint('or', net.cat, rating);
    }
    const reasons = {
      'checkmate': 'كش مات',
      'resign': 'استسلام',
      'timeout': 'انتهى الوقت',
      'abandon': 'غادر الخصم',
      'agreement': 'تعادل بالاتفاق',
      'stalemate': 'جمود (ستالميت)',
      'draw': 'تعادل',
      'aborted': 'أُلغيت المباراة',
    };
    int? oc;
    String head;
    if (result == '*') {
      head = 'أُلغيت المباراة';
    } else if (result == '1/2-1/2') {
      oc = 0;
      head = 'تعادل';
    } else {
      final whiteWon = result == '1-0';
      final v = (whiteWon == playerWhite) ? 1 : -1;
      oc = v;
      head = v > 0 ? 'فزت' : 'خسرت';
    }
    final why = reasons[reason];
    final text = (why == null || result == '*') ? head : '$head - $why';
    final note = rated
        ? 'تقييمك (${kCatLabel[net.cat]}): $rating (${delta >= 0 ? '+' : ''}$delta)'
        : (result == '*' ? '' : 'مباراة غير مصنفة');
    _end(text, outcome: oc, tag: result, note: note);
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
      if (!online && (whiteSecs <= 0 || blackSecs <= 0)) {
        _end(
            whiteSecs <= 0
                ? 'انتهى الوقت - فاز الأسود'
                : 'انتهى الوقت - فاز الأبيض',
            outcome: _oc(whiteSecs > 0));
      }
    }
  }

  int _oc(bool whiteWins) => (whiteWins == playerWhite) ? 1 : -1;

  void _end(String m, {int? outcome, String? tag, String? note}) {
    if (resultShown || !mounted) return;
    resultShown = true;
    AdsX.gameFinished();
    if (tag != null) {
      resultTag = tag;
    } else if (m.contains('فاز الأبيض')) {
      resultTag = '1-0';
    } else if (m.contains('فاز الأسود')) {
      resultTag = '0-1';
    } else if (m.contains('تعادل')) {
      resultTag = '1/2-1/2';
    } else if (m.contains('فزت')) {
      resultTag = playerWhite ? '1-0' : '0-1';
    } else if (m.contains('فاز الخصم')) {
      resultTag = playerWhite ? '0-1' : '1-0';
    }
    if (outcome != null && (widget.vsAI || online)) {
      Prefs.bump(online ? 'on' : 'ai', outcome);
    }
    String n = note ?? '';
    if (n.isEmpty &&
        widget.vsAI &&
        outcome != null &&
        widget.botRating > 0 &&
        game.history.length >= 2) {
      final c = catOf(widget.minutes, widget.inc);
      final old = Prefs.rating(c);
      final score = outcome > 0 ? 1.0 : (outcome < 0 ? 0.0 : 0.5);
      final e = 1 / (1 + pow(10, (widget.botRating - old) / 400));
      final d = (32 * (score - e)).round();
      final nw = max(100, old + d);
      Prefs.setRating(c, nw);
      Prefs.addRatingPoint('lr', c, nw);
      n = 'تقييمك (${kCatLabel[c]}): $nw (${d >= 0 ? '+' : ''}$d)';
    }
    if (resultTag != '*' && game.history.length >= 2) {
      Prefs.addHistory({
        'd': DateTime.now().millisecondsSinceEpoch,
        'o': widget.vsAI
            ? widget.level
            : (online ? widget.og!.oppName : 'لاعب محلي'),
        'r': resultTag,
        'me': (widget.vsAI || online) ? (playerWhite ? 'w' : 'b') : '',
        'pgn': _pgn(),
        'uci': List<String>.from(ucis),
        'm': widget.vsAI ? 'ai' : (online ? 'on' : 'lo'),
      });
    }
    ratingNote = n;
    if (Prefs.sound) HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _dialogOpen = true;
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
                    if (ratingNote.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(ratingNote,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kGreen)),
                    ],
                    const SizedBox(height: 20),
                    _greenBtn('مراجعة اللعبة', () {
                      Navigator.pop(context);
                      _reviewSummary();
                    }),
                    const SizedBox(height: 10),
                    if (online)
                      _greenBtn('إعادة المباراة', () {
                        Hub.send({'t': 'rematch'});
                        Navigator.pop(context);
                        _toast('تم إرسال طلب إعادة المباراة');
                      })
                    else
                      _greenBtn('لعبة جديدة', () {
                        Navigator.pop(context);
                        _reset();
                      }),
                    const SizedBox(height: 6),
                    TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (online) Navigator.pop(context);
                        },
                        child: Text(online ? 'خروج' : 'عرض الرقعة')),
                  ]),
                ),
              )).then((_) => _dialogOpen = false);
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

  void _reset({bool force = false}) {
    if (online && !force) return;
    if (resultShown && !online) AdsX.maybeShowBetweenGames();
    epoch++;
    setState(() {
      game = ch.Chess();
      ucis = [];
      ratingNote = '';
      flipped = !playerWhite;
      selected = null;
      targets = [];
      lastFrom = lastTo = null;
      whiteSecs = blackSecs = widget.minutes * 60;
      thinking = false;
      resultShown = false;
      showBest = false;
      hintA = hintB = null;
      reviews = [];
      fens = [game.fen];
      moveSq = [];
      viewIdx = null;
      resultTag = '*';
      _rebuild();
    });
    _maybeAI();
  }

  void _checkEnd() {
    if (online) {
      String? res;
      String? why;
      if (game.in_checkmate) {
        res = game.turn == ch.Color.WHITE ? '0-1' : '1-0';
        why = 'checkmate';
      } else if (game.in_stalemate) {
        res = '1/2-1/2';
        why = 'stalemate';
      } else if (game.in_draw) {
        res = '1/2-1/2';
        why = 'draw';
      }
      if (res != null) Hub.send({'t': 'game_over', 'result': res, 'reason': why});
      return;
    }
    if (game.in_checkmate) {
      _end(
          game.turn == ch.Color.WHITE
              ? 'كش مات - فاز الأسود'
              : 'كش مات - فاز الأبيض',
          outcome: _oc(game.turn != ch.Color.WHITE));
    } else if (game.in_stalemate) {
      _end('تعادل بالجمود (ستالميت)', outcome: 0);
    } else if (game.in_threefold_repetition) {
      _end('تعادل بالتكرار', outcome: 0);
    } else if (game.in_draw) {
      _end('تعادل', outcome: 0);
    }
  }

  bool get _aiToMove => widget.vsAI && game.turn == aiColor;
  bool get _notMyTurnOnline =>
      online && (game.turn == ch.Color.WHITE) != playerWhite;

  void _sfx({bool capture = false, bool check = false}) {
    if (!Prefs.sound) return;
    SystemSound.play(SystemSoundType.click);
    if (check) {
      HapticFeedback.heavyImpact();
    } else if (capture) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _tap(String sq) {
    if (viewIdx != null ||
        thinking ||
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
      promo = Prefs.autoQueen
          ? 'q'
          : await _askPromo(p.color == ch.Color.WHITE);
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
    final capture = game.get(to) != null;
    final mpiece = game.get(from);
    final ok = game.move({'from': from, 'to': to, 'promotion': promo ?? 'q'});
    if (!ok) return;
    final isPromoMove = mpiece != null &&
        mpiece.type.toString() == 'p' &&
        (to[1] == '8' || to[1] == '1');
    ucis.add('$from$to${isPromoMove ? (promo ?? 'q') : ''}');
    if (!online) {
      if (moverWhite) {
        whiteSecs += widget.inc;
      } else {
        blackSecs += widget.inc;
      }
    }
    fens.add(game.fen);
    moveSq.add([from, to]);
    viewIdx = null;
    if (online && !fromNet) {
      Hub.send({'t': 'move', 'from': from, 'to': to, 'promo': promo});
    }
    String san = '$from$to';
    try {
      final l = game.san_moves();
      if (l.isNotEmpty) san = l.last.toString();
    } catch (_) {}
    final rev = Rev(san, moverWhite, to);
    reviews.add(rev);
    _sfx(capture: capture, check: game.in_check);
    setState(() {
      _applyMove(from, to, promo);
      lastFrom = from;
      lastTo = to;
      selected = null;
      targets = [];
      showBest = false;
      hintA = hintB = null;
    });
    _scrollMoves();
    _analyze(fenBefore, rev, from, to, promo);
    _checkEnd();
    _maybeAI();
  }

  Future<void> _analyze(
      String fen, Rev rev, String from, String to, String? promo) async {
    // two passes: a fast one (shows the grade quickly), then a deeper one
    for (final d in [2, 3]) {
      final r = await compute(_analyzeTask, {
        'fen': fen,
        'depth': d,
        'from': from,
        'to': to,
        'promo': promo
      });
      if (!mounted || r == null || !reviews.contains(rev)) return;
      final loss = r['loss'] as int;
      setState(() {
        rev.loss = loss < 0 ? 0 : loss;
        rev.evalAfter = r['evalAfter'] as int;
        rev.bestSan = r['bestSan'] as String;
        rev.bestFrom = r['bestFrom'] as String;
        rev.bestTo = r['bestTo'] as String;
        rev.grade = _gradeOf(rev.loss, r['gap'] as int, r['n'] as int,
            sac: r['sac'] as bool);
      });
      if (d == 3 &&
          (rev.grade == 'mistake' || rev.grade == 'blunder') &&
          rev.white == playerWhite &&
          (widget.vsAI || online) &&
          rev.bestFrom != null) {
        Prefs.addMistake({
          'fen': fen,
          'bf': rev.bestFrom,
          'bt': rev.bestTo,
          'san': rev.bestSan,
          'white': rev.white,
          'd': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  double _accuracy(bool white) {
    final l =
        reviews.where((r) => r.white == white && r.grade != null).toList();
    if (l.isEmpty) return -1;
    double sum = 0;
    for (final r in l) {
      sum += 100 * exp(-min(r.loss, 3000) / 300.0);
    }
    return sum / l.length;
  }

  void _reviewSummary() {
    if (Prefs.tier == 0 && !Prefs.useDaily('review', 1)) {
      _upsell('المجانيون يمكنهم عرض ملخص مراجعة واحد يومياً. الاشتراك يفتحه بلا حدود.');
      return;
    }
    const order = [
      'brilliant',
      'great',
      'best',
      'excellent',
      'good',
      'inaccuracy',
      'mistake',
      'blunder'
    ];
    int cnt(bool w, String g) =>
        reviews.where((r) => r.white == w && r.grade == g).length;
    String accText(bool w) {
      final a = _accuracy(w);
      return a < 0 ? '--' : '${a.toStringAsFixed(0)}%';
    }

    showDialog(
        context: context,
        builder: (_) => Dialog(
              backgroundColor: kPanel,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('ملخص المراجعة',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Expanded(child: SizedBox()),
                      SizedBox(
                          width: 64,
                          child: Column(children: [
                            const Text('الأبيض',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                            Text(accText(true),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                          ])),
                      SizedBox(
                          width: 64,
                          child: Column(children: [
                            const Text('الأسود',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white60)),
                            Text(accText(false),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                          ])),
                    ]),
                    const Divider(height: 22),
                    for (final g in order)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          _badge(kGrades[g]!, 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(kGrades[g]!.label,
                                  style: const TextStyle(fontSize: 14))),
                          SizedBox(
                              width: 64,
                              child: Text('${cnt(true, g)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 15))),
                          SizedBox(
                              width: 64,
                              child: Text('${cnt(false, g)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 15))),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق')),
                  ]),
                ),
              ),
            ));
  }

  void _popHist() {
    if (reviews.isNotEmpty) reviews.removeLast();
    if (fens.length > 1) fens.removeLast();
    if (moveSq.isNotEmpty) moveSq.removeLast();
    if (ucis.isNotEmpty) ucis.removeLast();
  }

  List<Pc> _pcsFromFen(String fen) {
    final g = ch.Chess.fromFEN(fen);
    final l = <Pc>[];
    int id = 100000;
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = g.get(_sq(r, f));
        if (p != null) {
          l.add(Pc(id++, p.type.toString(), p.color == ch.Color.WHITE,
              _sq(r, f)));
        }
      }
    }
    return l;
  }

  void _goView(int i) {
    setState(() {
      viewIdx = (i >= fens.length - 1) ? null : i;
      selected = null;
      targets = [];
      hintA = hintB = null;
    });
  }

  String _pgn() {
    final sans = _sans();
    final d = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    String white = 'White';
    String black = 'Black';
    if (widget.vsAI) {
      if (aiWhite) {
        white = 'Computer';
      } else {
        black = 'Computer';
      }
    }
    final b = StringBuffer();
    b.writeln('[Event "Casual Game"]');
    b.writeln('[Site "Chess App"]');
    b.writeln('[Date "${d.year}.${two(d.month)}.${two(d.day)}"]');
    b.writeln('[White "$white"]');
    b.writeln('[Black "$black"]');
    b.writeln('[Result "$resultTag"]');
    b.writeln();
    for (int i = 0; i < sans.length; i++) {
      if (i % 2 == 0) b.write('${i ~/ 2 + 1}. ');
      b.write('${sans[i]} ');
    }
    b.write(resultTag);
    return b.toString();
  }

  Future<void> _copy(String t, String msg) async {
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  Future<void> _offerDraw() async {
    if (game.game_over || resultShown) return;
    if (online) {
      Hub.send({'t': 'draw_offer'});
      _toast('تم إرسال عرض التعادل');
      return;
    }
    if (widget.vsAI) {
      final ev = reviews
          .lastWhere((r) => r.grade != null, orElse: () => Rev('', true, ''))
          .evalAfter;
      final aiScore = aiWhite ? ev : -ev;
      if (aiScore <= 80 && game.history.length >= 20) {
        _end('تعادل بالاتفاق', outcome: 0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('رفض الكمبيوتر التعادل'),
            duration: Duration(seconds: 1)));
      }
      return;
    }
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: kPanel,
              title: const Text('عرض تعادل'),
              content: const Text('هل يقبل الطرف الآخر التعادل؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('لا')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('نعم')),
              ],
            ));
    if (ok == true) _end('تعادل بالاتفاق', outcome: 0);
  }

  void _moreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (online)
                ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: const Text('دردشة سريعة'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _chatSheet();
                    }),
              ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('ملخص المراجعة'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reviewSummary();
                  }),
              ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('نسخ PGN'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copy(_pgn(), 'تم نسخ PGN');
                  }),
              ListTile(
                  leading: const Icon(Icons.grid_on),
                  title: const Text('نسخ FEN'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _copy(game.fen, 'تم نسخ FEN');
                  }),
              ListTile(
                    leading: const Icon(Icons.balance),
                    title: const Text('عرض تعادل'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _offerDraw();
                    }),
              SwitchListTile(
                  title: const Text('الصوت والاهتزاز'),
                  value: Prefs.sound,
                  onChanged: (v) {
                    setS(() => Prefs.sound = v);
                    Prefs.save();
                  }),
              SwitchListTile(
                  title: const Text('ترقية تلقائية إلى وزير'),
                  value: Prefs.autoQueen,
                  onChanged: (v) {
                    setS(() => Prefs.autoQueen = v);
                    Prefs.save();
                  }),
              SwitchListTile(
                  title: const Text('إظهار النقلات الممكنة'),
                  value: Prefs.showLegal,
                  onChanged: (v) {
                    setS(() => Prefs.showLegal = v);
                    setState(() {});
                    Prefs.save();
                  }),
              SwitchListTile(
                  title: const Text('إظهار الإحداثيات'),
                  value: Prefs.showCoords,
                  onChanged: (v) {
                    setS(() => Prefs.showCoords = v);
                    setState(() {});
                    Prefs.save();
                  }),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _hint() async {
    if (thinking || game.game_over || resultShown || _aiToMove) return;
    if (Prefs.tier == 0 && !_hintAllowed()) {
      _upsell('وصلت للحد اليومي للتلميحات (5). الاشتراك يفتح تلميحات غير محدودة.', rewarded: true);
      return;
    }
    final my = epoch;
    final r = await compute(_bestMoveTask, {'fen': game.fen, 'depth': 3});
    if (!mounted || my != epoch || r == null) return;
    setState(() {
      hintA = r['from'];
      hintB = r['to'];
      selected = null;
      targets = [];
    });
  }

  Future<void> _maybeAI() async {
    if (!widget.vsAI || game.game_over || game.turn != aiColor || thinking) {
      return;
    }
    final my = epoch;
    setState(() => thinking = true);
    await Future.delayed(const Duration(milliseconds: 450));
    Map<String, String>? r;
    if (widget.depth >= 98) {
      r = await compute(_bestMoveTimed,
          {'fen': game.fen, 'ms': widget.depth >= 99 ? 3000 : 6000});
    } else {
      r = await compute(_bestMoveTask, {
        'fen': game.fen,
        'depth': widget.depth,
        'blunder': widget.blunder
      });
    }
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
    _popHist();
    if (widget.vsAI && game.turn == aiColor && game.history.isNotEmpty) {
      game.undo_move();
      _popHist();
    }
    viewIdx = null;
    setState(() {
      selected = null;
      targets = [];
      lastFrom = lastTo = null;
      thinking = false;
      resultShown = false;
      showBest = false;
      hintA = hintB = null;
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
            if (reconnecting || oppAway) _banner(),
            const SizedBox(height: 6),
            _playerBar(!bottomWhite),
            const SizedBox(height: 6),
            LayoutBuilder(builder: (ctx, cons) {
              final bs = cons.maxWidth - 18;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: SizedBox(
                height: bs,
                child: Row(children: [
                  _evalBar(bs),
                  const SizedBox(width: 2),
                  SizedBox(width: bs, height: bs, child: _board()),
                ]),
              ));
            }),
            const SizedBox(height: 6),
            _playerBar(bottomWhite),
            Expanded(
              child: SingleChildScrollView(
                  child: Column(children: [_historyBar(), _reviewCard()])),
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

  Widget _historyBar() {
    final total = fens.length - 1;
    final cur = viewIdx ?? total;
    final op = _opening(_sans());
    Widget btn(IconData i, VoidCallback? f) => IconButton(
        onPressed: f,
        icon: Icon(i, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 36));
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
          color: kPanel, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
          child: Text(op.isEmpty ? 'الافتتاحية: --' : 'الافتتاحية: $op',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ),
        btn(Icons.first_page, cur > 0 ? () => _goView(0) : null),
        btn(Icons.chevron_left, cur > 0 ? () => _goView(cur - 1) : null),
        btn(Icons.chevron_right, cur < total ? () => _goView(cur + 1) : null),
        btn(Icons.last_page, cur < total ? () => _goView(total) : null),
      ]),
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
              onTap: () {
                if (!showBest &&
                    Prefs.tier == 0 &&
                    !_hintAllowed()) {
                  _upsell('وصلت للحد اليومي للتلميحات (5). الاشتراك يفتح تلميحات غير محدودة.', rewarded: true);
                  return;
                }
                setState(() => showBest = !showBest);
              },
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
    String ratingTxt = '';
    final isMe = (white == playerWhite);
    if (widget.vsAI) {
      if (isMe) {
        name = '${Prefs.name} ${kTierBadge[Prefs.tier]}'.trim();
        ratingTxt = '${Prefs.rating(catOf(widget.minutes, widget.inc))}';
      } else {
        name = widget.level;
        ratingTxt = widget.botRating > 0 ? '${widget.botRating}' : '';
      }
    } else if (online) {
      final nt = widget.og!;
      if (isMe) {
        name = '${Prefs.name} ${kTierBadge[Prefs.tier]}'.trim();
        ratingTxt = nt.myRating > 0 ? '${nt.myRating}' : '';
      } else {
        name = '${nt.oppName} ${kTierBadge[nt.oppTier.clamp(0, 3).toInt()]}'.trim();
        ratingTxt = nt.oppRating > 0 ? '${nt.oppRating}' : '';
      }
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
                    child: Text(ratingTxt.isEmpty ? name : '$name ($ratingTxt)',
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
        final inView = viewIdx != null;
        final shownPcs = inView ? _pcsFromFen(fens[viewIdx!]) : pcs;
        String? sqAt(Offset o) {
          if (o.dx < 0 || o.dy < 0 || o.dx >= S || o.dy >= S) return null;
          final dc = (o.dx / cell).floor().clamp(0, 7).toInt();
          final dr = (o.dy / cell).floor().clamp(0, 7).toInt();
          final f = flipped ? 7 - dc : dc;
          final r = flipped ? 7 - dr : dr;
          return _sq(r, f);
        }

        Pc? dragPcTmp;
        if (dragFrom != null) {
          for (final p in pcs) {
            if (p.sq == dragFrom) dragPcTmp = p;
          }
        }
        final dragPc = dragPcTmp;
        Offset pos(String sq) {
          final f = _files.indexOf(sq[0]);
          final r = 8 - int.parse(sq[1]);
          return Offset((flipped ? 7 - f : f) * cell,
              (flipped ? 7 - r : r) * cell);
        }

        final whiteTurn = game.turn == ch.Color.WHITE;
        String? kingSq;
        if (!inView && game.in_check) {
          for (final p in pcs) {
            if (p.type == 'k' && p.white == whiteTurn) kingSq = p.sq;
          }
        }
        final lastRev = reviews.isEmpty ? null : reviews.last;
        final bestA =
            hintA ?? ((showBest && lastRev != null) ? lastRev.bestFrom : null);
        final bestB =
            hintB ?? ((showBest && lastRev != null) ? lastRev.bestTo : null);
        final squares = <Widget>[];
        for (int dr = 0; dr < 8; dr++) {
          for (int dc = 0; dc < 8; dc++) {
            final f = flipped ? 7 - dc : dc;
            final r = flipped ? 7 - dr : dr;
            final sq = _sq(r, f);
            final dark = (r + f) % 2 == 1;
            final th = kThemes[gTheme];
            final fg = dark ? th[0] : th[1];
            final hl = inView
                ? (viewIdx! > 0 &&
                    (sq == moveSq[viewIdx! - 1][0] ||
                        sq == moveSq[viewIdx! - 1][1]))
                : (sq == lastFrom || sq == lastTo || sq == selected);
            squares.add(Positioned(
              left: dc * cell,
              top: dr * cell,
              width: cell,
              height: cell,
              child: GestureDetector(
                onTap: () => _tap(sq),
                child: Container(
                  color: dark ? kThemes[gTheme][1] : kThemes[gTheme][0],
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
                    if (Prefs.showCoords && dc == 0)
                      Positioned(
                          left: 2,
                          top: 1,
                          child: Text('${8 - r}',
                              style: TextStyle(
                                  fontSize: cell * 0.2,
                                  fontWeight: FontWeight.w800,
                                  color: fg))),
                    if (Prefs.showCoords && dr == 7)
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
        if (!inView && lastRev != null && lastRev.grade != null) {
          final g = kGrades[lastRev.grade!]!;
          final p = pos(lastRev.to);
          final bsz = cell * 0.42;
          badge = Positioned(
            left: min(p.dx + cell * 0.62, S - bsz),
            top: max(p.dy - cell * 0.06, 0),
            child: _badge(g, bsz),
          );
        }
        return GestureDetector(
          onPanStart: (d) {
            final sq = sqAt(d.localPosition);
            if (sq == null) return;
            _tap(sq);
            final p = game.get(sq);
            if (selected == sq &&
                p != null &&
                p.color == game.turn &&
                viewIdx == null) {
              setState(() {
                dragFrom = sq;
                dragAt = d.localPosition;
              });
            }
          },
          onPanUpdate: (d) {
            if (dragFrom != null) setState(() => dragAt = d.localPosition);
          },
          onPanEnd: (d) {
            final from = dragFrom;
            final at = dragAt;
            setState(() {
              dragFrom = null;
              dragAt = null;
            });
            if (from == null || at == null) return;
            final to = sqAt(at);
            if (to != null && to != from && targets.contains(to)) {
              _userMove(from, to);
            }
          },
          onPanCancel: () {
            if (dragFrom != null) {
              setState(() {
                dragFrom = null;
                dragAt = null;
              });
            }
          },
          child: SizedBox(
          width: S,
          height: S,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              ...squares,
              Positioned.fill(
                child: Stack(children: [
                  for (final pc in shownPcs)
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
                          child: Opacity(
                            opacity: pc.sq == dragFrom ? 0.25 : 1.0,
                            child: CustomPaint(
                                painter: PiecePainter(pc.type, pc.white)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(children: [
                    for (final t in (Prefs.showLegal ? targets : <String>[]))
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
                    if (dragPc != null && dragAt != null)
                      Positioned(
                        left: dragAt!.dx - cell * 0.75,
                        top: dragAt!.dy - cell * 1.1,
                        width: cell * 1.5,
                        height: cell * 1.5,
                        child: CustomPaint(
                            painter: PiecePainter(dragPc.type, dragPc.white)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ));
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
            _nav(Icons.palette_outlined, 'ثيم',
                () => setState(() {
                      int nx = gTheme;
                      for (int k = 0; k < kThemes.length; k++) {
                        nx = (nx + 1) % kThemes.length;
                        if (nx < 3 || Prefs.tier >= 1) break;
                      }
                      gTheme = nx;
                      Prefs.save();
                    })),
            if (!online) _nav(Icons.lightbulb_outline, 'تلميح', _hint),
            if (!online) _nav(Icons.undo, 'تراجع', _undo),
            _nav(Icons.flag_outlined, 'استسلام', () {
              if (game.game_over || resultShown) return;
              if (online) {
                Hub.send({'t': 'resign'});
                return;
              }
              final whiteResigns = widget.vsAI
                  ? playerWhite
                  : game.turn == ch.Color.WHITE;
              _end(whiteResigns
                  ? 'استسلم الأبيض - فاز الأسود'
                  : 'استسلم الأسود - فاز الأبيض',
                  outcome: widget.vsAI ? -1 : null);
            }),
            _nav(Icons.more_horiz, 'المزيد', _moreSheet),
          ],
        ),
      );

  Widget _nav(IconData i, String t, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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

// ───────────── settings & stats ─────────────
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Widget _stat(String title, String p) {
    final w = Prefs.stat('${p}_w');
    final l = Prefs.stat('${p}_l');
    final d = Prefs.stat('${p}_d');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kPanel, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('فوز $w  •  خسارة $l  •  تعادل $d',
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
        appBar: AppBar(
            backgroundColor: kPanel, title: const Text('الإحصائيات والإعدادات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (Prefs.safeMode)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF5A3A12),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                    'الوضع الآمن: تم تعطيل الإعلانات ومتجر الاشتراكات لأن التطبيق تعطل في المرة السابقة.',
                    style: TextStyle(fontSize: 13)),
                TextButton(
                    onPressed: () => setState(() {
                          Prefs.safeMode = false;
                          Prefs.save();
                        }),
                    child: const Text('إعادة تفعيلها (أعد فتح التطبيق بعدها)')),
              ]),
            ),
          if (Prefs.lastError.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFF5A2A2A),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(
                  child: Text('آخر خطأ في التطبيق:\n${Prefs.lastError}',
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: Prefs.lastError));
                    }),
                IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                          Prefs.lastError = '';
                          Prefs.save();
                        })),
              ]),
            ),
          _stat('ضد الكمبيوتر', 'ai'),
          _stat('أونلاين', 'on'),
          const RatingChartCard(),
          const AdsStatusCard(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('سياسة الخصوصية'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPage())),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: () => setState(Prefs.resetStats),
                child: const Text('تصفير الإحصائيات')),
          ),
          const SizedBox(height: 8),
          const Text('ألوان الرقعة', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(runSpacing: 10, children: [
            for (int i = 0; i < kThemes.length; i++)
              GestureDetector(
                onTap: () {
                  if (i >= 3 && Prefs.tier < 1) {
                    Hub.toast('هذا اللون للمشتركين');
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PlansPage()));
                    return;
                  }
                  setState(() {
                    gTheme = i;
                    Prefs.save();
                  });
                },
                child: Container(
                  width: 54,
                  height: 54,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: gTheme == i ? kGreen : Colors.transparent,
                        width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(children: [
                      Row(children: [
                        Expanded(child: Container(color: kThemes[i][0])),
                        Expanded(child: Container(color: kThemes[i][1])),
                      ]),
                      if (i >= 3 && Prefs.tier < 1)
                        const Center(
                            child: Icon(Icons.lock, size: 20, color: Colors.black54)),
                    ]),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
              title: const Text('الصوت والاهتزاز'),
              value: Prefs.sound,
              onChanged: (v) => setState(() {
                    Prefs.sound = v;
                    Prefs.save();
                  })),
          SwitchListTile(
              title: const Text('ترقية تلقائية إلى وزير'),
              value: Prefs.autoQueen,
              onChanged: (v) => setState(() {
                    Prefs.autoQueen = v;
                    Prefs.save();
                  })),
          SwitchListTile(
              title: const Text('إظهار النقلات الممكنة'),
              value: Prefs.showLegal,
              onChanged: (v) => setState(() {
                    Prefs.showLegal = v;
                    Prefs.save();
                  })),
          SwitchListTile(
              title: const Text('إظهار الإحداثيات'),
              value: Prefs.showCoords,
              onChanged: (v) => setState(() {
                    Prefs.showCoords = v;
                    Prefs.save();
                  })),
        ]),
      );
}

// ═════════════════════ NEW: review, learn from mistakes, charts, achievements ═════════════════════
Widget gradeBadge(GI g, double size) => Container(
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

// A board that only shows a position (no animation). Used by review and puzzles.
class StaticBoard extends StatelessWidget {
  final String fen;
  final bool flipped;
  final Set<String> hl;
  final Set<String> blue;
  final String? selected;
  final Set<String> targets;
  final void Function(String sq)? onTap;
  const StaticBoard({
    super.key,
    required this.fen,
    this.flipped = false,
    this.hl = const <String>{},
    this.blue = const <String>{},
    this.selected,
    this.targets = const <String>{},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    ch.Chess g;
    try {
      g = ch.Chess.fromFEN(fen);
    } catch (_) {
      g = ch.Chess();
    }
    final th = kThemes[gTheme];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (ctx, cons) {
          final cell = cons.maxWidth / 8;
          final kids = <Widget>[];
          for (int dr = 0; dr < 8; dr++) {
            for (int dc = 0; dc < 8; dc++) {
              final f = flipped ? 7 - dc : dc;
              final r = flipped ? 7 - dr : dr;
              final sq = '${_files[f]}${8 - r}';
              final dark = (r + f) % 2 == 1;
              final p = g.get(sq);
              final fg = dark ? th[0] : th[1];
              kids.add(Positioned(
                left: dc * cell,
                top: dr * cell,
                width: cell,
                height: cell,
                child: GestureDetector(
                  onTap: onTap == null ? null : () => onTap!(sq),
                  child: Stack(children: [
                    Container(color: dark ? th[1] : th[0]),
                    if (hl.contains(sq) || sq == selected)
                      Container(color: const Color(0x80F6F669)),
                    if (blue.contains(sq))
                      Container(color: const Color(0x884A90E2)),
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
                    if (p != null)
                      Padding(
                        padding: EdgeInsets.all(cell * 0.03),
                        child: CustomPaint(
                            size: Size.infinite,
                            painter: PiecePainter(
                                p.type.toString(), p.color == ch.Color.WHITE)),
                      ),
                    if (targets.contains(sq))
                      Center(
                        child: Container(
                          width: cell * 0.3,
                          height: cell * 0.3,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Color(0x40000000)),
                        ),
                      ),
                  ]),
                ),
              ));
            }
          }
          return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: kids));
        }),
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final List<double> ys;
  final double minY;
  final double maxY;
  final int? marker;
  final Color color;
  final bool zeroLine;
  LinePainter(this.ys,
      {required this.minY,
      required this.maxY,
      this.marker,
      this.color = kGreen,
      this.zeroLine = false});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
        Paint()..color = const Color(0xFF262421));
    if (ys.length < 2) return;
    double yOf(double v) {
      final t = ((v - minY) / (maxY - minY)).clamp(0.0, 1.0).toDouble();
      return size.height - 6 - t * (size.height - 12);
    }

    double xOf(int i) => 6 + i * (size.width - 12) / (ys.length - 1);
    if (zeroLine) {
      canvas.drawLine(
          Offset(0, yOf(0)),
          Offset(size.width, yOf(0)),
          Paint()
            ..color = const Color(0x33FFFFFF)
            ..strokeWidth = 1);
    }
    final path = Path()..moveTo(xOf(0), yOf(ys[0]));
    for (int i = 1; i < ys.length; i++) {
      path.lineTo(xOf(i), yOf(ys[i]));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
    final m = marker;
    if (m != null && m >= 0 && m < ys.length) {
      canvas.drawCircle(
          Offset(xOf(m), yOf(ys[m])), 4.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(LinePainter old) => true;
}

// ───────────── game review (analyse a finished game) ─────────────
class ReviewPage extends StatefulWidget {
  final Map<String, dynamic> rec;
  const ReviewPage({super.key, required this.rec});
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final List<String> fens = [];
  final List<List<String>> mv = [];
  final List<String> promos = [];
  final List<String> sans = [];
  final List<Rev?> revs = [];
  int idx = 0;
  int done = 0;
  bool flipped = false;
  bool showBest = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    flipped = (widget.rec['me'] ?? '') == 'b';
    Prefs.reviewsOpened++;
    Prefs.save();
    _replay();
    _analyzeAll();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _replay() {
    final g = ch.Chess();
    fens.add(g.fen);
    final list = (widget.rec['uci'] as List?) ?? [];
    for (final u in list) {
      final s = u.toString();
      if (s.length < 4) break;
      final from = s.substring(0, 2);
      final to = s.substring(2, 4);
      final promo = s.length > 4 ? s.substring(4, 5) : '';
      final ok = g.move(
          {'from': from, 'to': to, 'promotion': promo.isEmpty ? 'q' : promo});
      if (!ok) break;
      String san = s;
      try {
        final l = g.san_moves();
        if (l.isNotEmpty) san = l.last.toString();
      } catch (_) {}
      fens.add(g.fen);
      mv.add([from, to]);
      promos.add(promo);
      sans.add(san);
      revs.add(null);
    }
  }

  Future<void> _analyzeAll() async {
    for (int i = 0; i < mv.length; i++) {
      if (_disposed || !mounted) return;
      final r = await compute(_analyzeTask, {
        'fen': fens[i],
        'depth': 2,
        'from': mv[i][0],
        'to': mv[i][1],
        'promo': promos[i].isEmpty ? null : promos[i],
      });
      if (_disposed || !mounted) return;
      if (r != null) {
        final rev = Rev(sans[i], i % 2 == 0, mv[i][1]);
        final loss = r['loss'] as int;
        rev.loss = loss < 0 ? 0 : loss;
        rev.evalAfter = r['evalAfter'] as int;
        rev.bestSan = r['bestSan'] as String;
        rev.bestFrom = r['bestFrom'] as String;
        rev.bestTo = r['bestTo'] as String;
        rev.grade = _gradeOf(rev.loss, r['gap'] as int, r['n'] as int,
            sac: r['sac'] as bool);
        revs[i] = rev;
      }
      setState(() => done = i + 1);
    }
  }

  double _acc(bool white) {
    double sum = 0;
    int n = 0;
    for (int i = 0; i < revs.length; i++) {
      final r = revs[i];
      if (r == null || r.white != white) continue;
      sum += 100 * exp(-min(r.loss, 3000) / 300.0);
      n++;
    }
    return n == 0 ? -1 : sum / n;
  }

  String _accText(bool white) {
    final a = _acc(white);
    return a < 0 ? '--' : '${a.toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final n = mv.length;
    final Rev? rev = (idx > 0 && idx <= n) ? revs[idx - 1] : null;
    final hl = <String>{};
    if (idx > 0 && idx <= n) {
      hl.add(mv[idx - 1][0]);
      hl.add(mv[idx - 1][1]);
    }
    final blue = <String>{};
    if (showBest && rev != null && rev.bestFrom != null && rev.bestTo != null) {
      blue.add(rev.bestFrom!);
      blue.add(rev.bestTo!);
    }
    final ys = <double>[];
    double last = 0;
    for (int i = 0; i < n; i++) {
      final r = revs[i];
      if (r != null) last = r.evalAfter.toDouble().clamp(-800.0, 800.0).toDouble();
      ys.add(last);
    }
    final g = rev == null ? null : kGrades[rev.grade ?? ''];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPanel,
        title: const Text('مراجعة المباراة'),
        actions: [
          IconButton(
              icon: const Icon(Icons.swap_vert),
              onPressed: () => setState(() => flipped = !flipped)),
        ],
      ),
      body: n == 0
          ? const Center(child: Text('لا توجد نقلات لمراجعتها'))
          : Column(children: [
              if (done < n)
                LinearProgressIndicator(value: done / n, minHeight: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: CustomPaint(
                      painter: LinePainter(ys,
                          minY: -800,
                          maxY: 800,
                          marker: idx > 0 ? idx - 1 : null,
                          zeroLine: true)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: StaticBoard(
                    fen: fens[idx], flipped: flipped, hl: hl, blue: blue),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.first_page),
                        onPressed: idx > 0 ? () => setState(() => idx = 0) : null),
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: idx > 0 ? () => setState(() => idx--) : null),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            idx < n ? () => setState(() => idx++) : null),
                    IconButton(
                        icon: const Icon(Icons.last_page),
                        onPressed: idx < n ? () => setState(() => idx = n) : null),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: kPanel, borderRadius: BorderRadius.circular(8)),
                      child: idx == 0
                          ? const Text('اضغط ▶ لتبدأ مراجعة النقلات',
                              style: TextStyle(color: Colors.white54))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  if (g != null)
                                    gradeBadge(g, 26)
                                  else
                                    const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                        g == null
                                            ? '${sans[idx - 1]} - جاري التحليل...'
                                            : '${sans[idx - 1]} - ${g.label}',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: g?.color ?? Colors.white70)),
                                  ),
                                ]),
                                if (rev != null &&
                                    (rev.grade == 'inaccuracy' ||
                                        rev.grade == 'mistake' ||
                                        rev.grade == 'blunder') &&
                                    rev.bestSan.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => showBest = !showBest),
                                      child: Row(children: [
                                        const Icon(Icons.lightbulb_outline,
                                            size: 18, color: Colors.white60),
                                        const SizedBox(width: 6),
                                        Text('الأفضل كان: ${rev.bestSan}'),
                                        const SizedBox(width: 8),
                                        Text(
                                            showBest
                                                ? '(إخفاء)'
                                                : '(إظهار على الرقعة)',
                                            style: const TextStyle(
                                                fontSize: 12, color: kGreen)),
                                      ]),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _accBox('الأبيض', _accText(true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _accBox('الأسود', _accText(false))),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (int i = 0; i < n; i++)
                        GestureDetector(
                          onTap: () => setState(() => idx = i + 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: idx == i + 1 ? kGreenDark : kPanel,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(
                                '${i % 2 == 0 ? '${i ~/ 2 + 1}. ' : ''}${sans[i]}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _chipColor(revs[i]))),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
            ]),
    );
  }

  Color _chipColor(Rev? r) {
    final g = r?.grade;
    if (g == 'inaccuracy' || g == 'mistake' || g == 'blunder') {
      return kGrades[g!]!.color;
    }
    if (g == 'brilliant' || g == 'great') return kGrades[g!]!.color;
    return Colors.white;
  }

  Widget _accBox(String who, String acc) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: kPanel, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(who, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          Text(acc,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const Text('الدقة',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      );
}

// ───────────── learn from your mistakes ─────────────
class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});
  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  @override
  Widget build(BuildContext context) {
    final list = Prefs.mistakes();
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar: AppBar(
          backgroundColor: kPanel, title: const Text('تعلّم من أخطائك')),
      body: list.isEmpty
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'لا توجد أخطاء محفوظة بعد.\nالعب مباراة، وأي خطأ كبير ترتكبه سيظهر هنا لتتدرب على النقلة الصحيحة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54)),
            ))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final m = list[i];
                final white = m['white'] == true;
                final d = DateTime.fromMillisecondsSinceEpoch(
                    (m['d'] as num?)?.toInt() ?? 0);
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PuzzlePage(m: m)));
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: kPanel, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      SizedBox(
                          width: 34,
                          height: 34,
                          child: CustomPaint(
                              painter: PiecePainter('k', white))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(white ? 'دورك بالأبيض' : 'دورك بالأسود',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              Text('${d.year}/${d.month}/${d.day}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white54)),
                            ]),
                      ),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class PuzzlePage extends StatefulWidget {
  final Map<String, dynamic> m;
  const PuzzlePage({super.key, required this.m});
  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  late ch.Chess g;
  String? sel;
  Set<String> targets = {};
  String msg = '';
  bool solved = false;
  bool showSol = false;

  String get fen => widget.m['fen'].toString();
  String get bf => widget.m['bf'].toString();
  String get bt => widget.m['bt'].toString();

  @override
  void initState() {
    super.initState();
    g = ch.Chess.fromFEN(fen);
  }

  void _tap(String sq) {
    if (solved) return;
    if (sel != null && targets.contains(sq)) {
      if (sel == bf && sq == bt) {
        setState(() {
          solved = true;
          msg = 'أحسنت! هذه أفضل نقلة: ${widget.m['san'] ?? ''}';
        });
        Prefs.puzzlesSolved++;
        Prefs.removeMistake(fen);
        Prefs.save();
      } else {
        setState(() {
          msg = 'ليست الأفضل. حاول مرة أخرى';
          sel = null;
          targets = {};
        });
      }
      return;
    }
    final p = g.get(sq);
    if (p != null && p.color == g.turn) {
      final ms = g.moves({'asObjects': true}) as List;
      setState(() {
        sel = sq;
        targets = {
          for (final x in ms)
            if (x.fromAlgebraic == sq) x.toAlgebraic as String
        };
      });
    } else {
      setState(() {
        sel = null;
        targets = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final whiteToMove = g.turn == ch.Color.WHITE;
    return Scaffold(
      appBar: AppBar(backgroundColor: kPanel, title: const Text('أين النقلة الأفضل؟')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Text(
            whiteToMove
                ? 'دور الأبيض - جد أفضل نقلة'
                : 'دور الأسود - جد أفضل نقلة',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        StaticBoard(
          fen: fen,
          flipped: !whiteToMove,
          selected: sel,
          targets: targets,
          blue: (showSol || solved) ? {bf, bt} : <String>{},
          onTap: _tap,
        ),
        const SizedBox(height: 12),
        if (msg.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: solved ? kGreenDark : kPanel,
                borderRadius: BorderRadius.circular(8)),
            child: Text(msg, style: const TextStyle(fontSize: 15)),
          ),
        const SizedBox(height: 10),
        if (!solved)
          TextButton(
              onPressed: () => setState(() => showSol = !showSol),
              child: Text(showSol ? 'إخفاء الحل' : 'أظهر الحل')),
        if (solved)
          bigButton('رجوع', 'التمرين التالي', () => Navigator.pop(context)),
      ]),
    );
  }
}

// ───────────── rating chart (profile) ─────────────
class RatingChartCard extends StatefulWidget {
  const RatingChartCard({super.key});
  @override
  State<RatingChartCard> createState() => _RatingChartCardState();
}

class _RatingChartCardState extends State<RatingChartCard> {
  String cat = 'blitz';
  bool online = false;

  @override
  Widget build(BuildContext context) {
    final hist = Prefs.ratingHistory(online ? 'or' : 'lr', cat);
    final ys = hist.map((e) => e.toDouble()).toList();
    double lo = 700, hi = 900;
    if (ys.isNotEmpty) {
      lo = ys.reduce(min) - 30;
      hi = ys.reduce(max) + 30;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: kPanel, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('تطور تقييمك',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final c in ['bullet', 'blitz', 'rapid'])
            ChoiceChip(
              label: Text(kCatLabel[c]!),
              selected: cat == c,
              selectedColor: kGreen,
              onSelected: (_) => setState(() => cat = c),
            ),
          ChoiceChip(
            label: Text(online ? 'أونلاين' : 'ضد الكمبيوتر'),
            selected: true,
            selectedColor: kGreenDark,
            onSelected: (_) => setState(() => online = !online),
          ),
        ]),
        const SizedBox(height: 10),
        if (ys.length < 2)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
                child: Text('العب مباراتين على الأقل ليظهر الرسم',
                    style: TextStyle(color: Colors.white54, fontSize: 13))),
          )
        else ...[
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
                painter: LinePainter(ys,
                    minY: lo, maxY: hi, marker: ys.length - 1, color: kGreen)),
          ),
          const SizedBox(height: 6),
          Text('الآن: ${hist.last}   •   الأعلى: ${hist.reduce(max)}',
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ]),
    );
  }
}

// ───────────── achievements ─────────────
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    int wins = Prefs.stat('ai_w') + Prefs.stat('on_w');
    int games = wins +
        Prefs.stat('ai_l') +
        Prefs.stat('on_l') +
        Prefs.stat('ai_d') +
        Prefs.stat('on_d');
    int onlineGames =
        Prefs.stat('on_w') + Prefs.stat('on_l') + Prefs.stat('on_d');
    int bestRating = 0;
    for (final c in ['bullet', 'blitz', 'rapid']) {
      bestRating = max(bestRating, max(Prefs.rating(c), Prefs.oRating(c)));
    }
    final items = <List<dynamic>>[
      ['أول مباراة', 'أكمل مباراة واحدة', games >= 1, '$games/1'],
      ['أول فوز', 'اربح مباراة', wins >= 1, '$wins/1'],
      ['10 انتصارات', 'اربح 10 مباريات', wins >= 10, '$wins/10'],
      ['50 انتصاراً', 'اربح 50 مباراة', wins >= 50, '$wins/50'],
      ['لاعب أونلاين', 'العب مباراة ضد لاعب حقيقي', onlineGames >= 1, '$onlineGames/1'],
      ['تقييم 1000', 'اوصل لتقييم 1000', bestRating >= 1000, '$bestRating/1000'],
      ['تقييم 1200', 'اوصل لتقييم 1200', bestRating >= 1200, '$bestRating/1200'],
      ['مراجع محترف', 'راجع مباراة بالتحليل', Prefs.reviewsOpened >= 1, '${Prefs.reviewsOpened}/1'],
      ['طالب مجتهد', 'حل 5 تمارين من أخطائك', Prefs.puzzlesSolved >= 5, '${Prefs.puzzlesSolved}/5'],
      ['صديق', 'أضف صديقاً', Hub.friends.isNotEmpty, '${Hub.friends.length}/1'],
      ['مواظب', 'افتح اللعبة 3 أيام متتالية', Prefs.streak >= 3, '${Prefs.streak}/3'],
      ['أسبوع كامل', 'افتح اللعبة 7 أيام متتالية', Prefs.streak >= 7, '${Prefs.streak}/7'],
    ];
    final doneCount = items.where((e) => e[2] == true).length;
    return Scaffold(
      bottomNavigationBar: const SafeArea(child: AdBanner()),
      appBar: AppBar(backgroundColor: kPanel, title: const Text('الإنجازات')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: kPanel, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.local_fire_department, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
                child: Text('سلسلة الأيام: ${Prefs.streak}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
            Text('$doneCount/${items.length}',
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
          ]),
        ),
        for (final it in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: kPanel, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(it[2] == true ? Icons.emoji_events : Icons.lock_outline,
                  color: it[2] == true ? Colors.amber : Colors.white38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it[0].toString(),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: it[2] == true ? Colors.white : Colors.white60)),
                      Text(it[1].toString(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white38)),
                    ]),
              ),
              Text(it[3].toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ]),
          ),
      ]),
    );
  }
}

// ───────────── ads status (to check that ads are connected) ─────────────
class AdsStatusCard extends StatefulWidget {
  const AdsStatusCard({super.key});
  @override
  State<AdsStatusCard> createState() => _AdsStatusCardState();
}

class _AdsStatusCardState extends State<AdsStatusCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 80,
              child: Text(k,
                  style: const TextStyle(fontSize: 12, color: Colors.white54))),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    fontSize: 12,
                    color: v.contains('✓')
                        ? kGreen
                        : (v.contains('فشل') ? Colors.redAccent : Colors.white70))),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: kPanel, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('حالة الإعلانات',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (Prefs.safeMode)
          const Text('الوضع الآمن: الإعلانات معطلة',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent))
        else if (Prefs.tier > 0)
          const Text('لا تظهر الإعلانات لأن لديك اشتراكاً أو تجربة فعّالة',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        _row('الوضع', kTestAds ? 'إعلانات تجريبية ✓' : 'إعلانات حقيقية'),
        _row('وضع المكافأة', (kTestAds || kTestRewarded) ? 'تجريبية ✓' : 'حقيقية'),
        _row('التهيئة', AdsDiag.init),
        _row('البانر', AdsDiag.banner),
        _row('المكافأة', AdsDiag.rewarded),
        _row('البيني', AdsDiag.interstitial),
        const SizedBox(height: 6),
        const Text(
            'رموز الفشل: 3 = لا يوجد إعلان متاح الآن، 2 = مشكلة شبكة، 1 = معرّف الوحدة خاطئ، 0 = خطأ داخلي',
            style: TextStyle(fontSize: 11, color: Colors.white38)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ActionChip(
              label: const Text('إعادة التحميل'),
              onPressed: () {
                AdsX.preload();
                setState(() {});
              }),
          ActionChip(
              label: const Text('جرّب إعلان المكافأة'),
              onPressed: () => AdsX.showRewarded(
                  () => Hub.toast('✓ تم منح المكافأة بنجاح'))),
        ]),
      ]),
    );
  }
}

// ───────────── privacy policy (also required by Google Play and AdMob) ─────────────
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  static const String url = 'https://20091211mn.github.io/privacy.html';

  @override
  Widget build(BuildContext context) {
    const sections = <List<String>>[
      [
        'ما البيانات التي نجمعها؟',
        'الاسم الذي تختاره داخل اللعبة، ومعرّف مجهول يُنشأ تلقائياً (Firebase) بدون بريد أو رقم هاتف. بيانات اللعب الأونلاين: المباريات والنتائج والتقييم والأصدقاء. وإعدادات التطبيق المحفوظة على جهازك.'
      ],
      [
        'الإعلانات',
        'تعرض اللعبة إعلانات Google AdMob للمستخدمين المجانيين. قد تستخدم Google معرّف الإعلانات لعرض إعلانات مناسبة وقياس الأداء، ويمكنك إعادة ضبطه أو إيقاف التخصيص من إعدادات جهازك. نعرض نموذج موافقة حيث يلزم.'
      ],
      [
        'المشتريات',
        'الاشتراكات تتم عبر Google Play. لا نرى بيانات بطاقتك.'
      ],
      [
        'مشاركة البيانات',
        'لا نبيع بياناتك. تُعالَج عبر خدمات Google (Firebase وAdMob وGoogle Play) وفق سياساتها.'
      ],
      [
        'الأطفال',
        'اللعبة غير موجّهة للأطفال دون 13 عاماً.'
      ],
      [
        'حذف بياناتك',
        'راسلنا باسمك في اللعبة وكود الصداقة لحذف بيانات حسابك.'
      ],
    ];
    return Scaffold(
      appBar: AppBar(backgroundColor: kPanel, title: const Text('سياسة الخصوصية')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final sec in sections) ...[
          Text(sec[0],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(sec[1],
              style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.white70)),
          const SizedBox(height: 16),
        ],
        const Text('النص الكامل على الإنترنت:',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 4),
        SelectableText(url, style: const TextStyle(fontSize: 13, color: kGreen)),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: url));
              Hub.toast('تم نسخ الرابط');
            },
            child: const Text('نسخ الرابط')),
      ]),
    );
  }
}
