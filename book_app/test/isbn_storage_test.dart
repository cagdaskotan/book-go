import 'package:book_app/data/app_database.dart';
import 'package:book_app/services/backup_service.dart';
import 'package:book_app/services/book_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Barkod saklama: künye bulunamasa bile ISBN elimizde kalmalı, mükerrer
/// eklemeyi engellemeli ve yedeğe girmeli.
void main() {
  late Database db;
  late BookService books;

  setUp(() async {
    db = await openTestDatabase();
    books = BookService();
  });

  tearDown(() async => db.close());

  test('isbn kaydedilir ve geri okunur', () async {
    final id = await books.createBook(
      title: 'Kürk Mantolu Madonna',
      totalPages: 160,
      isbn: '9789754589351',
    );
    expect((await books.getBook(id)).isbn, '9789754589351');
  });

  test('isbn verilmezse null kalır', () async {
    final id = await books.createBook(title: 'Künyesiz', totalPages: 100);
    expect((await books.getBook(id)).isbn, isNull);
  });

  group('mükerrer kontrolü', () {
    test('aynı barkod bulunur', () async {
      await books.createBook(
        title: 'Tutunamayanlar',
        totalPages: 724,
        isbn: '9789754700107',
      );
      final found = await books.findByIsbn('9789754700107');
      expect(found, isNotNull);
      expect(found!.title, 'Tutunamayanlar');
    });

    test('tire ve boşluk barkodu bozmaz', () async {
      await books.createBook(
        title: 'Kitap',
        totalPages: 100,
        isbn: '9789754700107',
      );
      expect(await books.findByIsbn('978-975-470-010-7'), isNotNull);
      expect(await books.findByIsbn(' 9789754700107 '), isNotNull);
    });

    test('tireli kaydedilen barkod temiz sorguyla bulunur', () async {
      // Elle giriş tireli olabilir; okutulan barkod temizdir. İkisi
      // eşleşmezse mükerrer kontrolü işe yaramaz.
      await books.createBook(
        title: 'Elle girilmiş',
        totalPages: 100,
        isbn: '978-975-470-010-7',
      );
      expect(await books.findByIsbn('9789754700107'), isNotNull);
    });

    test('ISBN-10 sonundaki X büyük/küçük fark etmez', () async {
      await books.createBook(
        title: 'Eski baskı',
        totalPages: 100,
        isbn: '097522980x',
      );
      expect(await books.findByIsbn('097522980X'), isNotNull);
    });

    test('olmayan barkod null döner', () async {
      expect(await books.findByIsbn('9780000000000'), isNull);
    });

    test('boş barkod sorgulanmaz', () async {
      await books.createBook(title: 'Künyesiz', totalPages: 100);
      expect(await books.findByIsbn(''), isNull);
      expect(await books.findByIsbn('   '), isNull);
    });
  });

  test('isbn yedeğe girer ve geri yüklenir', () async {
    await books.createBook(
      title: 'Saatleri Ayarlama Enstitüsü',
      totalPages: 382,
      isbn: '9789753638029',
    );

    final manifest = await BackupService().buildManifest();
    final backedUp = (manifest['books'] as List).first as Map;
    expect(backedUp['isbn'], '9789753638029');
  });

  test('güncelleme barkodu korur', () async {
    final id = await books.createBook(
      title: 'Kitap',
      totalPages: 100,
      isbn: '9789754700107',
    );
    await books.updateBook(id, title: 'Yeni Ad');
    final book = await books.getBook(id);
    expect(book.title, 'Yeni Ad');
    expect(book.isbn, '9789754700107');
  });

  test('şema sürümü 2 ve isbn sütunu mevcut', () async {
    expect(AppDatabase.schemaVersion, 2);
    final columns = await db.rawQuery('PRAGMA table_info(books)');
    final names = columns.map((c) => c['name']).toList();
    expect(names, contains('isbn'));
  });

  group('yazar önerileri', () {
    test('kitaplıktaki yazarlar sıklığa göre gelir', () async {
      await books.createBook(
        title: 'Kürk Mantolu Madonna',
        totalPages: 160,
        author: 'Sabahattin Ali',
      );
      await books.createBook(
        title: 'İçimizdeki Şeytan',
        totalPages: 240,
        author: 'Sabahattin Ali',
      );
      await books.createBook(
        title: 'Tutunamayanlar',
        totalPages: 724,
        author: 'Oğuz Atay',
      );

      final authors = await books.knownAuthors();
      expect(authors.first, 'Sabahattin Ali'); // iki kitabı var
      expect(authors, contains('Oğuz Atay'));
      expect(authors, hasLength(2));
    });

    test('yazarsız kitaplar listeye girmez', () async {
      await books.createBook(title: 'Yazarsız', totalPages: 100);
      await books.createBook(
        title: 'Boşluklu',
        totalPages: 100,
        author: '   ',
      );
      expect(await books.knownAuthors(), isEmpty);
    });
  });
}
