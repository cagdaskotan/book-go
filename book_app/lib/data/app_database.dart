import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Uygulamanın tek veri kaynağı: cihazdaki SQLite dosyası.
///
/// Sunucu yok. Tüm kitaplar, okuma günlükleri, raflar, alıntılar ve anı
/// defteri sayfaları bu dosyada yaşar; kullanıcı uygulamayı silmediği sürece
/// kalıcıdır. Yedekleme/geri yükleme [BackupService] üzerinden bu tabloların
/// tamamını JSON'a serileştirir.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'kutuphanem.db';

  /// Şema sürümü. Yeni sütun/tablo eklerken artır ve [_migrate] içine
  /// karşılık gelen adımı yaz — kullanıcının verisi asla silinmez.
  static const int schemaVersion = 3;

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  /// Testlerde hazır (in-memory) bir veritabanı enjekte etmek için.
  // ignore: use_setters_to_change_properties
  void overrideForTests(Database database) => _db = database;

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) => createSchema(d),
      onUpgrade: (d, from, to) => _migrate(d, from, to),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Şemayı sıfırdan kurar. [onCreate] ve testler kullanır.
  static Future<void> createSchema(DatabaseExecutor d) async {
    for (final statement in _schema) {
      await d.execute(statement);
    }
  }

  static Future<void> _migrate(Database d, int from, int to) async {
    // 2: Okutulan barkodu saklamaya başladık. Künye bulunamasa bile ISBN
    // elimizde kalsın — kullanıcı tekrar yazmasın, ileride yeniden
    // sorgulayabilelim, aynı kitap iki kez eklenmesin.
    if (from < 2) {
      await d.execute('ALTER TABLE books ADD COLUMN isbn TEXT');
      await d.execute('CREATE INDEX idx_books_isbn ON books(isbn)');
    }

    // 3: Yayınevi. Katalogdan zaten geliyordu ama saklanmıyordu. Türkçe
    // okurda kitap yayıneviyle anılır: aynı eser farklı yayınevinde farklı
    // çeviri ve farklı sayfa sayısı demek.
    if (from < 3) {
      await d.execute('ALTER TABLE books ADD COLUMN publisher TEXT');
    }
  }

  /// Kullanıcı verisi tutan tablolar — yedekleme ve geri yükleme bu listeyi
  /// temel alır (silme sırası yabancı anahtarlara göre tersten işler).
  static const List<String> dataTables = [
    'journal_pages',
    'quotes',
    'collection_books',
    'collections',
    'reading_logs',
    'books',
    'settings',
  ];

  /// Geri yükleme öncesi tüm kullanıcı verisini temizler.
  static Future<void> clearAllData(DatabaseExecutor d) async {
    for (final table in dataTables) {
      await d.delete(table);
    }
  }

  static const List<String> _schema = [
    '''
    CREATE TABLE books (
      id             INTEGER PRIMARY KEY AUTOINCREMENT,
      title          TEXT    NOT NULL,
      author         TEXT,
      publisher      TEXT,
      isbn           TEXT,
      total_pages    INTEGER NOT NULL DEFAULT 0,
      cover_url      TEXT,
      category       TEXT,
      started_at     TEXT,
      finished_at    TEXT,
      is_finished    INTEGER NOT NULL DEFAULT 0,
      reading_status TEXT    NOT NULL DEFAULT 'want_to_read',
      current_page   INTEGER NOT NULL DEFAULT 0,
      notes          TEXT,
      favorite       INTEGER NOT NULL DEFAULT 0,
      rating         INTEGER,
      tags           TEXT,
      created_at     TEXT    NOT NULL
    )
    ''',
    'CREATE INDEX idx_books_status ON books(reading_status)',
    'CREATE INDEX idx_books_favorite ON books(favorite)',
    'CREATE INDEX idx_books_title ON books(title)',
    'CREATE INDEX idx_books_isbn ON books(isbn)',
    '''
    CREATE TABLE reading_logs (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id          INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      log_date         TEXT    NOT NULL,
      pages_read       INTEGER NOT NULL DEFAULT 0,
      duration_minutes INTEGER NOT NULL DEFAULT 0,
      note             TEXT,
      finished         INTEGER NOT NULL DEFAULT 0,
      created_at       TEXT    NOT NULL,
      updated_at       TEXT    NOT NULL
    )
    ''',
    'CREATE INDEX idx_logs_book_date ON reading_logs(book_id, log_date)',
    'CREATE INDEX idx_logs_date ON reading_logs(log_date)',
    '''
    CREATE TABLE collections (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      name       TEXT NOT NULL,
      color      TEXT NOT NULL DEFAULT '#6750E8',
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE collection_books (
      collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
      book_id       INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      display_mode  TEXT    NOT NULL DEFAULT 'spine',
      position      INTEGER NOT NULL DEFAULT 0,
      added_at      TEXT    NOT NULL,
      PRIMARY KEY (collection_id, book_id)
    )
    ''',
    'CREATE INDEX idx_collection_books_book ON collection_books(book_id)',
    '''
    CREATE TABLE quotes (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id    INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      page       INTEGER,
      text       TEXT    NOT NULL,
      favorite   INTEGER NOT NULL DEFAULT 0,
      created_at TEXT    NOT NULL
    )
    ''',
    'CREATE INDEX idx_quotes_book ON quotes(book_id)',
    '''
    CREATE TABLE journal_pages (
      id         TEXT    PRIMARY KEY,
      book_id    INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
      image_path TEXT    NOT NULL,
      text       TEXT    NOT NULL DEFAULT '',
      highlights TEXT    NOT NULL DEFAULT '[]',
      created_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_journal_book ON journal_pages(book_id)',
    '''
    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  ];
}
