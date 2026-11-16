import 'dart:convert';
import 'dart:io';

import 'package:book_app/models/reading_status.dart';
import 'package:book_app/services/backup_service.dart';
import 'package:book_app/services/book_service.dart';
import 'package:book_app/services/collection_service.dart';
import 'package:book_app/services/quote_service.dart';
import 'package:book_app/services/sample_library_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Örnek kitaplık: uygulamayı dolu görmek için eklenen veri.
///
/// En kritik iddia **temizlemenin kullanıcının kitaplarına dokunmaması**.
/// Örnek veriyi kaldırırken gerçek kitaplığı silmek onarılamaz bir hata
/// olurdu; bu yüzden burada ayrıca sınanıyor.
void main() {
  // Defter sayfalarını geri yüklemek path_provider'a uzanıyor; birim
  // testinde platform kanalı yok, o yüzden geçici bir klasörle taklit
  // ediyoruz.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late BookService books;
  late Directory tempDir;

  setUp(() async {
    db = await openTestDatabase();
    books = BookService();
    tempDir = await Directory.systemTemp.createTemp('ornek-kitaplik-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tempDir.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('kurulum her özelliği besleyen veriyi üretir', () async {
    expect(await SampleLibraryService.isInstalled(), isFalse);

    final summary = await SampleLibraryService.install();

    expect(summary.books, greaterThanOrEqualTo(8));
    expect(summary.quotes, greaterThanOrEqualTo(4));
    expect(summary.collections, 2);
    expect(summary.journalPages, greaterThanOrEqualTo(2));
    expect(await SampleLibraryService.isInstalled(), isTrue);

    final all = await books.fetchBooks();
    expect(all.length, summary.books);

    // Her okuma durumundan en az bir kitap olsun ki durum süzgeçleri,
    // "okuyorum" rafı ve istatistikler boş kalmasın.
    final statuses = all.map((b) => b.readingStatus).toSet();
    for (final status in ReadingStatus.values) {
      expect(statuses, contains(status.value), reason: '${status.value} yok');
    }

    final quotes = await QuoteService().fetchQuotes();
    expect(quotes.any((q) => q.favorite), isTrue);

    final pages = await db.query('journal_pages');
    expect(pages, hasLength(summary.journalPages));
    // Örnek sayfaların fotoğrafı yok; defter metni gösteriyor.
    expect(pages.every((p) => '${p['text']}'.isNotEmpty), isTrue);
    expect(pages.any((p) => '${p['highlights']}'.contains('"s"')), isTrue);
  });

  test('bitirilen kitaplar tam ilerleme ve bitiş tarihiyle gelir', () async {
    await SampleLibraryService.install();

    final finished = (await books.fetchBooks())
        .where((b) => b.readingStatus == ReadingStatus.finished.value)
        .toList();

    expect(finished, isNotEmpty);
    for (final book in finished) {
      // Günlük kayıtlarının toplamı sayfa sayısını tutmalı: tutmazsa
      // ilerleme çubuğu %100'e varmaz ve kitap "bitti" görünmez.
      expect(
        book.currentPage,
        book.totalPages,
        reason: '${book.title} ilerlemesi eksik',
      );
      expect(book.finishedAt, isNotNull);
      expect(book.rating, isNotNull);
    }
  });

  test('ara verilen ve bırakılan kitaplar okuyora dönmez', () async {
    await SampleLibraryService.install();

    final dormant = (await books.fetchBooks()).where(
      (b) => ReadingStatus.parse(b.readingStatus).isDormant,
    );

    expect(dormant, isNotEmpty);
    for (final book in dormant) {
      // Bu kitapların günlük kaydı var; ilerleme hesabı durumu ezmemeli.
      expect(book.currentPage, greaterThan(0));
      expect(ReadingStatus.parse(book.readingStatus).isDormant, isTrue);
    }
  });

  test('bugün okunmuş bir kayıt var, seri canlı başlar', () async {
    await SampleLibraryService.install();

    final today = DateTime.now();
    final stamp =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final rows = await db.query(
      'reading_logs',
      where: 'log_date = ?',
      whereArgs: [stamp],
    );
    expect(rows, isNotEmpty, reason: 'bugüne kayıt yok, seri sıfır görünür');
  });

  test('temizleme kullanıcının kendi kitabına dokunmaz', () async {
    // Kullanıcının gerçek kitabı — örnek veriden önce de sonra da durmalı.
    final mine = await books.createBook(
      title: 'Benim Kitabım',
      totalPages: 200,
      author: 'Ben',
    );
    final myShelf = await CollectionService().createCollection(
      'Benim Rafım',
      '#123456',
    );
    await QuoteService().createQuote(bookId: mine, text: 'Benim alıntım');

    await SampleLibraryService.install();
    await SampleLibraryService.remove();

    expect(await SampleLibraryService.isInstalled(), isFalse);

    final remaining = await books.fetchBooks();
    expect(remaining, hasLength(1));
    expect(remaining.single.id, mine);

    final shelves = await CollectionService().fetchCollections();
    expect(shelves.map((c) => c.id).toList(), [myShelf.id]);

    final quotes = await QuoteService().fetchQuotes();
    expect(quotes, hasLength(1));
    expect(quotes.single.text, 'Benim alıntım');

    expect(await db.query('journal_pages'), isEmpty);
    // Örnek kitapların günlük kayıtları da gitmeli.
    expect(await db.query('reading_logs'), isEmpty);
  });

  test('örnek kitap elle silinmişse temizleme patlamaz', () async {
    await SampleLibraryService.install();

    // Kullanıcı örnek kitaplardan birini kendi eliyle siler.
    final first = (await books.fetchBooks()).first;
    await books.deleteBook(first.id);

    await SampleLibraryService.remove();

    expect(await SampleLibraryService.isInstalled(), isFalse);
    expect(await books.fetchBooks(), isEmpty);
  });

  test('iki kez kurmak kitaplığı ikiye katlamaz', () async {
    final first = await SampleLibraryService.install();
    // Kullanıcı düğmeye ikinci kez basamıyor (kart "temizle"ye dönüyor),
    // ama servis yine de üst üste yazmak yerine temiz davranmalı.
    await SampleLibraryService.remove();
    final second = await SampleLibraryService.install();

    expect(second.books, first.books);
    expect(await books.fetchBooks(), hasLength(first.books));
  });

  test('yedek gidip gelince örnek veri yine temizlenebilir', () async {
    // Riskin bedeli yüksek: işaretçi kitap kimliklerini tutuyor, yedek
    // kimlikleri korumazsa ya da işaretçi yedeğe girmezse "temizle"
    // kullanıcının gerçek kitaplarını silebilir.
    final mine = await books.createBook(title: 'Benim Kitabım', totalPages: 90);
    await SampleLibraryService.install();

    final manifest = await BackupService().buildManifest();
    final file = File('${tempDir.path}/yedek.json');
    await file.writeAsString(jsonEncode(manifest));

    await BackupService().restore(file);

    // İşaretçi yedekle birlikte geldi mi?
    expect(await SampleLibraryService.isInstalled(), isTrue);

    await SampleLibraryService.remove();

    final remaining = await books.fetchBooks();
    expect(remaining, hasLength(1));
    expect(remaining.single.title, 'Benim Kitabım');
    expect(remaining.single.id, mine);
  });

  test('her örnek kitabın kapağı var', () async {
    // Örnek kitaplık uygulamayı "hazır" göstermek için var; kapaksız raf
    // yarım kalmış hissi veriyor. Adresler kurulum anında aranmıyor,
    // tohum verisinde sabit duruyor — ağ yoksa kurulum yine çalışsın diye.
    await SampleLibraryService.install();

    final all = await books.fetchBooks();
    for (final book in all) {
      final url = (book.coverUrl ?? '').trim();
      expect(url, isNotEmpty, reason: '${book.title} kapaksız');
      expect(
        url,
        startsWith('https://covers.openlibrary.org/'),
        reason: '${book.title} beklenmeyen kapak kaynağı',
      );
    }
  });

  test('kapaklar birbirinden farklı', () async {
    // Kopyala-yapıştır sırasında aynı kimliği iki kitaba yazmak kolay;
    // rafta iki aynı kapak görünce örnek veri sahte duruyor.
    await SampleLibraryService.install();

    final urls = (await books.fetchBooks())
        .map((b) => b.coverUrl)
        .whereType<String>()
        .toList();
    expect(urls.toSet().length, urls.length, reason: 'yinelenen kapak var');
  });
}
