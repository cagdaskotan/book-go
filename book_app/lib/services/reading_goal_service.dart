import '../data/settings_store.dart';
import '../models/book.dart';

/// Yıllık okuma hedefi (kitap adedi) ve bu yıl bitirilen kitap sayımı.
///
/// Hedef veritabanında durur — böylece yedeğe dahil olur ve yeni telefonda
/// geri yüklendiğinde korunur. İlerleme kitap listesinden türetilir.
class ReadingGoalService {
  ReadingGoalService._();

  static const int defaultGoal = 12;

  static Future<int> getYearlyGoal() async {
    try {
      return await SettingsStore.getInt(
        SettingsStore.yearlyBookGoal,
        defaultGoal,
      );
    } catch (_) {
      return defaultGoal;
    }
  }

  static Future<void> setYearlyGoal(int goal) async {
    try {
      await SettingsStore.setInt(
        SettingsStore.yearlyBookGoal,
        goal.clamp(1, 999),
      );
    } catch (_) {
      // yazılamazsa sessizce geç; sonraki denemede tekrar yazılır
    }
  }

  /// Verilen yıl içinde bitirilmiş kitap sayısı (varsayılan: bu yıl).
  static int finishedInYear(List<Book> books, {int? year}) {
    final y = year ?? DateTime.now().year;
    return books.where((b) => _finishedInYear(b, y)).length;
  }

  static bool _finishedInYear(Book b, int year) {
    if (!b.isFinished) return false;
    final f = (b.finishedAt ?? '').trim();
    if (f.isNotEmpty) {
      final parsedYear = int.tryParse(f.split('-').first);
      if (parsedYear != null) return parsedYear == year;
    }
    // Bitiş tarihi yoksa eklenme yılına düş.
    return b.createdAt.year == year;
  }

  /// Yılın bu gününe göre beklenen kitap sayısı (tempo çizgisi).
  static double expectedByNow(int goal, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final dayOfYear = n.difference(DateTime(n.year)).inDays + 1;
    final daysInYear = DateTime(n.year + 1).difference(DateTime(n.year)).inDays;
    return goal * (dayOfYear / daysInYear);
  }
}
