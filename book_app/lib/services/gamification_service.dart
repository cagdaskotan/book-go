import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../data/settings_store.dart';
import '../models/gamification_summary.dart';
import '../utils/dates.dart';
import 'api_exception.dart';

const int defaultDailyPageGoal = 20;

/// İlerleme özeti (XP, seviye, seri, haftalık tablo) — tamamı cihazdaki
/// okuma günlüğünden hesaplanır.
class GamificationService {
  GamificationService();

  Future<Database> get _db => AppDatabase.instance.db;

  Future<GamificationSummary> fetchSummary() async {
    final db = await _db;
    final goal = await SettingsStore.getInt(
      SettingsStore.dailyPageGoal,
      defaultDailyPageGoal,
    );

    final dayRows = await db.rawQuery(
      'SELECT log_date, SUM(pages_read) AS pages '
      'FROM reading_logs WHERE pages_read > 0 '
      'GROUP BY log_date ORDER BY log_date ASC',
    );
    final pagesByDate = <String, int>{};
    for (final row in dayRows) {
      final date = row['log_date'] as String?;
      final pages = (row['pages'] as num?)?.toInt() ?? 0;
      if (date != null && date.isNotEmpty) pagesByDate[date] = pages;
    }

    final finishedRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM books WHERE is_finished = 1',
    );
    final finishedBooks = (finishedRows.first['c'] as num?)?.toInt() ?? 0;

    return buildGamificationSummary(
      pagesByDate: pagesByDate,
      finishedBooks: finishedBooks,
      dailyPageGoal: goal,
      now: DateTime.now(),
    );
  }

  Future<GamificationSummary> updateDailyGoal(int pages) async {
    if (pages < 1 || pages > 500) {
      throw const ApiException(
        400,
        'Günlük sayfa hedefi 1 ile 500 arasında olmalı.',
      );
    }
    await SettingsStore.setInt(SettingsStore.dailyPageGoal, pages);
    return fetchSummary();
  }
}

/// Özeti saf veriden üretir — veritabanı gerektirmez, doğrudan test edilebilir.
GamificationSummary buildGamificationSummary({
  required Map<String, int> pagesByDate,
  required int finishedBooks,
  required int dailyPageGoal,
  required DateTime now,
}) {
  final goal = dailyPageGoal.clamp(1, 500);
  final today = DateTime(now.year, now.month, now.day);

  final dates =
      pagesByDate.keys
          .map(parseYmd)
          .whereType<DateTime>()
          .toList(growable: false)
        ..sort();

  var totalPages = 0;
  for (final pages in pagesByDate.values) {
    totalPages += pages;
  }

  final streaks = calculateStreaks(dates, today);
  final activeDays = dates.length;
  final xp = totalPages + finishedBooks * 100 + activeDays * 10;

  // Hafta pazartesi başlar.
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final week = <ReadingDay>[];
  for (var i = 0; i < 7; i++) {
    final day = weekStart.add(Duration(days: i));
    final key = ymd(day);
    final pages = pagesByDate[key] ?? 0;
    week.add(
      ReadingDay(
        date: key,
        pagesRead: pages,
        goalMet: pages >= goal,
        isToday: day == today,
      ),
    );
  }

  return GamificationSummary(
    dailyPageGoal: goal,
    todayPages: pagesByDate[ymd(today)] ?? 0,
    currentStreak: streaks.current,
    longestStreak: streaks.longest,
    totalPages: totalPages,
    finishedBooks: finishedBooks,
    activeDays: activeDays,
    xp: xp,
    level: xp ~/ 500 + 1,
    levelProgress: xp % 500,
    week: week,
  );
}

/// Okuma serisi: [current] bugün ya da dün biten kesintisiz gün sayısı,
/// [longest] tüm zamanların en uzun kesintisiz dizisi.
class ReadingStreaks {
  const ReadingStreaks({required this.current, required this.longest});
  final int current;
  final int longest;
}

/// [sortedDates] artan sıralı ve tekilleştirilmiş gün listesi olmalıdır.
ReadingStreaks calculateStreaks(List<DateTime> sortedDates, DateTime today) {
  if (sortedDates.isEmpty) {
    return const ReadingStreaks(current: 0, longest: 0);
  }

  var run = 1;
  var longest = 1;
  for (var i = 1; i < sortedDates.length; i++) {
    if (_isNextDay(sortedDates[i - 1], sortedDates[i])) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }

  var current = 0;
  final last = sortedDates.last;
  final yesterday = today.subtract(const Duration(days: 1));
  if (last == today || last == yesterday) {
    current = 1;
    for (var i = sortedDates.length - 1; i > 0; i--) {
      if (!_isNextDay(sortedDates[i - 1], sortedDates[i])) break;
      current++;
    }
  }

  return ReadingStreaks(current: current, longest: longest);
}

/// Yaz saati geçişlerinde saat farkı 24'ten sapabileceği için takvim günü
/// üzerinden karşılaştırır.
bool _isNextDay(DateTime earlier, DateTime later) {
  final next = DateTime(earlier.year, earlier.month, earlier.day + 1);
  return next.year == later.year &&
      next.month == later.month &&
      next.day == later.day;
}
