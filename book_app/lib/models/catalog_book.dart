class CatalogBook {
  const CatalogBook({
    required this.isbn,
    required this.title,
    required this.totalPages,
    required this.source,
    this.author,
    this.coverUrl,
    this.category,
    this.publisher,
  });

  final String isbn;
  final String title;
  final int totalPages;
  final String source;
  final String? author;
  final String? coverUrl;
  final String? category;
  final String? publisher;

  factory CatalogBook.fromJson(Map<String, dynamic> json) {
    int integer(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    String? text(dynamic value) {
      final result = value?.toString().trim();
      return result == null || result.isEmpty ? null : result;
    }

    return CatalogBook(
      isbn: text(json['isbn']) ?? '',
      title: text(json['title']) ?? '',
      totalPages: integer(json['total_pages']),
      source: text(json['source']) ?? '',
      author: text(json['author']),
      coverUrl: text(json['cover_url']),
      category: text(json['category']),
      publisher: text(json['publisher']),
    );
  }
}
