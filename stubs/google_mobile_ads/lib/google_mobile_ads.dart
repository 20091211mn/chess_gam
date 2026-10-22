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

class AdError {}

class FullScreenContentCallback<T> {
  final void Function(T ad)? onAdDismissedFullScreenContent;
  final void Function(T ad, AdError error)? onAdFailedToShowFullScreenContent;
  const FullScreenContentCallback({
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
  });
}

class InterstitialAdLoadCallback {
  final void Function(InterstitialAd ad) onAdLoaded;
  final void Function(LoadAdError error) onAdFailedToLoad;
  const InterstitialAdLoadCallback(
      {required this.onAdLoaded, required this.onAdFailedToLoad});
}

class InterstitialAd extends Ad {
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;
  static void load({
    required String adUnitId,
    required AdRequest request,
    required InterstitialAdLoadCallback adLoadCallback,
  }) {}
  void show() {}
}

class RewardItem {}

class RewardedAdLoadCallback {
  final void Function(RewardedAd ad) onAdLoaded;
  final void Function(LoadAdError error) onAdFailedToLoad;
  const RewardedAdLoadCallback(
      {required this.onAdLoaded, required this.onAdFailedToLoad});
}

class RewardedAd extends Ad {
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;
  static void load({
    required String adUnitId,
    required AdRequest request,
    required RewardedAdLoadCallback rewardedAdLoadCallback,
  }) {}
  void show({required void Function(Ad ad, RewardItem reward) onUserEarnedReward}) {}
}

class FormError {}

class ConsentRequestParameters {}

class ConsentInformation {
  static final ConsentInformation instance = ConsentInformation._();
  ConsentInformation._();
  void requestConsentInfoUpdate(dynamic p, dynamic ok, dynamic fail) {}
  Future<bool> isConsentFormAvailable() async => false;
}

class ConsentForm {
  static void loadAndShowConsentFormIfRequired(dynamic cb) {}
}
