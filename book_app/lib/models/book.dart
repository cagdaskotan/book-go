class Book {
  Book({
    required this.id,
    required this.title,
    required this.totalPages,
    required this.currentPage,
    required this.isFinished,
    required this.favorite,
    required this.createdAt,
    this.author,
    this.isbn,
    this.coverUrl,
    this.category,
    this.startedAt, // "YYYY-MM-DD"
    this.finishedAt, // "YYYY-MM-DD"
    this.notes,
    this.rating, // 0..100
    this.tags,
    this.readingStatus = 'want_to_read',
  });

  final int id;
  final String title;
  final int totalPages;
  final int currentPage;
  final bool isFinished;
  final bool favorite;
  final DateTime createdAt;
  final String? author;

  /// Okutulan barkod. Künye bulunamasa bile saklanır: kullanıcı tekrar
  /// yazmasın, ileride yeniden sorgulanabilsin, mükerrer eklenmesin.
  final String? isbn;

  final String? coverUrl;
  final String? category;
  final String? startedAt; // date-only string
  final String? finishedAt; // date-only string
  final String? notes;
  final int? rating; // null ise puan yok
  final String? tags;
  final String readingStatus;

  static const Object _sentinel = Object();

  factory Book.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    bool b(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v == 1;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    int? ni(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime dt(String? s) =>
        DateTime.tryParse(s ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

    // Backend bazen tarihleri ISO ile gönderebilir; sadece date kısmını alıyoruz
    String? dateOnly(dynamic v) {
      final s = v as String?;
      if (s == null || s.trim().isEmpty) return null;
      return s.split('T').first;
    }

    return Book(
      id: i(json['id']),
      title: (json['title'] as String?) ?? '',
      totalPages: i(json['total_pages']),
      currentPage: i(json['current_page']),
      isFinished: b(json['is_finished']),
      favorite: b(json['favorite']),
      createdAt: dt(json['created_at'] as String?),
      author: json['author'] as String?,
      isbn: json['isbn'] as String?,
      coverUrl: json['cover_url'] as String?,
      category: json['category'] as String?,
      startedAt: dateOnly(json['started_at']),
      finishedAt: dateOnly(json['finished_at']),
      notes: json['notes'] as String?,
      rating: ni(json['rating']),
      tags: json['tags'] as String?,
      readingStatus: (json['reading_status'] as String?) ?? 'want_to_read',
    );
  }

  Book copyWith({
    int? id,
    String? title,
    int? totalPages,
    int? currentPage,
    bool? isFinished,
    bool? favorite,
    DateTime? createdAt,
    Object? author = _sentinel,
    Object? isbn = _sentinel,
    Object? coverUrl = _sentinel,
    Object? category = _sentinel,
    Object? startedAt = _sentinel,
    Object? finishedAt = _sentinel,
    Object? notes = _sentinel,
    Object? rating = _sentinel,
    Object? tags = _sentinel,
    String? readingStatus,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      isFinished: isFinished ?? this.isFinished,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      author: identical(author, _sentinel) ? this.author : author as String?,
      isbn: identical(isbn, _sentinel) ? this.isbn : isbn as String?,
      coverUrl: identical(coverUrl, _sentinel)
          ? this.coverUrl
          : coverUrl as String?,
      category: identical(category, _sentinel)
          ? this.category
          : category as String?,
      startedAt: identical(startedAt, _sentinel)
          ? this.startedAt
          : startedAt as String?,
      finishedAt: identical(finishedAt, _sentinel)
          ? this.finishedAt
          : finishedAt as String?,
      notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      rating: identical(rating, _sentinel) ? this.rating : rating as int?,
      tags: identical(tags, _sentinel) ? this.tags : tags as String?,
      readingStatus: readingStatus ?? this.readingStatus,
    );
  }
}

/// Günlük (okuma logu) modeli.
/// Web’de kullanılan alanlarla birebir.
class BookLog {
  BookLog({
    required this.id,
    required this.bookId,
    required this.logDate, // "YYYY-MM-DD"
    this.pagesRead, // null veya 0 olabilir
    this.note,
    this.finished = false,
    this.durationMinutes = 0,
  });

  final int id;
  final int bookId;
  final String logDate;
  final int? pagesRead;
  final String? note;
  final bool finished;
  final int durationMinutes;

  factory BookLog.fromJson(Map<String, dynamic> json) {
    int? ni(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    bool b(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v == 1;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
      return false;
    }

    String dateOnly(dynamic v) {
      final s = v as String?;
      if (s == null || s.trim().isEmpty) return '';
      return s.split('T').first;
    }

    return BookLog(
      id: ni(json['id']) ?? 0,
      bookId: ni(json['book_id']) ?? 0,
      logDate: dateOnly(json['log_date']),
      pagesRead: ni(json['pages_read']),
      note: json['note'] as String?,
      finished: b(json['finished']),
      durationMinutes: ni(json['duration_minutes']) ?? 0,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'book_id': bookId,
    'log_date': logDate,
    'pages_read': (pagesRead ?? 0),
    'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
    'finished': finished,
    'duration_minutes': durationMinutes,
  };

  Map<String, dynamic> toUpdateJson() => {
    'log_date': logDate,
    'pages_read': (pagesRead ?? 0),
    'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
    'finished': finished,
    'duration_minutes': durationMinutes,
  };

  static const _sentinel = Object();

  BookLog copyWith({
    int? id,
    int? bookId,
    String? logDate,
    int? pagesRead,
    Object? note = _sentinel,
    bool? finished,
    int? durationMinutes,
  }) {
    return BookLog(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      logDate: logDate ?? this.logDate,
      pagesRead: pagesRead ?? this.pagesRead,
      note: identical(note, _sentinel) ? this.note : note as String?,
      finished: finished ?? this.finished,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
