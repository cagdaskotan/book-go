import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/book.dart';
import '../utils/dates.dart';
import 'api_exception.dart';
import 'journal_store.dart';

/// Kitaplar ve okuma günlüğü için cihaz-içi depo.
///
/// Eskiden bu sınıf HTTP ile sunucuya giderdi; artık doğrudan SQLite ile
/// konuşuyor. Dışa açık imzalar bilinçli olarak aynı bırakıldı, dolayısıyla
/// ekranlar değişmeden çalışır — fark şu ki her çağrı anında döner ve
/// internet gerektirmez.
class BookService {
  BookService();

  Future<Database> get _db => AppDatabase.instance.db;

  static const _validStatuses = {'want_to_read', 'reading', 'paused'};

  // ---------------------------------------------------------------------------
  // KITAPLAR
  // ---------------------------------------------------------------------------

  Future<List<Book>> fetchBooks() async {
    final db = await _db;
    final rows = await db.query('books', orderBy: 'id DESC');
    return rows.map(bookFromRow).toList();
  }

  Future<Book> getBook(int id) async {
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw const ApiException(404, 'Kayıt bulunamadı.');
    return bookFromRow(rows.first);
  }

  /// Barkodu karşılaştırılabilir hale getirir: tire ve boşluk kaldırılır,
  /// harfler büyütülür (ISBN-10'un sonundaki X için). Hem yazarken hem
  /// ararken aynı biçimi kullanmak şart — yoksa elle tireli girilen bir
  /// barkod, okutulanla eşleşmez.
  static String? normalizeIsbn(String? raw) {
    final clean = raw?.replaceAll(RegExp(r'[\s-]'), '').trim().toUpperCase();
    return (clean == null || clean.isEmpty) ? null : clean;
  }

  /// Bu barkod kitaplıkta zaten var mı?
  ///
  /// Aynı kitabı ikinci kez okutmak sık yapılan bir şey — raf kalabalıklaşır,
  /// istatistik bozulur. Eklemeden önce kullanıcıyı uyarabilmek için.
  Future<Book?> findByIsbn(String isbn) async {
    final clean = normalizeIsbn(isbn);
    if (clean == null) return null;
    final db = await _db;
    final rows = await db.query(
      'books',
      where: 'isbn = ?',
      whereArgs: [clean],
      limit: 1,
    );
    return rows.isEmpty ? null : bookFromRow(rows.first);
  }

  Future<int> createBook({
    required String title,
    required int totalPages,
    String? author,
    String? isbn,
    String? coverUrl,
    String? category,
    String? startedAt,
    String? finishedAt,
    bool? isFinished,
    int? currentPage,
    String? notes,
    bool? favorite,
    String? tags,
    int? rating,
    String? readingStatus,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ApiException(400, 'Kitap adı gerekli.');
    }
    if (totalPages <= 0) {
      throw const ApiException(400, 'Sayfa sayısı sıfırdan büyük olmalı.');
    }

    final finished = isFinished ?? false;
    var page = currentPage ?? 0;
    if (page < 0) page = 0;

    if (rating != null && (rating < 0 || rating > 100)) {
      throw const ApiException(400, 'Puan 0 ile 100 arasında olmalı.');
    }
    if (rating != null && !finished) {
      throw const ApiException(
        400,
        'Puan yalnızca bitirilen kitaplara verilebilir.',
      );
    }

    final start = _parseOrThrow(startedAt, 'Başlama tarihi');
    var finish = _parseOrThrow(finishedAt, 'Bitirme tarihi');

    if (finished) {
      finish ??= todayYmd();
      page = totalPages;
    } else if (page > totalPages) {
      throw const ApiException(
        400,
        'Okunan sayfa, toplam sayfadan fazla olamaz.',
      );
    }
    _assertDateOrder(start, finish);

    final db = await _db;
    return db.insert('books', {
      'title': cleanTitle,
      'author': _orNull(author),
      'isbn': normalizeIsbn(isbn),
      'total_pages': totalPages,
      'cover_url': _orNull(coverUrl),
      'category': _orNull(category),
      'started_at': start,
      'finished_at': finish,
      'is_finished': finished ? 1 : 0,
      'reading_status': _normalizeStatus(readingStatus, finished, page),
      'current_page': page,
      'notes': _orNull(notes),
      'favorite': (favorite ?? false) ? 1 : 0,
      'rating': rating,
      'tags': _orNull(tags),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Kısmi güncelleme: yalnızca verilen alanlar değişir.
  ///
  /// Puan için üç durum: [setRating] false ise dokunulmaz; true + değer ise
  /// yazılır; true + null ise puan kaldırılır.
  Future<void> updateBook(
    int id, {
    String? title,
    String? author,
    String? isbn,
    int? totalPages,
    String? coverUrl,
    String? category,
    String? startedAt,
    String? finishedAt,
    bool? isFinished,
    int? currentPage,
    String? notes,
    bool? favorite,
    String? tags,
    int? rating,
    bool setRating = false,
    String? readingStatus,
  }) async {
    final db = await _db;
    final existing = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) throw const ApiException(404, 'Kayıt bulunamadı.');
    final cur = existing.first;

    final newTitle = (title ?? cur['title'] as String).trim();
    final newTotal = totalPages ?? (cur['total_pages'] as int);
    final finished = isFinished ?? (cur['is_finished'] as int) == 1;
    var page = currentPage ?? (cur['current_page'] as int);
    if (page < 0) page = 0;

    int? newRating = cur['rating'] as int?;
    if (setRating) {
      if (rating != null && (rating < 0 || rating > 100)) {
        throw const ApiException(400, 'Puan 0 ile 100 arasında olmalı.');
      }
      newRating = rating;
    }

    var status = cur['reading_status'] as String;
    if (readingStatus != null) {
      status = _normalizeStatus(readingStatus, finished, page);
    }

    final start = startedAt != null
        ? _parseOrThrow(startedAt, 'Başlama tarihi')
        : cur['started_at'] as String?;
    var finish = finishedAt != null
        ? _parseOrThrow(finishedAt, 'Bitirme tarihi')
        : cur['finished_at'] as String?;

    if (finished) {
      finish ??= todayYmd();
      page = newTotal;
      status = 'finished';
    } else {
      if (page > newTotal) {
        throw const ApiException(
          400,
          'Okunan sayfa, toplam sayfadan fazla olamaz.',
        );
      }
      if (setRating && rating != null) {
        throw const ApiException(
          400,
          'Puan yalnızca bitirilen kitaplara verilebilir.',
        );
      }
      // Kitap "bitmedi"ye döndüyse puan ve bitiş tarihi anlamını yitirir.
      newRating = null;
      finish = null;
      if (status == 'finished') {
        status = _normalizeStatus(null, false, page);
      }
    }

    if (newTitle.isEmpty) throw const ApiException(400, 'Kitap adı gerekli.');
    if (newTotal <= 0) {
      throw const ApiException(400, 'Sayfa sayısı sıfırdan büyük olmalı.');
    }
    _assertDateOrder(start, finish);

    await db.update(
      'books',
      {
        'title': newTitle,
        'author': author != null ? _orNull(author) : cur['author'],
        'isbn': isbn != null ? normalizeIsbn(isbn) : cur['isbn'],
        'total_pages': newTotal,
        'cover_url': coverUrl != null ? _orNull(coverUrl) : cur['cover_url'],
        'category': category != null ? _orNull(category) : cur['category'],
        'started_at': start,
        'finished_at': finish,
        'is_finished': finished ? 1 : 0,
        'reading_status': status,
        'current_page': page,
        'notes': notes != null ? _orNull(notes) : cur['notes'],
        'favorite': favorite != null
            ? (favorite ? 1 : 0)
            : cur['favorite'] as int,
        'rating': newRating,
        'tags': tags != null ? _orNull(tags) : cur['tags'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kitabı ve ona bağlı her şeyi (günlük, alıntı, raf bağları, anı defteri
  /// sayfaları) siler. Anı defteri görselleri diskte yetim kalmasın diye
  /// dosyaları da temizler.
  Future<void> deleteBook(int id) async {
    final db = await _db;
    final journalRows = await db.query(
      'journal_pages',
      columns: ['image_path'],
      where: 'book_id = ?',
      whereArgs: [id],
    );

    final affected = await db.delete('books', where: 'id = ?', whereArgs: [id]);
    if (affected == 0) throw const ApiException(404, 'Kayıt bulunamadı.');

    for (final row in journalRows) {
      final path = row['image_path'] as String?;
      if (path == null || path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // görsel silinemese de kayıt gitti, sorun değil
      }
    }
    if (journalRows.isNotEmpty && JournalStore.instance.isLoaded) {
      await JournalStore.instance.reload();
    }
  }

  Future<void> updateFavorite(int bookId, bool favorite) async {
    final db = await _db;
    final affected = await db.update(
      'books',
      {'favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (affected == 0) throw const ApiException(404, 'Kayıt bulunamadı.');
  }

  // ---------------------------------------------------------------------------
  // OKUMA GÜNLÜĞÜ
  // ---------------------------------------------------------------------------

  Future<List<BookLog>> fetchLogs(int bookId) async {
    final db = await _db;
    final rows = await db.query(
      'reading_logs',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'log_date DESC, id DESC',
    );
    return rows.map(logFromRow).toList();
  }

  /// Tüm kitapların günlük kayıtları (istatistik ve yedekleme için).
  Future<List<BookLog>> fetchAllLogs() async {
    final db = await _db;
    final rows = await db.query(
      'reading_logs',
      orderBy: 'log_date DESC, id DESC',
    );
    return rows.map(logFromRow).toList();
  }

  Future<void> createLog(BookLog log) async {
    final db = await _db;
    final date = _requireDate(log.logDate);
    final pages = log.pagesRead ?? 0;
    _validateLog(pages, log.durationMinutes, log.note);

    final book = await db.query(
      'books',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [log.bookId],
      limit: 1,
    );
    if (book.isEmpty) throw const ApiException(404, 'Kitap bulunamadı.');

    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('reading_logs', {
        'book_id': log.bookId,
        'log_date': date,
        'pages_read': pages,
        'duration_minutes': log.durationMinutes,
        'note': _orNull(log.note),
        'finished': log.finished ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });
      await _recomputeProgress(txn, log.bookId);
    });
  }

  Future<void> updateLog(BookLog log) async {
    final db = await _db;
    final date = _requireDate(log.logDate);
    final pages = log.pagesRead ?? 0;
    _validateLog(pages, log.durationMinutes, log.note);

    final existing = await db.query(
      'reading_logs',
      columns: ['book_id'],
      where: 'id = ?',
      whereArgs: [log.id],
      limit: 1,
    );
    if (existing.isEmpty) throw const ApiException(404, 'Kayıt bulunamadı.');
    final bookId = existing.first['book_id'] as int;

    await db.transaction((txn) async {
      await txn.update(
        'reading_logs',
        {
          'log_date': date,
          'pages_read': pages,
          'duration_minutes': log.durationMinutes,
          'note': _orNull(log.note),
          'finished': log.finished ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [log.id],
      );
      await _recomputeProgress(txn, bookId);
    });
  }

  Future<void> deleteLog(int logId) async {
    final db = await _db;
    final existing = await db.query(
      'reading_logs',
      columns: ['book_id'],
      where: 'id = ?',
      whereArgs: [logId],
      limit: 1,
    );
    if (existing.isEmpty) throw const ApiException(404, 'Kayıt bulunamadı.');
    final bookId = existing.first['book_id'] as int;

    await db.transaction((txn) async {
      await txn.delete('reading_logs', where: 'id = ?', whereArgs: [logId]);
      await _recomputeProgress(txn, bookId);
    });
  }

  /// Kitabın ilerlemesini ve bitmişlik durumunu günlük kayıtlarından türetir.
  ///
  /// Kural: okunan sayfaların toplamı ilerlemedir (toplam sayfada kırpılır).
  /// "Bitirdim" işaretli bir kayıt varsa kitap o tarihte bitmiş sayılır;
  /// yoksa ilerleme toplamı yakaladığında bitmiş sayılır. Hiçbiri yoksa
  /// bitiş tarihi temizlenir — tek doğru kaynak günlüktür.
  static Future<void> _recomputeProgress(
    DatabaseExecutor txn,
    int bookId,
  ) async {
    final sums = await txn.rawQuery(
      'SELECT COALESCE(SUM(pages_read), 0) AS total '
      'FROM reading_logs WHERE book_id = ?',
      [bookId],
    );
    final readPages = (sums.first['total'] as num?)?.toInt() ?? 0;

    final bookRows = await txn.query(
      'books',
      columns: ['total_pages', 'finished_at', 'reading_status'],
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (bookRows.isEmpty) return;
    final totalPages = bookRows.first['total_pages'] as int;
    final previousFinishedAt = bookRows.first['finished_at'] as String?;
    final previousStatus = bookRows.first['reading_status'] as String;

    final finishMarks = await txn.rawQuery(
      'SELECT MAX(log_date) AS d '
      'FROM reading_logs WHERE book_id = ? AND finished = 1',
      [bookId],
    );
    final finishedLogDate = finishMarks.first['d'] as String?;

    var progress = readPages;
    if (totalPages > 0 && progress > totalPages) progress = totalPages;

    final bool isFinished;
    final String? finishedAt;
    if (finishedLogDate != null && finishedLogDate.isNotEmpty) {
      isFinished = true;
      finishedAt = finishedLogDate;
    } else if (totalPages > 0 && progress >= totalPages) {
      isFinished = true;
      finishedAt = previousFinishedAt ?? todayYmd();
    } else {
      isFinished = false;
      finishedAt = null;
    }

    final String status;
    if (isFinished) {
      status = 'finished';
    } else if (progress > 0 && previousStatus != 'paused') {
      status = 'reading';
    } else {
      status = previousStatus == 'finished' ? 'want_to_read' : previousStatus;
    }

    await txn.update(
      'books',
      {
        'current_page': progress,
        'is_finished': isFinished ? 1 : 0,
        'finished_at': finishedAt,
        'reading_status': status,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // ---------------------------------------------------------------------------
  // YARDIMCILAR
  // ---------------------------------------------------------------------------

  static void _validateLog(int pages, int minutes, String? note) {
    if (pages < 0) {
      throw const ApiException(400, 'Okunan sayfa negatif olamaz.');
    }
    if (minutes < 0) {
      throw const ApiException(400, 'Süre negatif olamaz.');
    }
    if (pages == 0 && minutes == 0 && (note?.trim().isEmpty ?? true)) {
      throw const ApiException(
        400,
        'Sayfa, süre veya not alanlarından en az birini doldur.',
      );
    }
  }

  static String _requireDate(String raw) {
    final parsed = parseYmd(raw);
    if (parsed == null) {
      throw const ApiException(400, 'Geçerli bir tarih seç.');
    }
    return ymd(parsed);
  }

  static String? _parseOrThrow(String? raw, String label) {
    try {
      return normalizeYmd(raw);
    } on FormatException {
      throw ApiException(400, '$label geçersiz (YYYY-AA-GG).');
    }
  }

  static void _assertDateOrder(String? start, String? finish) {
    final s = parseYmd(start);
    final f = parseYmd(finish);
    if (s != null && f != null && f.isBefore(s)) {
      throw const ApiException(
        400,
        'Bitirme tarihi, başlama tarihinden önce olamaz.',
      );
    }
  }

  static String _normalizeStatus(String? raw, bool finished, int currentPage) {
    if (finished) return 'finished';
    final trimmed = raw?.trim();
    if (trimmed != null && _validStatuses.contains(trimmed)) return trimmed;
    return currentPage > 0 ? 'reading' : 'want_to_read';
  }

  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// SQLite satırını [Book] nesnesine çevirir.
Book bookFromRow(Map<String, Object?> row) => Book(
  id: row['id'] as int,
  title: row['title'] as String? ?? '',
  totalPages: row['total_pages'] as int? ?? 0,
  currentPage: row['current_page'] as int? ?? 0,
  isFinished: (row['is_finished'] as int? ?? 0) == 1,
  favorite: (row['favorite'] as int? ?? 0) == 1,
  createdAt:
      DateTime.tryParse(row['created_at'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0),
  author: row['author'] as String?,
  isbn: row['isbn'] as String?,
  coverUrl: row['cover_url'] as String?,
  category: row['category'] as String?,
  startedAt: row['started_at'] as String?,
  finishedAt: row['finished_at'] as String?,
  notes: row['notes'] as String?,
  rating: row['rating'] as int?,
  tags: row['tags'] as String?,
  readingStatus: row['reading_status'] as String? ?? 'want_to_read',
);

/// SQLite satırını [BookLog] nesnesine çevirir.
BookLog logFromRow(Map<String, Object?> row) => BookLog(
  id: row['id'] as int,
  bookId: row['book_id'] as int,
  logDate: row['log_date'] as String? ?? '',
  pagesRead: row['pages_read'] as int?,
  note: row['note'] as String?,
  finished: (row['finished'] as int? ?? 0) == 1,
  durationMinutes: row['duration_minutes'] as int? ?? 0,
);
