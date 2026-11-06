import '../data/app_database.dart';

/// Isı haritası verisi: cihazdaki günlük kayıtlardan gün-bazlı sayfa toplamı.
class StatsService {
  StatsService();

  /// Verilen yıl için `YYYY-MM-DD -> okunan sayfa` eşlemesi.
  Future<Map<String, int>> fetchDailyActivity({int? year}) async {
    final db = await AppDatabase.instance.db;
    final y = year ?? DateTime.now().year;
    final rows = await db.rawQuery(
      'SELECT log_date, SUM(pages_read) AS pages '
      'FROM reading_logs '
      'WHERE pages_read > 0 AND log_date >= ? AND log_date <= ? '
      'GROUP BY log_date ORDER BY log_date ASC',
      ['$y-01-01', '$y-12-31'],
    );

    final activity = <String, int>{};
    for (final row in rows) {
      final date = row['log_date'] as String?;
      final pages = (row['pages'] as num?)?.toInt() ?? 0;
      if (date != null && date.isNotEmpty) activity[date] = pages;
    }
    return activity;
  }
}
