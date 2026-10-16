import 'package:flutter/widgets.dart';

class MobileAds {
  static final MobileAds instance = MobileAds._();
  MobileAds._();
  Future<void> initialize() async {}
}

class AdSize {
  final int width;
  final int height;
  const AdSize({required this.width, required this.height});
  static const AdSize banner = AdSize(width: 320, height: 50);
}

class AdRequest {
  const AdRequest();
}

class LoadAdError {}

class Ad {
  void dispose() {}
}

class BannerAdListener {
  final void Function(Ad ad)? onAdLoaded;
  final void Function(Ad ad, LoadAdError error)? onAdFailedToLoad;
  const BannerAdListener({this.onAdLoaded, this.onAdFailedToLoad});
}

class BannerAd extends Ad {
  final String adUnitId;
  final AdSize size;
  final AdRequest request;
  final BannerAdListener listener;
  BannerAd({
    required this.adUnitId,
    required this.size,
    required this.request,
    required this.listener,
  });
  Future<void> load() async {}
}

class AdWidget extends StatelessWidget {
  final Ad ad;
  const AdWidget({super.key, required this.ad});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
