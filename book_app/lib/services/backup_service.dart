import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../utils/dates.dart';
import 'api_exception.dart';
import 'journal_store.dart';
import 'profile_service.dart';
import '../models/reading_status.dart';

/// Yedekleme ve geri yükleme.
///
/// Yedek, tek bir `.zip` dosyasıdır:
/// ```
/// kutuphanem-yedek-2026-11-06.zip
///   backup.json        → tüm kayıtlar (kitaplar, günlük, raflar, alıntılar…)
///   journal/<id>.jpg   → anı defteri sayfa fotoğrafları
/// ```
/// `backup.json` insan tarafından okunabilir; istenirse başka bir araçla da
/// işlenebilir. Geri yükleme, cihazdaki veriyi yedektekiyle **değiştirir**.
class BackupService {
  BackupService();

  /// Yedek biçimi sürümü. Alan eklendiğinde artar; [_assertReadable] eski
  /// sürümleri kabul etmeye devam eder.
  static const int formatVersion = 2;

  /// Yedek dosyasına yazılan uygulama kimliği.
  static const String _appTag = 'Bilge';

  /// Geçmişte yazılmış kimlikler. Uygulamanın adı değişti; eski yedekler
  /// reddedilmesin diye hepsi kabul ediliyor.
  static const Set<String> _knownAppTags = {_appTag, 'Mobil Kütüphanem'};
  static const String _manifestName = 'backup.json';
  static const String _journalPrefix = 'journal/';

  /// Türetilmiş veriler yedeğe girmez — yeniden üretilebilirler.
  static const Set<String> _skippedSettings = {'recommendations_cache'};

  // ---------------------------------------------------------------------------
  // DIŞA AKTARMA
  // ---------------------------------------------------------------------------

  /// Yedeği hazırlayıp paylaşım sayfasını açar (Drive, e-posta, dosyaya kaydet).
  Future<void> shareBackup() async {
    final file = await writeBackupFile();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: 'Bilge yedeği',
      text: 'Kitaplığımın ${todayYmd()} tarihli yedeği',
    );
  }

  /// Yedek arşivini geçici klasöre yazar ve dosyayı döndürür.
  Future<File> writeBackupFile() async {
    final archive = Archive();
    final manifest = await buildManifest();

    // Anı defteri sayfa görsellerini arşive koy.
    for (final image in await _journalImages()) {
      try {
        final file = File(image.sourcePath);
        if (await file.exists()) {
          archive.add(
            ArchiveFile.bytes(image.archiveName, await file.readAsBytes()),
          );
        }
      } catch (_) {
        // okunamayan görseli atla, yedek yine de tamamlanır
      }
    }

    archive.add(
      ArchiveFile.string(
        _manifestName,
        const JsonEncoder.withIndent('  ').convert(manifest),
      ),
    );

    final bytes = ZipEncoder().encodeBytes(archive);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kutuphanem-yedek-${todayYmd()}.zip');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Tüm kullanıcı verisini JSON'a çevirir (kimlikler korunur ki ilişkiler
  /// geri yüklemede bozulmasın).
  Future<Map<String, Object?>> buildManifest() async {
    final db = await AppDatabase.instance.db;

    final books = await db.query('books', orderBy: 'id ASC');
    final logs = await db.query('reading_logs', orderBy: 'id ASC');
    final collections = await db.query('collections', orderBy: 'id ASC');
    final collectionBooks = await db.query('collection_books');
    final quotes = await db.query('quotes', orderBy: 'id ASC');
    final journal = await db.query('journal_pages', orderBy: 'created_at ASC');
    final settingRows = await db.query('settings');

    final settings = <String, String>{};
    for (final row in settingRows) {
      final key = row['key'] as String;
      if (_skippedSettings.contains(key)) continue;
      settings[key] = row['value'] as String;
    }

    final journalPages = journal
        .map(
          (row) => <String, Object?>{
            'id': row['id'],
            'book_id': row['book_id'],
            'text': row['text'],
            'highlights': row['highlights'],
            'created_at': row['created_at'],
            // Arşiv içindeki göreli yol; geri yüklemede buradan okunur.
            'image_file': _archiveNameFor(row['image_path'] as String?),
          },
        )
        .toList();

    return {
      'app': _appTag,
      'format_version': formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': {'display_name': ProfileService.instance.displayName},
      'books': books.map(Map<String, Object?>.from).toList(),
      'reading_logs': logs.map(Map<String, Object?>.from).toList(),
      'collections': collections.map(Map<String, Object?>.from).toList(),
      'collection_books': collectionBooks
          .map(Map<String, Object?>.from)
          .toList(),
      'quotes': quotes.map(Map<String, Object?>.from).toList(),
      'journal_pages': journalPages,
      'settings': settings,
    };
  }

  /// Arşive konacak sayfa görselleri: diskteki kaynak yol + arşiv içi ad.
  Future<List<_JournalImage>> _journalImages() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('journal_pages', columns: ['image_path']);
    final images = <_JournalImage>[];
    for (final row in rows) {
      final path = row['image_path'] as String?;
      final name = _archiveNameFor(path);
      if (path == null || path.isEmpty || name == null) continue;
      images.add(_JournalImage(sourcePath: path, archiveName: name));
    }
    return images;
  }

  /// Diskteki yoldan arşiv içi göreli adı üretir (`journal/123.jpg`).
  static String? _archiveNameFor(String? path) {
    if (path == null || path.isEmpty) return null;
    final name = path.split(RegExp(r'[\\/]')).last;
    return name.isEmpty ? null : '$_journalPrefix$name';
  }

  // ---------------------------------------------------------------------------
  // GERİ YÜKLEME
  // ---------------------------------------------------------------------------

  /// Yedek dosyasını okuyup içeriğini özetler — kullanıcıya onay ekranında
  /// "kaç kitap geri geliyor" diye göstermek için.
  Future<BackupPreview> inspect(File file) async {
    final manifest = await _readManifest(file);
    return BackupPreview(
      exportedAt: DateTime.tryParse(manifest['exported_at']?.toString() ?? ''),
      books: _listOf(manifest['books']).length,
      logs: _listOf(manifest['reading_logs']).length,
      collections: _listOf(manifest['collections']).length,
      quotes: _listOf(manifest['quotes']).length,
      journalPages: _listOf(manifest['journal_pages']).length,
    );
  }

  /// Cihazdaki veriyi yedektekiyle değiştirir.
  Future<BackupPreview> restore(File file) async {
    final bytes = await file.readAsBytes();
    final archive = _tryOpenArchive(bytes);
    final manifest = archive != null
        ? _manifestFromArchive(archive)
        : _manifestFromJson(bytes);
    _assertReadable(manifest);

    final db = await AppDatabase.instance.db;
    await db.transaction((txn) async {
      await AppDatabase.clearAllData(txn);

      for (final row in _listOf(manifest['books'])) {
        await txn.insert('books', _bookRow(row));
      }
      for (final row in _listOf(manifest['reading_logs'])) {
        await txn.insert('reading_logs', _logRow(row));
      }
      for (final row in _listOf(manifest['collections'])) {
        await txn.insert('collections', _collectionRow(row));
      }
      for (final row in _listOf(manifest['collection_books'])) {
        await txn.insert(
          'collection_books',
          _collectionBookRow(row),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final row in _listOf(manifest['quotes'])) {
        await txn.insert('quotes', _quoteRow(row));
      }

      final settings = manifest['settings'];
      if (settings is Map) {
        for (final entry in settings.entries) {
          final key = entry.key.toString();
          if (_skippedSettings.contains(key)) continue;
          await txn.insert('settings', {
            'key': key,
            'value': entry.value.toString(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });

    // Anı defteri görsellerini arşivden çıkarıp satırlarını yaz.
    await _restoreJournal(
      pages: _listOf(manifest['journal_pages']),
      archive: archive,
    );

    final profile = manifest['profile'];
    if (profile is Map) {
      await ProfileService.instance.setDisplayName(
        profile['display_name']?.toString() ?? '',
      );
    } else {
      await ProfileService.instance.load();
    }
    await JournalStore.instance.reload();

    return BackupPreview(
      exportedAt: DateTime.tryParse(manifest['exported_at']?.toString() ?? ''),
      books: _listOf(manifest['books']).length,
      logs: _listOf(manifest['reading_logs']).length,
      collections: _listOf(manifest['collections']).length,
      quotes: _listOf(manifest['quotes']).length,
      journalPages: _listOf(manifest['journal_pages']).length,
    );
  }

  Future<void> _restoreJournal({
    required List<Map<String, Object?>> pages,
    required Archive? archive,
  }) async {
    if (pages.isEmpty) return;
    final db = await AppDatabase.instance.db;
    final journalDir = await JournalStore.journalDirectory();

    // Hangi kitapların var olduğunu bilelim; eksik kitaba bağlı sayfa yabancı
    // anahtarı patlatır.
    final bookRows = await db.query('books', columns: ['id']);
    final bookIds = bookRows.map((r) => r['id'] as int).toSet();

    for (final page in pages) {
      final id = page['id']?.toString();
      final bookId = _int(page['book_id']);
      if (id == null || id.isEmpty || !bookIds.contains(bookId)) continue;

      var imagePath = '';
      final archiveName = page['image_file']?.toString();
      if (archive != null && archiveName != null && archiveName.isNotEmpty) {
        final entry = archive.find(archiveName);
        final data = entry?.readBytes();
        if (data != null) {
          final target = File('${journalDir.path}/${archiveName.split('/').last}');
          await target.writeAsBytes(data, flush: true);
          imagePath = target.path;
        }
      }

      await db.insert('journal_pages', {
        'id': id,
        'book_id': bookId,
        'image_path': imagePath,
        'text': page['text']?.toString() ?? '',
        'highlights': _highlightsJson(page['highlights']),
        'created_at': _int(page['created_at']),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ---------------------------------------------------------------------------
  // Okuma yardımcıları
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>> _readManifest(File file) async {
    final bytes = await file.readAsBytes();
    final archive = _tryOpenArchive(bytes);
    final manifest = archive != null
        ? _manifestFromArchive(archive)
        : _manifestFromJson(bytes);
    _assertReadable(manifest);
    return manifest;
  }

  /// Dosya zip ise arşivi döndürür; düz JSON ise null.
  static Archive? _tryOpenArchive(Uint8List bytes) {
    // ZIP imzası: 'PK\x03\x04'
    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      return null;
    }
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const ApiException(400, 'Yedek dosyası açılamadı.');
    }
  }

  static Map<String, Object?> _manifestFromArchive(Archive archive) {
    final entry = archive.find(_manifestName);
    final data = entry?.readBytes();
    if (data == null) {
      throw const ApiException(
        400,
        'Bu arşivde yedek verisi (backup.json) bulunamadı.',
      );
    }
    return _decodeManifest(data);
  }

  static Map<String, Object?> _manifestFromJson(Uint8List bytes) =>
      _decodeManifest(bytes);

  static Map<String, Object?> _decodeManifest(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // aşağıda ortak hata
    }
    throw const ApiException(400, 'Yedek dosyası okunamadı.');
  }

  static void _assertReadable(Map<String, Object?> manifest) {
    final app = manifest['app']?.toString();
    if (app != null && app.isNotEmpty && !_knownAppTags.contains(app)) {
      throw const ApiException(
        400,
        'Bu dosya başka bir uygulamanın yedeği gibi görünüyor.',
      );
    }
    final version = _int(manifest['format_version'] ?? manifest['schema_version']);
    if (version > formatVersion) {
      throw const ApiException(
        400,
        'Yedek, uygulamanın bu sürümünden daha yeni. Lütfen uygulamayı güncelle.',
      );
    }
    if (manifest['books'] is! List) {
      throw const ApiException(400, 'Yedek dosyasında kitap listesi yok.');
    }
  }

  // ---------------------------------------------------------------------------
  // Satır dönüştürücüler — eksik/yanlış tipli alanlara dayanıklı
  // ---------------------------------------------------------------------------

  static Map<String, Object?> _bookRow(Map<String, Object?> row) {
    final totalPages = _int(row['total_pages']);
    final finished = _bool(row['is_finished']);
    return {
      if (row['id'] != null) 'id': _int(row['id']),
      'title': row['title']?.toString() ?? 'İsimsiz kitap',
      'author': _str(row['author']),
      'publisher': _str(row['publisher']),
      'isbn': _str(row['isbn']),
      'total_pages': totalPages,
      'cover_url': _str(row['cover_url']),
      'category': _str(row['category']),
      'started_at': _date(row['started_at']),
      'finished_at': _date(row['finished_at']),
      'is_finished': finished ? 1 : 0,
      'reading_status': _status(row['reading_status'], finished),
      'current_page': _int(row['current_page']),
      'notes': _str(row['notes']),
      'favorite': _bool(row['favorite']) ? 1 : 0,
      'rating': row['rating'] == null ? null : _int(row['rating']),
      'tags': _str(row['tags']),
      'created_at':
          _str(row['created_at']) ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, Object?> _logRow(Map<String, Object?> row) {
    final now = DateTime.now().toIso8601String();
    return {
      if (row['id'] != null) 'id': _int(row['id']),
      'book_id': _int(row['book_id']),
      'log_date': _date(row['log_date']) ?? todayYmd(),
      'pages_read': _int(row['pages_read']),
      'duration_minutes': _int(row['duration_minutes']),
      'note': _str(row['note']),
      'finished': _bool(row['finished']) ? 1 : 0,
      'created_at': _str(row['created_at']) ?? now,
      'updated_at': _str(row['updated_at']) ?? now,
    };
  }

  static Map<String, Object?> _collectionRow(Map<String, Object?> row) => {
    if (row['id'] != null) 'id': _int(row['id']),
    'name': row['name']?.toString() ?? 'Raf',
    'color': _str(row['color']) ?? '#6750E8',
    'created_at': _str(row['created_at']) ?? DateTime.now().toIso8601String(),
  };

  static Map<String, Object?> _collectionBookRow(Map<String, Object?> row) => {
    'collection_id': _int(row['collection_id']),
    'book_id': _int(row['book_id']),
    'display_mode': _str(row['display_mode']) ?? 'spine',
    'position': _int(row['position']),
    'added_at': _str(row['added_at']) ?? DateTime.now().toIso8601String(),
  };

  static Map<String, Object?> _quoteRow(Map<String, Object?> row) => {
    if (row['id'] != null) 'id': _int(row['id']),
    'book_id': _int(row['book_id']),
    'page': row['page'] == null ? null : _int(row['page']),
    'text': row['text']?.toString() ?? '',
    'favorite': _bool(row['favorite']) ? 1 : 0,
    'created_at': _str(row['created_at']) ?? DateTime.now().toIso8601String(),
  };

  static String _highlightsJson(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is List) return jsonEncode(value);
    return '[]';
  }

  static List<Map<String, Object?>> _listOf(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map(Map<String, Object?>.from).toList();
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final s = value?.toString().toLowerCase();
    return s == '1' || s == 'true';
  }

  static String? _str(Object? value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static String? _date(Object? value) {
    final parsed = parseYmd(value?.toString());
    return parsed == null ? null : ymd(parsed);
  }

  static String _status(Object? value, bool finished) {
    if (finished) return 'finished';
    final s = value?.toString().trim();
    return (s != null && ReadingStatus.dbValues.contains(s))
        ? s
        : ReadingStatus.wantToRead.value;
  }
}

class _JournalImage {
  const _JournalImage({required this.sourcePath, required this.archiveName});
  final String sourcePath;
  final String archiveName;
}

/// Yedek dosyasının özeti.
class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.books,
    required this.logs,
    required this.collections,
    required this.quotes,
    required this.journalPages,
  });

  final DateTime? exportedAt;
  final int books;
  final int logs;
  final int collections;
  final int quotes;
  final int journalPages;
}
