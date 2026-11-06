import 'package:book_app/models/book.dart';
import 'package:book_app/services/api_exception.dart';
import 'package:book_app/services/book_service.dart';
import 'package:book_app/utils/dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Eskiden sunucuda duran "ilerlemeyi günlükten türet" kuralının cihazdaki
/// karşılığını doğrular.
void main() {
  late Database db;
  late BookService service;

  setUp(() async {
    db = await openTestDatabase();
    service = BookService();
  });

  tearDown(() async => db.close());

  Future<int> newBook({int totalPages = 100}) =>
      service.createBook(title: 'Tutunamayanlar', totalPages: totalPages);

  group('kitap oluşturma', () {
    test('başlık boşsa reddedilir', () {
      expect(
        () => service.createBook(title: '   ', totalPages: 10),
        throwsA(isA<ApiException>()),
      );
    });

    test('sayfa sayısı sıfırsa reddedilir', () {
      expect(
        () => service.createBook(title: 'Kitap', totalPages: 0),
        throwsA(isA<ApiException>()),
      );
    });

    test('puan yalnızca bitirilen kitaba verilebilir', () {
      expect(
        () => service.createBook(title: 'Kitap', totalPages: 10, rating: 90),
        throwsA(isA<ApiException>()),
      );
    });

    test('bitmiş işaretlenirse sayfa toplama eşitlenir ve tarih bugün olur',
        () async {
      final id = await service.createBook(
        title: 'Kitap',
        totalPages: 120,
        isFinished: true,
        rating: 85,
      );
      final book = await service.getBook(id);
      expect(book.isFinished, isTrue);
      expect(book.currentPage, 120);
      expect(book.readingStatus, 'finished');
      expect(book.finishedAt, todayYmd());
      expect(book.rating, 85);
    });

    test('bitirme tarihi başlamadan önce olamaz', () {
      expect(
        () => service.createBook(
          title: 'Kitap',
          totalPages: 10,
          startedAt: '2026-05-10',
          finishedAt: '2026-05-01',
          isFinished: true,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('günlük kaydı ilerlemeyi sürer', () {
    test('sayfalar toplanır ve durum okunuyora geçer', () async {
      final id = await newBook();
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 30),
      );
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-02', pagesRead: 25),
      );

      final book = await service.getBook(id);
      expect(book.currentPage, 55);
      expect(book.isFinished, isFalse);
      expect(book.readingStatus, 'reading');
      expect(book.finishedAt, isNull);
    });

    test('toplam sayfaya ulaşınca kitap biter', () async {
      final id = await newBook(totalPages: 50);
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 50),
      );

      final book = await service.getBook(id);
      expect(book.isFinished, isTrue);
      expect(book.currentPage, 50);
      expect(book.readingStatus, 'finished');
      expect(book.finishedAt, todayYmd());
    });

    test('ilerleme toplam sayfada kırpılır', () async {
      final id = await newBook(totalPages: 50);
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 400),
      );
      expect((await service.getBook(id)).currentPage, 50);
    });

    test('"bitirdim" işaretli kayıt bitiş tarihini belirler', () async {
      final id = await newBook();
      await service.createLog(
        BookLog(
          id: 0,
          bookId: id,
          logDate: '2026-10-20',
          pagesRead: 10,
          finished: true,
        ),
      );

      final book = await service.getBook(id);
      expect(book.isFinished, isTrue);
      expect(book.finishedAt, '2026-10-20');
    });

    test('kayıt silinince ilerleme geri alınır', () async {
      final id = await newBook(totalPages: 40);
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 40),
      );
      expect((await service.getBook(id)).isFinished, isTrue);

      final logs = await service.fetchLogs(id);
      await service.deleteLog(logs.single.id);

      final book = await service.getBook(id);
      expect(book.isFinished, isFalse);
      expect(book.currentPage, 0);
      expect(book.finishedAt, isNull);
      expect(book.readingStatus, 'want_to_read');
    });

    test('duraklatılmış kitap yeni kayıtla okunuyora zorlanmaz', () async {
      final id = await newBook();
      await service.updateBook(id, readingStatus: 'paused');
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 10),
      );
      expect((await service.getBook(id)).readingStatus, 'paused');
    });

    test('boş kayıt reddedilir', () async {
      final id = await newBook();
      expect(
        () => service.createLog(
          BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 0),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('geçersiz tarih reddedilir', () async {
      final id = await newBook();
      expect(
        () => service.createLog(
          BookLog(id: 0, bookId: id, logDate: '2026-02-31', pagesRead: 5),
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('kitap güncelleme', () {
    test('bitmişlik geri alınınca puan ve bitiş tarihi temizlenir', () async {
      final id = await service.createBook(
        title: 'Kitap',
        totalPages: 80,
        isFinished: true,
        rating: 70,
      );
      await service.updateBook(id, isFinished: false, currentPage: 20);

      final book = await service.getBook(id);
      expect(book.isFinished, isFalse);
      expect(book.rating, isNull);
      expect(book.finishedAt, isNull);
      expect(book.readingStatus, 'reading');
    });

    test('okunan sayfa toplamı aşamaz', () async {
      final id = await newBook(totalPages: 30);
      expect(
        () => service.updateBook(id, currentPage: 31),
        throwsA(isA<ApiException>()),
      );
    });

    test('silinen kitabın günlüğü de gider', () async {
      final id = await newBook();
      await service.createLog(
        BookLog(id: 0, bookId: id, logDate: '2026-11-01', pagesRead: 10),
      );
      await service.deleteBook(id);

      final remaining = await db.query('reading_logs');
      expect(remaining, isEmpty);
    });
  });
}
