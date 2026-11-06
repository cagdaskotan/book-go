import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plus kilitleri etkin mi? İlk çıkışta KAPALI: herkes her şeye erişir,
/// ödeme/paywall gösterilmez. İleride `true` yapınca kilitler + paywall döner.
/// Tüm Plus altyapısı (PlusManager, PlusScreen) kodda hazır bekler.
const bool kPlusEnabled = false;

/// Kullanıcının Plus içeriklerine erişimi var mı?
/// Kilitler kapalıyken herkes erişir; açıkken yalnızca Plus üyeleri.
bool get hasPlusAccess => !kPlusEnabled || plusManager.isPlus;

/// Plus (premium) üyelik durumu.
///
/// Şimdilik cihazda saklanan basit bir bayrak. Mağaza entegrasyonunda
/// (RevenueCat vb.) [setPlus] gerçek satın alma durumundan beslenecek.
class PlusManager extends ChangeNotifier {
  static const _key = 'is_plus';

  bool _isPlus = false;
  bool get isPlus => _isPlus;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPlus = prefs.getBool(_key) ?? false;
    } catch (_) {}
  }

  Future<void> setPlus(bool value) async {
    if (_isPlus == value) return;
    _isPlus = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }
}

/// Global tekil (Provider/Riverpod yoksa iş görür).
final plusManager = PlusManager();
