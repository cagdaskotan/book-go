import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'plus_manager.dart';

/// Geçiş (interstitial) reklamlarını yükleyip *dengeli* biçimde gösteren tekil.
///
/// Denge kuralları ([AdConfig]):
///  - Plus üyelere hiç reklam gösterilmez.
///  - Uygulama açılışından sonra bir süre (coldStartGrace) reklam yok.
///  - İki reklam arası en az `minInterval` bekler.
///  - En az `pushesPerAd` ileri-geçiş olmadan reklam çıkmaz.
///  - Bir reklam yüklü değilse sessizce atlanır (akış hiç kesilmez).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;
  bool _loading = false;
  bool _showing = false;
  InterstitialAd? _interstitial;

  DateTime? _startTime;
  DateTime? _lastAdTime;
  int _pushesSinceAd = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _startTime = DateTime.now();
    try {
      await MobileAds.instance.initialize();
      _loadInterstitial();
    } catch (e) {
      debugPrint('AdService init failed: $e');
    }
  }

  void _loadInterstitial() {
    if (_loading || _interstitial != null) return;
    // Plus üyeye reklam yüklemeye gerek yok.
    if (_plusBlocks) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _loading = false;
          debugPrint('Interstitial load failed: ${error.code} ${error.message}');
        },
      ),
    );
  }

  /// Navigasyon gözlemcisi her ileri geçişte bunu çağırır.
  void onForwardNavigation() {
    _pushesSinceAd++;
    maybeShowInterstitial();
  }

  bool get _plusBlocks => kPlusEnabled && plusManager.isPlus;

  bool _canShow() {
    if (_plusBlocks || _showing || _interstitial == null) return false;
    final now = DateTime.now();
    final start = _startTime;
    if (start != null && now.difference(start) < AdConfig.coldStartGrace) {
      return false;
    }
    final last = _lastAdTime;
    if (last != null && now.difference(last) < AdConfig.minInterval) {
      return false;
    }
    return _pushesSinceAd >= AdConfig.pushesPerAd;
  }

  /// Uygun koşullar sağlanıyorsa yüklü geçiş reklamını gösterir.
  void maybeShowInterstitial() {
    if (_plusBlocks) return;
    // Yüklü değilse arka planda bir sonrakini hazırla, sessizce çık.
    if (_interstitial == null) {
      _loadInterstitial();
      return;
    }
    if (!_canShow()) return;

    final ad = _interstitial!;
    _interstitial = null;
    _showing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _lastAdTime = DateTime.now();
        _pushesSinceAd = 0;
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        _loadInterstitial(); // bir sonrakini hazırla
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showing = false;
        _loadInterstitial();
      },
    );
    ad.show();
  }

  void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
  }
}
