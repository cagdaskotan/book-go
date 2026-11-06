import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Kullanıcıya ait ayarlar (günlük sayfa hedefi, yıllık kitap hedefi, profil
/// adı). Veritabanında durur, dolayısıyla yedeğe dahil olur.
///
/// Tema/reklam gibi yalnızca cihaza özgü durumlar SharedPreferences'ta kalır;
/// onlar yedeklenmez — başka bir telefonda anlamları yok.
class SettingsStore {
  SettingsStore._();

  static const String dailyPageGoal = 'daily_page_goal';
  static const String yearlyBookGoal = 'yearly_book_goal';
  static const String profileName = 'profile_name';

  static Future<String?> getString(String key) async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> setString(String key, String value) async {
    final db = await AppDatabase.instance.db;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> remove(String key) async {
    final db = await AppDatabase.instance.db;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  static Future<int> getInt(String key, int fallback) async {
    final raw = await getString(key);
    return raw == null ? fallback : (int.tryParse(raw) ?? fallback);
  }

  static Future<void> setInt(String key, int value) =>
      setString(key, '$value');

  /// Sunucu dönemindeki SharedPreferences değerlerini bir kez veritabanına
  /// taşır; mevcut telefonlarda hedefler sıfırlanmasın.
  static Future<void> migrateLegacyPrefs() async {
    const marker = 'legacy_prefs_imported';
    if (await getString(marker) != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final yearly = prefs.getInt('yearly_book_goal');
      if (yearly != null) await setInt(yearlyBookGoal, yearly);
    } catch (_) {
      // okunamazsa varsayılanlarla devam
    }
    await setString(marker, '1');
  }
}
