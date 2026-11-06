import 'package:book_app/services/gamification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunucudaki XP/seri hesabının cihaza taşınmış hali — saf fonksiyon olduğu
/// için veritabanı gerekmez.
void main() {
  final today = DateTime(2026, 11, 6); // Cuma

  DateTime day(int d) => DateTime(2026, 11, d);

  group('okuma serisi', () {
    test('kayıt yoksa seri sıfırdır', () {
      final streaks = calculateStreaks(const [], today);
      expect(streaks.current, 0);
      expect(streaks.longest, 0);
    });

    test('bugüne kadar kesintisiz günler güncel seriyi verir', () {
      final streaks = calculateStreaks([day(4), day(5), day(6)], today);
      expect(streaks.current, 3);
      expect(streaks.longest, 3);
    });

    test('dün biten seri hâlâ güncel sayılır', () {
      final streaks = calculateStreaks([day(4), day(5)], today);
      expect(streaks.current, 2);
    });

    test('iki gün önce kesilen seri güncel değildir', () {
      final streaks = calculateStreaks([day(1), day(2), day(3)], today);
      expect(streaks.current, 0);
      expect(streaks.longest, 3);
    });

    test('en uzun seri boşluklara rağmen bulunur', () {
      final streaks = calculateStreaks([
        day(1),
        day(2),
        day(3),
        day(4),
        day(6),
      ], today);
      expect(streaks.longest, 4);
      expect(streaks.current, 1);
    });

    test('ay sınırını geçen seri doğru sayılır', () {
      final streaks = calculateStreaks([
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
      ], DateTime(2026, 11, 1));
      expect(streaks.current, 2);
      expect(streaks.longest, 2);
    });
  });

  group('özet', () {
    test('XP sayfa, bitirilen kitap ve aktif günden oluşur', () {
      final summary = buildGamificationSummary(
        pagesByDate: {'2026-11-05': 40, '2026-11-06': 60},
        finishedBooks: 2,
        dailyPageGoal: 50,
        now: today,
      );

      // 100 sayfa + 2*100 kitap + 2*10 aktif gün = 320
      expect(summary.totalPages, 100);
      expect(summary.activeDays, 2);
      expect(summary.xp, 320);
      expect(summary.level, 1);
      expect(summary.levelProgress, 320);
    });

    test('her 500 XP bir seviye', () {
      final summary = buildGamificationSummary(
        pagesByDate: {'2026-11-06': 1200},
        finishedBooks: 0,
        dailyPageGoal: 20,
        now: today,
      );
      // 1200 + 10 = 1210 -> seviye 3, ilerleme 210
      expect(summary.xp, 1210);
      expect(summary.level, 3);
      expect(summary.levelProgress, 210);
    });

    test('bugünün sayfası ve hedef durumu doğru', () {
      final summary = buildGamificationSummary(
        pagesByDate: {'2026-11-06': 60},
        finishedBooks: 0,
        dailyPageGoal: 50,
        now: today,
      );
      expect(summary.todayPages, 60);
      expect(summary.dailyGoalMet, isTrue);
      expect(summary.remainingPages, 0);
    });

    test('hafta pazartesiden başlar ve 7 gün içerir', () {
      final summary = buildGamificationSummary(
        pagesByDate: {'2026-11-06': 10},
        finishedBooks: 0,
        dailyPageGoal: 20,
        now: today,
      );
      expect(summary.week, hasLength(7));
      expect(summary.week.first.date, '2026-11-02'); // Pazartesi
      expect(summary.week.last.date, '2026-11-08'); // Pazar
      expect(summary.week.where((d) => d.isToday).single.date, '2026-11-06');
    });

    test('hedef 1-500 aralığına sıkıştırılır', () {
      final summary = buildGamificationSummary(
        pagesByDate: const {},
        finishedBooks: 0,
        dailyPageGoal: 9000,
        now: today,
      );
      expect(summary.dailyPageGoal, 500);
    });
  });
}
