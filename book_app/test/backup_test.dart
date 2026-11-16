import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:book_app/models/book.dart';
import 'package:book_app/models/book_collection.dart';
import 'package:book_app/services/api_exception.dart';
import 'package:book_app/services/backup_service.dart';
import 'package:book_app/services/book_service.dart';
import 'package:book_app/services/collection_service.dart';
import 'package:book_app/services/quote_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

void main() {
  late Database db;
  late Directory tempDir;

  setUp(() async {
    db = await openTestDatabase();
    tempDir = await Directory.systemTemp.createTemp('kutuphanem-test');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  /// Yedek dosyası yazar: [asZip] true ise arşiv, değilse düz JSON.
  Future<File> writeBackup(
    Map<String, Object?> manifest, {
    bool asZip = false,
  }) async {
    final json = jsonEncode(manifest);
    if (!asZip) {
      final file = File('${tempDir.path}/backup.json');
      return file.writeAsString(json);
    }
    final archive = Archive()..add(ArchiveFile.string('backup.json', json));
    final file = File('${tempDir.path}/backup.zip');
    return file.writeAsBytes(ZipEncoder().encodeBytes(archive));
  }

  /// Örnek bir kitaplık kurar.
  Future<void> seedLibrary() async {
    final books = BookService();
    final id = await books.createBook(
      title: 'Kürk Mantolu Madonna',
      totalPages: 160,
      author: 'Sabahattin Ali',
      category: 'Roman',
    );
    await books.createLog(
      BookLog(
        id: 0,
        bookId: id,
        logDate: '2026-11-01',
        pagesRead: 40,
        durationMinutes: 35,
        note: 'Akıcı',
      ),
    );
    final shelf = await CollectionService().createCollection(
      'Favoriler',
      '#112233',
    );
    await CollectionService().addBook(shelf.id, id);
    await CollectionService().setDisplayMode(
      shelf.id,
      id,
      ShelfDisplayMode.face,
    );
    await QuoteService().createQuote(
      bookId: id,
      text: 'İnsanın hayatında bazı şeyler vardır.',
      page: 12,
    );
  }

  test('yedek kitaplığın tamamını içerir', () async {
    await seedLibrary();
    final manifest = await BackupService().buildManifest();

    expect(manifest['app'], 'Bilge');
    expect(manifest['format_version'], BackupService.formatVersion);
    expect(manifest['books'], hasLength(1));
    expect(manifest['reading_logs'], hasLength(1));
    expect(manifest['collections'], hasLength(1));
    expect(manifest['collection_books'], hasLength(1));
    expect(manifest['quotes'], hasLength(1));
  });

  test('yedek alıp geri yükleyince her şey aynı kalır', () async {
    await seedLibrary();
    final manifest = await BackupService().buildManifest();
    final file = await writeBackup(manifest, asZip: true);

    // Kitaplığı tamamen değiştir: geri yükleme bunları silmeli.
    await BookService().createBook(title: 'Silinecek', totalPages: 10);

    final preview = await BackupService().restore(file);
    expect(preview.books, 1);

    final books = await BookService().fetchBooks();
    expect(books, hasLength(1));
    expect(books.single.title, 'Kürk Mantolu Madonna');
    expect(books.single.author, 'Sabahattin Ali');
    expect(books.single.currentPage, 40);

    final logs = await BookService().fetchLogs(books.single.id);
    expect(logs, hasLength(1));
    expect(logs.single.pagesRead, 40);
    expect(logs.single.durationMinutes, 35);
    expect(logs.single.note, 'Akıcı');

    final shelves = await CollectionService().fetchCollections();
    expect(shelves, hasLength(1));
    expect(shelves.single.name, 'Favoriler');
    expect(shelves.single.bookIds, [books.single.id]);
    expect(
      shelves.single.displayModeFor(books.single.id),
      ShelfDisplayMode.face,
    );

    final quotes = await QuoteService().fetchQuotes();
    expect(quotes, hasLength(1));
    expect(quotes.single.page, 12);
    expect(quotes.single.bookTitle, 'Kürk Mantolu Madonna');
  });

  test('düz JSON yedeği de okunur', () async {
    await seedLibrary();
    final manifest = await BackupService().buildManifest();
    final file = await writeBackup(manifest);

    final preview = await BackupService().restore(file);
    expect(preview.books, 1);
    expect(
      (await BookService().fetchBooks()).single.title,
      'Kürk Mantolu Madonna',
    );
  });

  test('yedek özeti dosyayı değiştirmeden okunur', () async {
    await seedLibrary();
    final file = await writeBackup(await BackupService().buildManifest());

    final preview = await BackupService().inspect(file);
    expect(preview.books, 1);
    expect(preview.quotes, 1);
    // inspect sadece okur: mevcut veri yerinde kalmalı.
    expect(await BookService().fetchBooks(), hasLength(1));
  });

  test('eski uygulama adıyla yazılmış yedek hâlâ okunur', () async {
    // Uygulamanın adı "Mobil Kütüphanem"den "Bilge"ye değişti; kullanıcının
    // elindeki eski yedekler reddedilmemeli.
    await seedLibrary();
    final manifest = await BackupService().buildManifest();
    manifest['app'] = 'Mobil Kütüphanem';
    final file = await writeBackup(manifest);

    final preview = await BackupService().restore(file);
    expect(preview.books, 1);
  });

  test('başka uygulamanın dosyası reddedilir', () async {
    final file = await writeBackup({'app': 'Başka Uygulama', 'books': []});
    expect(() => BackupService().restore(file), throwsA(isA<ApiException>()));
  });

  test('daha yeni biçimli yedek reddedilir', () async {
    final file = await writeBackup({
      'app': 'Mobil Kütüphanem',
      'format_version': BackupService.formatVersion + 1,
      'books': [],
    });
    expect(() => BackupService().restore(file), throwsA(isA<ApiException>()));
  });

  test('bozuk dosya anlaşılır hata verir', () async {
    final file = File('${tempDir.path}/bozuk.json');
    await file.writeAsString('bu bir yedek degil');
    expect(() => BackupService().restore(file), throwsA(isA<ApiException>()));
  });

  test('eksik alanlar varsayılanlarla tamamlanır', () async {
    final file = await writeBackup({
      'app': 'Mobil Kütüphanem',
      'format_version': 1,
      'books': [
        {'id': 7, 'title': 'Yarım Kayıt'},
      ],
    });

    await BackupService().restore(file);
    final book = await BookService().getBook(7);
    expect(book.title, 'Yarım Kayıt');
    expect(book.totalPages, 0);
    expect(book.readingStatus, 'want_to_read');
    expect(book.isFinished, isFalse);
  });

  test('ayarlar yedeğe girer, türetilmiş önbellek girmez', () async {
    await db.insert('settings', {'key': 'daily_page_goal', 'value': '45'});
    await db.insert('settings', {
      'key': 'recommendations_cache',
      'value': '{"items":[]}',
    });

    final manifest = await BackupService().buildManifest();
    final settings = manifest['settings'] as Map<String, Object?>;
    expect(settings['daily_page_goal'], '45');
    expect(settings.containsKey('recommendations_cache'), isFalse);
  });
}
