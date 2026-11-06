class Recommendation {
  const Recommendation({
    required this.title,
    required this.reason,
    this.author,
    this.coverUrl,
    this.totalPages = 0,
  });

  final String title;
  final String reason;
  final String? author;
  final String? coverUrl;
  final int totalPages;

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String? s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return Recommendation(
      title: (json['title'] as String?)?.trim() ?? '',
      reason: (json['reason'] as String?)?.trim() ?? '',
      author: s(json['author']),
      coverUrl: s(json['cover_url']),
      totalPages: i(json['total_pages']),
    );
  }
}
