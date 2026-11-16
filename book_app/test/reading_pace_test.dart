import 'package:book_app/models/book.dart';
import 'package:book_app/services/reading_pace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 10);

  BookLog log(String date, {int pages = 0, int minutes = 0}) => BookLog(
    id: 0,
    bookId: 1,
    logDate: date,
    pagesRead: pages,
    durationMinutes: minutes,
  );

  Book book({
    int totalPages = 300,
    int currentPage = 0,
    bool finished = false,
  }) => Book(
    id: 1,
    title: 'Kitap',
    totalPages: totalPages,
    currentPage: currentPage,
    isFinished: finished,
    favorite: false,
    createdAt: DateTime(2026, 11, 1),
  );

  group('tempo hesabı', () {
    test('kayıt yoksa boş döner', () {
      final pace = computeReadingPace(const [], today: today);
      expect(pace.isEmpty, isTrue);
      expect(pace.pagesPerMinute, isNull);
      expect(pace.pagesPerDay, isNull);
    });

    test('hız yalnızca süresi tutulmuş kayıtlardan çıkar', () {
      final pace = computeReadingPace([
        log('2026-11-08', pages: 40, minutes: 20), // 2 sayfa/dk
        log('2026-11-09', pages: 100), // süresiz: hıza girmez
      ], today: today);

      expect(pace.totalPages, 140);
      expect(pace.timedPages, 40);
      expect(pace.totalMinutes, 20);
      expect(pace.pagesPerMinute, 2.0);
      expect(pace.timedSessionCount, 1);
      expect(pace.sessionCount, 2);
    });

    test('süre yoksa hız null, tempo yine hesaplanır', () {
      final pace = computeReadingPace([
        log('2026-11-09', pages: 50),
      ], today: today);
      expect(pace.hasTimingData, isFalse);
      expect(pace.pagesPerDay, isNotNull);
    });

    test('günlük tempo okumadığın günleri de sayar', () {
      // 8 Kasım'da 60 sayfa, bugün 10 Kasım -> 3 takvim günü -> 20 sayfa/gün
      final pace = computeReadingPace([
        log('2026-11-08', pages: 60),
      ], today: today);
      expect(pace.spanDays, 3);
      expect(pace.pagesPerDay, 20.0);
      expect(pace.activeDays, 1);
      expect(pace.pagesPerActiveDay, 60.0);
    });

    test('aynı güne birden fazla kayıt tek aktif gün sayılır', () {
      final pace = computeReadingPace([
        log('2026-11-09', pages: 10, minutes: 5),
        log('2026-11-09', pages: 20, minutes: 10),
      ], today: today);
      expect(pace.activeDays, 1);
      expect(pace.totalPages, 30);
      expect(pace.pagesPerMinute, 2.0);
    });

    test('ileri tarihli kayıt yayılımı bozmaz', () {
      final pace = computeReadingPace([
        log('2026-11-09', pages: 10),
        log('2026-11-20', pages: 10), // bugünden sonra
      ], today: today);
      expect(pace.spanDays, 12); // 9 Kasım -> 20 Kasım
      expect(pace.pagesPerDay, isNotNull);
    });
  });

  group('bitirme tahmini', () {
    test('bitmiş kitapta tahmin yok', () {
      final pace = computeReadingPace([
        log('2026-11-08', pages: 300, minutes: 100),
      ], today: today);
      final estimate = estimateFinish(
        book: book(currentPage: 300, finished: true),
        pace: pace,
        today: today,
      );
      expect(estimate, isNull);
    });

    test('sayfa sayısı bilinmiyorsa tahmin yok', () {
      final pace = computeReadingPace([
        log('2026-11-08', pages: 30, minutes: 15),
      ], today: today);
      expect(
        estimateFinish(book: book(totalPages: 0), pace: pace, today: today),
        isNull,
      );
    });

    test('kalan gün ve tarih günlük tempodan çıkar', () {
      // 8 Kasım'da 60 sayfa -> 3 gün yayılım -> 20 sayfa/gün
      // 300 sayfalık kitapta 60 okundu -> 240 kalan -> 12 gün
      final pace = computeReadingPace([
        log('2026-11-08', pages: 60),
      ], today: today);
      final estimate = estimateFinish(
        book: book(currentPage: 60),
        pace: pace,
        today: today,
      )!;

      expect(estimate.remainingPages, 240);
      expect(estimate.daysLeft, 12);
      expect(estimate.date, DateTime(2026, 11, 22));
    });

    test('kalan süre okuma hızından çıkar', () {
      // 2 sayfa/dk, 240 sayfa kalan -> 120 dakika
      final pace = computeReadingPace([
        log('2026-11-08', pages: 60, minutes: 30),
      ], today: today);
      final estimate = estimateFinish(
        book: book(currentPage: 60),
        pace: pace,
        today: today,
      )!;
      expect(estimate.minutesLeft, 120);
    });

    test('süre tutulmamışsa tarih var ama kalan süre yok', () {
      final pace = computeReadingPace([
        log('2026-11-08', pages: 60),
      ], today: today);
      final estimate = estimateFinish(
        book: book(currentPage: 60),
        pace: pace,
        today: today,
      )!;
      expect(estimate.date, isNotNull);
      expect(estimate.minutesLeft, isNull);
    });

    test('tempo saçma derecede yavaşsa tarih verilmez', () {
      // Bir yıl önce 1 sayfa -> günlük tempo ~0.003 -> binlerce gün
      final pace = computeReadingPace([
        log('2025-11-10', pages: 1),
      ], today: today);
      final estimate = estimateFinish(
        book: book(currentPage: 1),
        pace: pace,
        today: today,
      )!;
      expect(estimate.daysLeft, isNull);
      expect(estimate.date, isNull);
      expect(estimate.remainingPages, 299);
    });

    test('ilerleme toplamı yakaladıysa tahmin yok', () {
      final pace = computeReadingPace([
        log('2026-11-08', pages: 300),
      ], today: today);
      expect(
        estimateFinish(book: book(currentPage: 300), pace: pace, today: today),
        isNull,
      );
    });
  });

  group('biçimlendirme', () {
    test('süre metni', () {
      expect(formatMinutes(0), '1 dk\'dan az');
      expect(formatMinutes(45), '45 dk');
      expect(formatMinutes(60), '1 sa');
      expect(formatMinutes(135), '2 sa 15 dk');
      expect(formatMinutes(1440), '1 gün');
      expect(formatMinutes(1500), '1 gün 1 sa');
    });

    test('bitiş günü metni', () {
      expect(formatFinishDate(DateTime(2026, 11, 10), today: today), 'bugün');
      expect(formatFinishDate(DateTime(2026, 11, 11), today: today), 'yarın');
      expect(
        formatFinishDate(DateTime(2026, 11, 13), today: today),
        '3 gün içinde',
      );
      expect(
        formatFinishDate(DateTime(2026, 11, 22), today: today),
        '22 Kasım',
      );
      expect(
        formatFinishDate(DateTime(2027, 1, 5), today: today),
        '5 Ocak 2027',
      );
    });
  });

  group('tahmin tabanı', () {
    test('aktif gün tabanı okunan günleri esas alır, daha iyimser', () {
      // 8 Kasım'da 60 sayfa; bugün 10 Kasım.
      // Aktif gün: 1 gün -> 60 sayfa/gün -> 240 kalan -> 4 gün
      // Takvim günü: 3 gün -> 20 sayfa/gün -> 12 gün
      final pace = computeReadingPace([
        log('2026-11-08', pages: 60),
      ], today: today);

      final optimistic = estimateFinish(
        book: book(currentPage: 60),
        pace: pace,
        today: today,
        basis: PaceBasis.activeDays,
      )!;
      final realistic = estimateFinish(
        book: book(currentPage: 60),
        pace: pace,
        today: today,
        basis: PaceBasis.calendarDays,
      )!;

      expect(optimistic.daysLeft, 4);
      expect(realistic.daysLeft, 12);
      expect(optimistic.date!.isBefore(realistic.date!), isTrue);
    });
  });
}
