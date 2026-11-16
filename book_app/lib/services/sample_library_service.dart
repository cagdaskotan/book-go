import 'dart:convert';

import '../data/app_database.dart';
import '../data/settings_store.dart';
import '../models/book.dart';
import '../models/book_collection.dart';
import '../models/reading_status.dart';
import '../utils/dates.dart';
import 'book_service.dart';
import 'collection_service.dart';
import 'journal_store.dart';
import 'quote_service.dart';

/// Örnek kitaplık — uygulamayı dolu hâliyle görmek için.
///
/// Boş bir uygulamada hiçbir özellik kendini anlatamıyor: ısı haritası boş,
/// seri sıfır, yıl karnesi yok, raf gri. Örnek veri bunların hepsini tek
/// dokunuşta canlandırıyor.
///
/// İki kural gözetiliyor:
///
/// * **Kullanıcının verisine dokunulmaz.** Örnek kayıtlar eklenir, mevcut
///   kitaplık silinmez.
/// * **İz bırakmaz.** Eklenen her kaydın kimliği saklanıyor; temizleme
///   tam olarak onları siliyor, gerçek kitapları değil.
class SampleLibraryService {
  SampleLibraryService._();

  static const String _marker = 'sample_library_ids';

  static final _books = BookService();
  static final _collections = CollectionService();
  static final _quotes = QuoteService();

  /// Örnek veri şu an yüklü mü?
  static Future<bool> isInstalled() async =>
      (await SettingsStore.getString(_marker)) != null;

  /// Örnek kitaplığı kurar ve eklenen kayıt sayısını döndürür.
  static Future<SampleSummary> install() async {
    final bookIds = <int>[];
    final collectionIds = <int>[];
    final journalIds = <String>[];

    for (final seed in _seeds) {
      final id = await _books.createBook(
        title: seed.title,
        author: seed.author,
        publisher: seed.publisher,
        totalPages: seed.pages,
        category: seed.category,
        isbn: seed.isbn,
        coverUrl: seed.coverUrl,
        readingStatus: seed.status.value,
        isFinished: seed.status == ReadingStatus.finished ? true : null,
        rating: seed.status == ReadingStatus.finished ? seed.rating : null,
        favorite: seed.favorite ? true : null,
        notes: seed.note,
        startedAt: seed.startedAt,
        finishedAt: seed.status == ReadingStatus.finished
            ? seed.finishedAt
            : null,
      );
      bookIds.add(id);

      for (final log in seed.logs) {
        await _books.createLog(
          BookLog(
            id: 0,
            bookId: id,
            logDate: log.date,
            pagesRead: log.pages,
            durationMinutes: log.minutes,
            note: log.note,
            finished: log.finished,
          ),
        );
      }
    }

    // --- Raflar
    final favorites = await _collections.createCollection(
      'Başucu kitaplarım',
      '#C77D3B',
    );
    collectionIds.add(favorites.id);
    final classics = await _collections.createCollection(
      'Klasikler',
      '#426B9B',
    );
    collectionIds.add(classics.id);

    for (var i = 0; i < bookIds.length && i < 4; i++) {
      await _collections.addBook(favorites.id, bookIds[i]);
    }
    for (var i = 3; i < bookIds.length && i < 8; i++) {
      await _collections.addBook(classics.id, bookIds[i]);
    }
    // Rafta çeşitlilik olsun: bazı kitaplar kapağı dönük dursun.
    if (bookIds.isNotEmpty) {
      await _collections.setDisplayMode(
        favorites.id,
        bookIds.first,
        ShelfDisplayMode.face,
      );
    }

    // --- Alıntılar
    for (final quote in _quoteSeeds) {
      final index = quote.bookIndex.clamp(0, bookIds.length - 1);
      await _quotes.createQuote(
        bookId: bookIds[index],
        text: quote.text,
        page: quote.page,
        favorite: quote.favorite,
      );
    }

    // --- Anı defteri sayfaları
    final db = await AppDatabase.instance.db;
    for (final page in _journalSeeds) {
      final index = page.bookIndex.clamp(0, bookIds.length - 1);
      final id = 'sample-${DateTime.now().microsecondsSinceEpoch}-$index';
      await db.insert('journal_pages', {
        'id': id,
        'book_id': bookIds[index],
        // Örnek sayfanın fotoğrafı yok; defter zaten metni gösteriyor.
        'image_path': '',
        'text': page.text,
        'highlights': jsonEncode(page.highlights),
        'created_at': DateTime.now()
            .subtract(Duration(days: page.daysAgo))
            .millisecondsSinceEpoch,
      });
      journalIds.add(id);
    }
    await JournalStore.instance.reload();

    await SettingsStore.setString(
      _marker,
      jsonEncode({
        'books': bookIds,
        'collections': collectionIds,
        'journal': journalIds,
      }),
    );

    return SampleSummary(
      books: bookIds.length,
      quotes: _quoteSeeds.length,
      collections: collectionIds.length,
      journalPages: journalIds.length,
    );
  }

  /// Yalnızca örnek kayıtları siler; kullanıcının kendi kitapları kalır.
  static Future<void> remove() async {
    final raw = await SettingsStore.getString(_marker);
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final db = await AppDatabase.instance.db;

      for (final id in (data['journal'] as List? ?? [])) {
        await db.delete('journal_pages', where: 'id = ?', whereArgs: ['$id']);
      }
      for (final id in (data['collections'] as List? ?? [])) {
        await _collections.deleteCollection(id as int);
      }
      // Kitabı silmek günlüğünü, alıntısını ve raf bağlarını da siliyor.
      for (final id in (data['books'] as List? ?? [])) {
        try {
          await _books.deleteBook(id as int);
        } catch (_) {
          // Kullanıcı elle silmişse sorun değil.
        }
      }
      await JournalStore.instance.reload();
    } catch (_) {
      // Bozuk kayıt: işaretçiyi temizleyip devam et.
    }
    await SettingsStore.remove(_marker);
  }

  // ---------------------------------------------------------------------------
  // Tohum veriler
  // ---------------------------------------------------------------------------

  /// Bugünden [daysAgo] gün önceki tarih.
  static String _day(int daysAgo) =>
      ymd(DateTime.now().subtract(Duration(days: daysAgo)));

  /// Örnek kitaplar: her okuma durumundan, puanlısı puansızı, serili serisiz.
  ///
  /// Son beş gün kesintisiz okunmuş görünüyor ki seri, ısı haritası ve
  /// günlük hedef göstergeleri dolu gelsin.
  static final List<_BookSeed> _seeds = [
    _BookSeed(
      title: 'Kürk Mantolu Madonna',
      cover: 10848013,
      author: 'Sabahattin Ali',
      publisher: 'Yapı Kredi Yayınları',
      category: 'Roman',
      isbn: '9789750718533',
      pages: 160,
      status: ReadingStatus.reading,
      favorite: true,
      startedAt: _day(9),
      note: 'Raif Efendi anlatıcı olarak sessiz ama her satırda var.',
      logs: [
        _LogSeed(_day(9), 22, 30),
        _LogSeed(_day(8), 18, 25),
        _LogSeed(_day(4), 26, 35, note: 'Maria Puder bölümü'),
        _LogSeed(_day(3), 20, 28),
        _LogSeed(_day(2), 15, 20),
        _LogSeed(_day(1), 19, 26),
        _LogSeed(_day(0), 12, 18),
      ],
    ),
    _BookSeed(
      title: 'Tutunamayanlar',
      cover: 8730101,
      author: 'Oğuz Atay',
      publisher: 'İletişim Yayınları',
      category: 'Roman',
      isbn: '9789754704587',
      pages: 724,
      status: ReadingStatus.paused,
      startedAt: _day(60),
      note: 'Ara verdim, dinlenip döneceğim.',
      logs: [
        _LogSeed(_day(60), 40, 60),
        _LogSeed(_day(58), 35, 50),
        _LogSeed(_day(52), 45, 65),
      ],
    ),
    _BookSeed(
      title: 'Körlük',
      cover: 10482411,
      author: 'José Saramago',
      publisher: 'Kırmızı Kedi',
      category: 'Roman',
      isbn: '9786050918243',
      pages: 328,
      status: ReadingStatus.finished,
      rating: 90,
      favorite: true,
      startedAt: _day(40),
      finishedAt: _day(22),
      note: 'Noktalama yokluğuna alışınca akıp gidiyor.',
      logs: [
        _LogSeed(_day(40), 60, 80),
        _LogSeed(_day(35), 80, 95),
        _LogSeed(_day(30), 90, 110),
        _LogSeed(_day(22), 98, 120, note: 'Bitti', finished: true),
      ],
    ),
    _BookSeed(
      title: 'Saatleri Ayarlama Enstitüsü',
      cover: 8996939,
      author: 'Ahmet Hamdi Tanpınar',
      publisher: 'Dergâh Yayınları',
      category: 'Roman',
      isbn: '9789759953621',
      pages: 382,
      status: ReadingStatus.finished,
      rating: 80,
      startedAt: _day(95),
      finishedAt: _day(70),
      logs: [
        _LogSeed(_day(95), 120, 150),
        _LogSeed(_day(84), 140, 160),
        _LogSeed(_day(70), 122, 140, finished: true),
      ],
    ),
    _BookSeed(
      title: 'Sineklerin Tanrısı',
      cover: 8684447,
      author: 'William Golding',
      publisher: 'İş Bankası Kültür Yayınları',
      category: 'Roman',
      isbn: '9786053606536',
      pages: 254,
      status: ReadingStatus.finished,
      rating: 70,
      startedAt: _day(130),
      finishedAt: _day(118),
      logs: [
        _LogSeed(_day(130), 130, 150),
        _LogSeed(_day(118), 124, 140, finished: true),
      ],
    ),
    _BookSeed(
      title: 'İnsanın Anlam Arayışı',
      cover: 8516506,
      author: 'Viktor E. Frankl',
      publisher: 'Okuyan Us',
      category: 'Psikoloji',
      isbn: '9789758717884',
      pages: 160,
      status: ReadingStatus.finished,
      rating: 100,
      favorite: true,
      startedAt: _day(160),
      finishedAt: _day(150),
      logs: [_LogSeed(_day(150), 160, 180, finished: true)],
    ),
    _BookSeed(
      title: 'Satranç',
      cover: 5548285,
      author: 'Stefan Zweig',
      publisher: 'İş Bankası Kültür Yayınları',
      category: 'Öykü',
      isbn: '9786053321125',
      pages: 76,
      status: ReadingStatus.wantToRead,
    ),
    _BookSeed(
      title: 'Dönüşüm',
      cover: 12820198,
      author: 'Franz Kafka',
      publisher: 'Can Yayınları',
      category: 'Roman',
      isbn: '9789750719387',
      pages: 88,
      status: ReadingStatus.wantToRead,
    ),
    _BookSeed(
      title: 'Ulysses',
      cover: 13136548,
      author: 'James Joyce',
      publisher: 'Yapı Kredi Yayınları',
      category: 'Roman',
      isbn: '9789750826108',
      pages: 1024,
      status: ReadingStatus.abandoned,
      startedAt: _day(200),
      note: 'Şimdilik benden uzak. Belki ileride.',
      logs: [_LogSeed(_day(200), 30, 70), _LogSeed(_day(196), 18, 55)],
    ),
    _BookSeed(
      title: 'Yüzbaşının Kızı',
      cover: 893480,
      author: 'Aleksandr Puşkin',
      publisher: 'İş Bankası Kültür Yayınları',
      category: 'Roman',
      isbn: '9789754587869',
      pages: 176,
      status: ReadingStatus.reading,
      startedAt: _day(5),
      logs: [
        _LogSeed(_day(5), 28, 35),
        _LogSeed(_day(2), 24, 30),
        _LogSeed(_day(0), 18, 22),
      ],
    ),
  ];

  static const List<_QuoteSeed> _quoteSeeds = [
    _QuoteSeed(
      bookIndex: 0,
      page: 14,
      favorite: true,
      text:
          'İnsanın bütün ömrünce beklediği bir şey vardır; onu bulduğu gün '
          'hayatın bütün manası değişir.',
    ),
    _QuoteSeed(
      bookIndex: 0,
      page: 87,
      text: 'Hayatta en çok korktuğum şey, bir gün hiçbir şeye şaşırmamaktı.',
    ),
    _QuoteSeed(
      bookIndex: 2,
      page: 143,
      favorite: true,
      text: 'Sanırım körleşmedik, sanırım köründük. Gören ama görmeyen körler.',
    ),
    _QuoteSeed(
      bookIndex: 3,
      page: 61,
      text: 'Hiçbir şey hayat kadar şaşırtıcı olamaz. Yazı hariç, yazı hariç!',
    ),
    _QuoteSeed(
      bookIndex: 5,
      page: 102,
      favorite: true,
      text: 'Yaşamak için bir nedeni olan, neredeyse her nasıla katlanabilir.',
    ),
    _QuoteSeed(
      bookIndex: 1,
      page: 288,
      text: 'Ben ne zaman bir şeye başlasam, sonu gelmiyor.',
    ),
  ];

  static const List<_JournalSeed> _journalSeeds = [
    _JournalSeed(
      bookIndex: 0,
      daysAgo: 3,
      text:
          'Bir insanın bütün hayatını değiştiren anların, yaşandıkları sırada '
          'ne kadar sıradan göründüğüne hep şaşmışımdır. Oysa sonradan dönüp '
          'baktığımızda, her şeyin tam o anda başladığını anlarız.',
      highlights: [
        {'id': 'h1', 's': 0, 'e': 62, 'c': 0, 'n': 'Tam da böyle'},
      ],
    ),
    _JournalSeed(
      bookIndex: 2,
      daysAgo: 25,
      text:
          'Körler dünyasında tek gören olmak, bir ayrıcalık değil bir yüktür. '
          'Herkesin göremediğini görmek, görmek zorunda kalmaktır.',
      highlights: [
        {'id': 'h1', 's': 0, 'e': 48, 'c': 1, 'n': ''},
      ],
    ),
  ];
}

/// Kurulum sonrası özet — kullanıcıya ne eklendiğini söylemek için.
class SampleSummary {
  const SampleSummary({
    required this.books,
    required this.quotes,
    required this.collections,
    required this.journalPages,
  });

  final int books;
  final int quotes;
  final int collections;
  final int journalPages;
}

class _BookSeed {
  const _BookSeed({
    required this.title,
    required this.author,
    required this.publisher,
    required this.category,
    required this.pages,
    required this.status,
    this.cover,
    this.isbn,
    this.rating,
    this.favorite = false,
    this.note,
    this.startedAt,
    this.finishedAt,
    this.logs = const [],
  });

  final String title;
  final String author;
  final String publisher;
  final String category;
  final int pages;
  final ReadingStatus status;

  /// Open Library kapak kimliği.
  ///
  /// Adres kurulum anında aranmıyor, önceden çözülüp buraya yazıldı:
  /// on kitap için on HTTP isteği kurulumu yavaşlatır ve ağ yoksa
  /// tamamen başarısız olur. Kimlikler sabit; görsel ilk gösterimde
  /// inip önbelleğe alınıyor, inemezse üretilmiş cilde düşüyor.
  final int? cover;

  final String? isbn;

  /// Kapak adresi — uygulamanın kitap ararken kullandığı kaynağın aynısı.
  String? get coverUrl =>
      cover == null ? null : 'https://covers.openlibrary.org/b/id/$cover-L.jpg';

  final int? rating;
  final bool favorite;
  final String? note;
  final String? startedAt;
  final String? finishedAt;
  final List<_LogSeed> logs;
}

class _LogSeed {
  const _LogSeed(
    this.date,
    this.pages,
    this.minutes, {
    this.note,
    this.finished = false,
  });

  final String date;
  final int pages;
  final int minutes;
  final String? note;
  final bool finished;
}

class _QuoteSeed {
  const _QuoteSeed({
    required this.bookIndex,
    required this.text,
    this.page,
    this.favorite = false,
  });

  final int bookIndex;
  final String text;
  final int? page;
  final bool favorite;
}

class _JournalSeed {
  const _JournalSeed({
    required this.bookIndex,
    required this.text,
    required this.daysAgo,
    this.highlights = const [],
  });

  final int bookIndex;
  final String text;
  final int daysAgo;
  final List<Map<String, Object?>> highlights;
}
