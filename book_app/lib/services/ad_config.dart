import 'dart:io' show Platform;

/// Reklam yapılandırması — AdMob birim kimlikleri ve davranış ayarları.
///
/// Yayına çıkarken:
///  1) [kUseTestAds] değerini `false` yap.
///  2) Aşağıdaki `_prod...` kimliklerini AdMob panelinden aldığın gerçek
///     kimliklerle değiştir (Android + iOS ayrı ayrı).
///  3) AndroidManifest.xml ve ios/Runner/Info.plist içindeki uygulama
///     kimliğini (APPLICATION_ID / GADApplicationIdentifier) de güncelle.
class AdConfig {
  AdConfig._();

  /// Test modunda Google'ın örnek reklamları gösterilir (hesap banlanmaz).
  /// Yayında `false` yapılmalı.
  static const bool kUseTestAds = true;

  // ---- Google resmi TEST kimlikleri ----
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2934735716';

  // ---- GERÇEK kimlikler (yayına çıkınca doldur) ----
  static const String _prodInterstitialAndroid = 'ca-app-pub-XXXXX/XXXXX';
  static const String _prodInterstitialIos = 'ca-app-pub-XXXXX/XXXXX';
  static const String _prodBannerAndroid = 'ca-app-pub-XXXXX/XXXXX';
  static const String _prodBannerIos = 'ca-app-pub-XXXXX/XXXXX';

  static bool get _android => Platform.isAndroid;

  static String get interstitialUnitId {
    if (kUseTestAds) {
      return _android ? _testInterstitialAndroid : _testInterstitialIos;
    }
    return _android ? _prodInterstitialAndroid : _prodInterstitialIos;
  }

  static String get bannerUnitId {
    if (kUseTestAds) {
      return _android ? _testBannerAndroid : _testBannerIos;
    }
    return _android ? _prodBannerAndroid : _prodBannerIos;
  }

  // ---- Denge (kullanıcıyı bezdirmeme) ayarları ----

  /// Bir geçiş reklamı gösterildikten sonra en az bu kadar süre geçmeden
  /// yeni reklam gösterilmez.
  static const Duration minInterval = Duration(minutes: 3);

  /// Uygulama açıldıktan sonra ilk bu süre boyunca hiç reklam gösterilmez
  /// (ilk izlenim bozulmasın).
  static const Duration coldStartGrace = Duration(seconds: 45);

  /// Reklam gösterilmeden önce gereken en az "ileri sayfa geçişi" sayısı.
  static const int pushesPerAd = 5;
}
