import 'dart:convert';

import '../data/app_database.dart';
import '../data/settings_store.dart';
import '../models/catalog_book.dart';
import '../models/recommendation.dart';
import 'catalog_service.dart';

/// Kitaplığa bakıp öneri üreten motor — eskiden sunucuda çalışıyordu,
/// artık cihazda.
///
/// Profil, kullanıcının kitaplarından çıkarılır: bitirilen ve yüksek puan
/// verilen kitaplar daha ağır sayılır. En sevilen yazarlar ve türler için
/// Google Books / Open Library sorgulanır, zaten sahip olunan kitaplar
/// ayıklanır. Sonuç 12 saat boyunca cihazda saklanır; internet yoksa son
/// başarılı liste gösterilmeye devam eder.
class RecommendationService {
  RecommendationService({CatalogService? catalog})
    : _catalog = catalog ?? CatalogService();

  final CatalogService _catalog;

  static const Duration _ttl = Duration(hours: 12);
  static const String _cacheKey = 'recommendations_cache';
  static const int _maxResults = 24;

  /// Türkçe kategori -> Open Library / Google Books konu eşlemesi.
  static const Map<String, String> subjectMap = {
    'Roman': 'fiction',
    'Öykü': 'short stories',
    'Şiir': 'poetry',
    'Polisiye': 'mystery',
    'Bilim Kurgu': 'science fiction',
    'Fantastik': 'fantasy',
    'Tarih': 'history',
    'Felsefe': 'philosophy',
    'Psikoloji': 'psychology',
    'Bilim': 'science',
    'Kişisel Gelişim': 'self-help',
    'Biyografi': 'biography',
    'Çocuk': 'juvenile fiction',
    'Çizgi Roman': 'comics',
    'Deneme': 'essays',
  };

  Future<List<Recommendation>> fetch({bool refresh = false}) async {
    final cached = await _readCache();
    if (!refresh && cached != null && cached.isFresh) return cached.items;

    final profile = await _loadProfile();
    final fresh = await _build(profile);

    if (fresh.isEmpty) {
      // İnternet yoksa ya da kaynaklar boş döndüyse eldeki listeyi koru.
      return cached?.items ?? const [];
    }
    await _writeCache(fresh);
    return fresh;
  }

  // ---------------------------------------------------------------------------

  Future<List<_ProfileBook>> _loadProfile() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query(
      'books',
      columns: ['title', 'author', 'category', 'rating', 'is_finished'],
    );
    return rows
        .map(
          (row) => _ProfileBook(
            title: row['title'] as String? ?? '',
            author: (row['author'] as String? ?? '').trim(),
            category: (row['category'] as String? ?? '').trim(),
            rating: row['rating'] as int?,
            finished: (row['is_finished'] as int? ?? 0) == 1,
          ),
        )
        .toList();
  }

  Future<List<Recommendation>> _build(List<_ProfileBook> books) async {
    if (books.isEmpty) return const [];

    final owned = <String>{};
    final authorWeight = <String, double>{};
    final categoryWeight = <String, double>{};

    for (final book in books) {
      owned.add(_normalizeTitle(book.title));

      // Bitirilen ve yüksek puanlı kitaplar zevki daha çok temsil eder.
      var weight = 1.0;
      if (book.finished) weight = 2.5;
      final rating = book.rating;
      if (rating != null) {
        weight = rating / 20.0; // 0..5
        if (rating >= 80) weight += 2.5;
      }
      if (book.author.isNotEmpty) {
        authorWeight[book.author] = (authorWeight[book.author] ?? 0) + weight;
      }
      if (book.category.isNotEmpty) {
        categoryWeight[book.category] =
            (categoryWeight[book.category] ?? 0) + weight;
      }
    }

    final recommendations = <Recommendation>[];
    final seen = <String>{};

    void addAll(List<CatalogBook> candidates, String reason, int limit) {
      var added = 0;
      for (final candidate in candidates) {
        final title = candidate.title.trim();
        final key = _normalizeTitle(title);
        if (key.isEmpty || owned.contains(key) || !seen.add(key)) continue;
        recommendations.add(
          Recommendation(
            title: title,
            reason: reason,
            author: candidate.author,
            coverUrl: candidate.coverUrl,
            totalPages: candidate.totalPages,
          ),
        );
        if (++added >= limit) break;
      }
    }

    // 1) Sevilen yazarlardan başka kitaplar
    for (final author in _topKeys(authorWeight, 4)) {
      final found = await _catalog.searchByQuery('inauthor:"$author"');
      addAll(found, '$author okuduğun için', 4);
    }

    // 2) Sevilen türlerden öne çıkan kitaplar
    for (final category in _topKeys(categoryWeight, 2)) {
      final subject = subjectMap[category];
      if (subject == null) continue;
      final found = await _catalog.searchByQuery('subject:"$subject"');
      addAll(found, '$category sevdiğin için', 4);
    }

    if (recommendations.length > _maxResults) {
      return recommendations.sublist(0, _maxResults);
    }
    return recommendations;
  }

  // ---------------------------------------------------------------------------
  // Önbellek
  // ---------------------------------------------------------------------------

  Future<_CachedRecommendations?> _readCache() async {
    final raw = await SettingsStore.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final at = DateTime.tryParse(decoded['at']?.toString() ?? '');
      final items = decoded['items'];
      if (at == null || items is! List) return null;
      return _CachedRecommendations(
        at: at,
        items: items
            .whereType<Map<String, dynamic>>()
            .map(Recommendation.fromJson)
            .where((r) => r.title.isNotEmpty)
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(List<Recommendation> items) async {
    final payload = jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'items': items
          .map(
            (r) => {
              'title': r.title,
              'reason': r.reason,
              'author': r.author,
              'cover_url': r.coverUrl,
              'total_pages': r.totalPages,
            },
          )
          .toList(),
    });
    await SettingsStore.setString(_cacheKey, payload);
  }

  static List<String> _topKeys(Map<String, double> weights, int count) {
    final entries = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(count).map((e) => e.key).toList();
  }

  /// Karşılaştırma için başlığı sadeleştirir (harf ve rakam dışını atar).
  static String _normalizeTitle(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
}

class _ProfileBook {
  const _ProfileBook({
    required this.title,
    required this.author,
    required this.category,
    required this.rating,
    required this.finished,
  });

  final String title;
  final String author;
  final String category;
  final int? rating;
  final bool finished;
}

class _CachedRecommendations {
  const _CachedRecommendations({required this.at, required this.items});

  final DateTime at;
  final List<Recommendation> items;

  bool get isFresh =>
      items.isNotEmpty &&
      DateTime.now().difference(at) < RecommendationService._ttl;
}
