import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Real AdMob ad unit IDs for this app (from the AdMob console). Ad unit
/// IDs aren't sensitive the way the AdMob App ID or an API key would be —
/// they're routinely committed in app source — so these are hardcoded
/// rather than pulled from a secret/env var.
///
/// google_mobile_ads only supports Android/iOS; every entry point here
/// no-ops elsewhere (web, desktop) so the game stays testable in those
/// environments during development.
class AdmobService {
  static const _androidBannerId = 'ca-app-pub-9078637596840810/7967136806';
  static const _androidInterstitialId = 'ca-app-pub-9078637596840810/1045515558';

  // No iOS AdMob app/ad units created for this project yet — fall back to
  // Google's public iOS TEST ad unit IDs (different constants than
  // Android's) rather than silently reusing the Android ones, which don't
  // work cross-platform and would just fail to serve. Replace with real
  // iOS ad unit IDs once an iOS app entry exists in the AdMob console.
  static const _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static String get _bannerId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosBannerId : _androidBannerId;
  static String get _interstitialId =>
      defaultTargetPlatform == TargetPlatform.iOS ? _iosInterstitialId : _androidInterstitialId;

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_isSupported) return;
    await MobileAds.instance.initialize();
  }

  static BannerAd? createBanner({AdSize size = AdSize.banner, void Function()? onLoaded}) {
    if (!_isSupported) return null;
    final banner = BannerAd(
      adUnitId: _bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }

  static InterstitialAd? _interstitial;

  /// Starts loading an interstitial in the background so it's ready by the
  /// time [showInterstitial] is called (e.g. at the next round-end screen).
  static void preloadInterstitial() {
    if (!_isSupported) return;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready, then starts loading
  /// the next one. No-ops silently if none is ready — never blocks play.
  static void showInterstitial() {
    if (!_isSupported) return;
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadInterstitial();
      },
    );
    ad.show();
  }
}
