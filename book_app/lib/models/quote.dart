class Quote {
  const Quote({
    required this.id,
    required this.bookId,
    required this.text,
    this.page,
    this.favorite = false,
    this.createdAt,
    this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
  });

  final int id;
  final int bookId;
  final String text;
  final int? page;
  final bool favorite;
  final String? createdAt;
  final String? bookTitle;
  final String? bookAuthor;
  final String? coverUrl;

  factory Quote.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

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

    String? s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return Quote(
      id: i(json['id']),
      bookId: i(json['book_id']),
      text: (json['text'] as String?)?.trim() ?? '',
      page: ni(json['page']),
      favorite: b(json['favorite']),
      createdAt: s(json['created_at']),
      bookTitle: s(json['book_title']),
      bookAuthor: s(json['book_author']),
      coverUrl: s(json['cover_url']),
    );
  }
}
