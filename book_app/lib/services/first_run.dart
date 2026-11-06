import 'package:shared_preferences/shared_preferences.dart';

/// İlk açılış durumu.
///
/// Cihaza özgü bir bayrak: yedekle taşınmaz, çünkü "bu telefonda karşılama
/// ekranını gördüm" bilgisi kullanıcı verisi değil. Yeni telefonda karşılama
/// tekrar görünür ve kullanıcı orada yedeğini geri yükleyebilir.
class FirstRun {
  FirstRun._();

  static const String _key = 'onboarding_seen_v1';

  /// Karşılama akışı daha önce tamamlandı mı?
  static Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      // Okunamazsa karşılamayı atla; kullanıcıyı kapıda bırakmaktan iyidir.
      return true;
    }
  }

  static Future<void> markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // yazılamazsa bir sonraki açılışta tekrar sorar; veri kaybı yok
    }
  }
}
