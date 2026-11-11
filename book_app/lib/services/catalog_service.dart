import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/catalog_book.dart';
import 'api_exception.dart';
import 'google_books_config.dart';

/// Kitap künyesi arama (barkod ve başlık) — doğrudan Google Books ve
/// Open Library'nin herkese açık uçlarına gider.
///
/// Burası uygulamanın internete ihtiyaç duyduğu tek yer; o da yalnızca yeni
/// kitap eklerken künye doldurmak için. Kitaplığın tamamı cihazda durduğundan
/// bu servisler erişilemese bile uygulama çalışmaya devam eder, sadece
/// bilgileri elle girmek gerekir.
class CatalogService {
  CatalogService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);

  // ---------------------------------------------------------------------------
  // BARKOD (ISBN)
  // ---------------------------------------------------------------------------

  /// Barkodu önce Google Books'ta (Türkçe baskı öncelikli), bulunamazsa
  /// Open Library'de arar.
  Future<CatalogBook> lookupISBN(String rawISBN) async {
    final isbn = rawISBN.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{9}[\dXx]$|^\d{13}$').hasMatch(isbn)) {
      throw const ApiException(400, 'Geçersiz barkod.');
    }

    var reachedSource = false;

    try {
      final book = await _lookupGoogleBooks(isbn);
      reachedSource = true;
      if (book != null) return book;
    } on ApiException {
      rethrow;
    } catch (_) {
      // sıradaki kaynağı dene
    }

    try {
      final book = await _lookupOpenLibrary(isbn);
      reachedSource = true;
      if (book != null) return book;
    } on ApiException {
      rethrow;
    } catch (_) {
      // aşağıda uygun hatayı üretiyoruz
    }

    if (!reachedSource) {
      throw const ApiException(
        0,
        'Kitap bilgisi servisine ulaşılamadı. Bilgileri elle girebilirsin.',
      );
    }
    throw const ApiException(404, 'Bu barkoda ait kitap bilgisi bulunamadı.');
  }

  Future<CatalogBook?> _lookupGoogleBooks(String isbn) async {
    final params = <String, String>{
      'q': 'isbn:$isbn',
      'maxResults': '5',
      'langRestrict': 'tr',
    };
    if (googleBooksApiKey.isNotEmpty) params['key'] = googleBooksApiKey;

    final decoded = await _getJson(
      Uri.https('www.googleapis.com', '/books/v1/volumes', params),
    );
    if (decoded is! Map<String, dynamic>) return null;
    final items = decoded['items'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final info = first['volumeInfo'];
    if (info is! Map<String, dynamic>) return null;

    final title = _text(info['title']);
    if (title == null) return null;

    final images = info['imageLinks'];
    String? cover;
    if (images is Map) {
      cover = _text(images['large']) ?? _text(images['thumbnail']);
      cover = cover?.replaceFirst('http://', 'https://');
    }

    return CatalogBook(
      isbn: isbn,
      title: title,
      totalPages: _int(info['pageCount']),
      source: 'google_books',
      author: _latinize(_firstOfList(info['authors'])),
      coverUrl: cover,
      category: _firstOfList(info['categories']),
      publisher: _text(info['publisher']),
    );
  }

  Future<CatalogBook?> _lookupOpenLibrary(String isbn) async {
    final key = 'ISBN:$isbn';
    final decoded = await _getJson(
      Uri.https('openlibrary.org', '/api/books', {
        'bibkeys': key,
        'jscmd': 'data',
        'format': 'json',
      }),
    );
    if (decoded is! Map<String, dynamic>) return null;
    final info = decoded[key];
    if (info is! Map<String, dynamic>) return null;

    final title = _text(info['title']);
    if (title == null) return null;

    final authors = _namesOf(
      info['authors'],
    ).map(_latinize).whereType<String>().toList();
    final coverMap = info['cover'];
    final cover =
        (coverMap is Map ? _text(coverMap['large']) : null) ??
        'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg';

    return CatalogBook(
      isbn: isbn,
      title: title,
      totalPages: _int(info['number_of_pages']),
      source: 'open_library',
      author: authors.isEmpty ? null : authors.join(', '),
      coverUrl: cover,
      category: _namesOf(info['subjects']).firstOrNull,
      publisher: _namesOf(info['publishers']).firstOrNull,
    );
  }

  // ---------------------------------------------------------------------------
  // BAŞLIKLA ARAMA
  // ---------------------------------------------------------------------------

  /// Başlığa göre arar: Google Books ve Open Library sonuçlarını birleştirip
  /// Türkçe baskıları öne alacak şekilde sıralar.
  Future<List<CatalogBook>> searchByTitle(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final ql = q.toLowerCase();

    ApiException? openLibraryError;
    List<(double, CatalogBook)> google = const [];
    List<(double, CatalogBook)> openlib = const [];

    await Future.wait([
      () async {
        try {
          google = await _searchGoogleBooks(q, ql);
        } catch (_) {
          google = const []; // Google sessizce atlanır
        }
      }(),
      () async {
        try {
          openlib = await _searchOpenLibrary(q, ql);
        } on ApiException catch (e) {
          openLibraryError = e;
        } catch (_) {
          openLibraryError = const ApiException(
            0,
            'Arama servisine bağlanılamadı.',
          );
        }
      }(),
    ]);

    if (google.isEmpty && openlib.isEmpty) {
      final error = openLibraryError;
      if (error != null) throw error;
      return const [];
    }

    // Birleştir + tekilleştir (yüksek skor kazanır).
    final byKey = <String, (double, CatalogBook)>{};
    for (final entry in [...google, ...openlib]) {
      final key = _dedupKey(entry.$2);
      final existing = byKey[key];
      if (existing == null || entry.$1 > existing.$1) byKey[key] = entry;
    }

    final merged = byKey.values.toList()..sort((a, b) => b.$1.compareTo(a.$1));
    return merged.map((e) => e.$2).toList();
  }

  /// Serbest sorgu (örn. `inauthor:"Sabahattin Ali"` ya da `subject:"fiction"`).
  /// Kaynağın kendi alaka sırası korunur; öneri motoru kullanır.
  Future<List<CatalogBook>> searchByQuery(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final google = await _searchGoogleBooks(q, q.toLowerCase());
      if (google.isNotEmpty) {
        return google.map((e) => e.$2).take(limit).toList();
      }
    } catch (_) {
      // Open Library'ye düş
    }
    try {
      final openlib = await _searchOpenLibrary(q, q.toLowerCase());
      return openlib.map((e) => e.$2).take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  // ----------------------- Google Books -----------------------
  Future<List<(double, CatalogBook)>> _searchGoogleBooks(
    String q,
    String ql,
  ) async {
    final params = <String, String>{
      'q': q,
      'maxResults': '20',
      'printType': 'books',
      'country': 'TR',
    };
    if (googleBooksApiKey.isNotEmpty) params['key'] = googleBooksApiKey;

    final decoded = await _getJson(
      Uri.https('www.googleapis.com', '/books/v1/volumes', params),
    );
    if (decoded is! Map<String, dynamic>) return const [];
    final items = decoded['items'];
    if (items is! List) return const [];

    final out = <(double, CatalogBook)>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is! Map<String, dynamic>) continue;
      final v = it['volumeInfo'];
      if (v is! Map<String, dynamic>) continue;
      final title = _text(v['title']);
      if (title == null) continue;

      final author = _latinize(_firstOfList(v['authors']));
      final totalPages = _int(v['pageCount']);
      final publisher = _text(v['publisher']);
      final lang = _text(v['language'])?.toLowerCase();

      String? cover;
      final img = v['imageLinks'];
      if (img is Map) {
        cover = _text(img['thumbnail']) ?? _text(img['smallThumbnail']);
        cover = cover?.replaceFirst('http://', 'https://');
      }

      var isbn = '';
      final ids = v['industryIdentifiers'];
      if (ids is List) {
        for (final id in ids) {
          if (id is Map &&
              (id['type'] == 'ISBN_13' || id['type'] == 'ISBN_10')) {
            isbn = id['identifier'].toString();
            break;
          }
        }
      }

      // Skor: başlık katmanı + kaynağın alaka sırası + sinyaller.
      double s = _titleScore(title, ql);
      s += (20 - i) * 8; // Google'ın kendi alaka sırası
      s += 900; // Google kaynağı tercih (Türkçe başlıklar)
      if (lang == 'tr') {
        s += 1200;
      } else if (lang == 'en') {
        s += 300;
      }
      if (cover != null && cover.isNotEmpty) s += 400;
      if (totalPages > 0) s += 150;
      if (author != null && author.isNotEmpty) s += 100;

      out.add((
        s,
        CatalogBook(
          isbn: isbn,
          title: title,
          totalPages: totalPages,
          source: 'google',
          author: author,
          coverUrl: cover,
          publisher: publisher,
        ),
      ));
    }
    return out;
  }

  // ----------------------- Open Library -----------------------
  Future<List<(double, CatalogBook)>> _searchOpenLibrary(
    String q,
    String ql,
  ) async {
    final decoded = await _getJson(
      Uri.https('openlibrary.org', '/search.json', {
        'q': q,
        'limit': '60',
        'fields':
            'title,author_name,cover_i,number_of_pages_median,first_publish_year,'
            'edition_count,ratings_count,publisher,language,isbn',
      }),
      onError: const ApiException(0, 'Arama yapılamadı.'),
    );
    if (decoded is! Map<String, dynamic>) return const [];
    final docs = decoded['docs'];
    if (docs is! List) return const [];

    final seen = <String>{};
    final out = <(double, CatalogBook)>[];

    for (final doc in docs) {
      if (doc is! Map<String, dynamic>) continue;
      final title = _text(doc['title']);
      if (title == null) continue;

      final author = _latinize(_firstOfList(doc['author_name']));

      final key = '${title.toLowerCase()}|${author?.toLowerCase() ?? ''}';
      if (!seen.add(key)) continue;

      final coverId = doc['cover_i'];
      final hasCover = coverId is num;
      final coverUrl = hasCover
          ? 'https://covers.openlibrary.org/b/id/${coverId.toInt()}-M.jpg'
          : null;
      final totalPages = _int(doc['number_of_pages_median']);
      final isbnList = doc['isbn'];
      final isbn = (isbnList is List && isbnList.isNotEmpty)
          ? isbnList.first.toString()
          : '';
      final publisher = _firstOfList(doc['publisher']);
      final langs = doc['language'];
      final langList = langs is List
          ? langs.map((e) => e.toString()).toList()
          : const <String>[];

      double s = _titleScore(title, ql);
      final editions = (doc['edition_count'] as num?)?.toDouble() ?? 0;
      s += editions.clamp(0, 1500);
      final ratings = (doc['ratings_count'] as num?)?.toDouble() ?? 0;
      s += (ratings * .5).clamp(0, 500);
      if (langList.contains('tur')) {
        s += 1200;
      } else if (langList.contains('eng')) {
        s += 300;
      }
      if (hasCover) s += 400;
      if (totalPages > 0) s += 150;
      if (author != null && author.isNotEmpty) s += 100;

      out.add((
        s,
        CatalogBook(
          isbn: isbn,
          title: title,
          totalPages: totalPages,
          source: 'openlibrary',
          author: author,
          coverUrl: coverUrl,
          publisher: publisher,
        ),
      ));
    }
    return out;
  }

  // ----------------------- HTTP -----------------------
  Future<Object?> _getJson(Uri uri, {ApiException? onError}) async {
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      if (onError != null) throw onError;
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // ----------------------- Skorlama yardımcıları -----------------------
  /// Başlık eşleşme katmanı: tam > baştan > kelime > içinde > yok.
  /// Aralıklar büyük tutulur ki popülerlik sinyalleri katmanı geçemesin.
  static double _titleScore(String title, String ql) {
    final tl = title.toLowerCase();
    if (tl == ql) return 100000;
    if (tl.startsWith(ql)) return 50000;
    if (_wordMatch(tl, ql)) return 20000;
    if (tl.contains(ql)) return 8000;
    return 0;
  }

  static bool _wordMatch(String haystack, String needle) {
    final i = haystack.indexOf(needle);
    if (i < 0) return false;
    final before = i == 0 ? ' ' : haystack[i - 1];
    final afterIdx = i + needle.length;
    final after = afterIdx >= haystack.length ? ' ' : haystack[afterIdx];
    return !_isWordChar(before) && !_isWordChar(after);
  }

  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static bool _isWordChar(String c) => _wordChar.hasMatch(c);

  /// Kaynaklar arası tekilleştirme anahtarı (başlık + ilk yazar adı).
  static String _dedupKey(CatalogBook b) {
    final t = b.title.toLowerCase().replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '',
    );
    final a = (b.author ?? '').toLowerCase().split(RegExp(r'\s+')).first;
    return '$t|$a';
  }

  // ----------------------- Ayrıştırma yardımcıları -----------------------
  static String? _text(Object? value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static String? _firstOfList(Object? value) {
    if (value is List && value.isNotEmpty) return _text(value.first);
    return null;
  }

  /// Open Library'nin `[{name: ...}]` biçimindeki alanlarını düz listeye çevirir.
  static List<String> _namesOf(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e is Map ? _text(e['name']) : _text(e))
        .whereType<String>()
        .toList();
  }

  /// Kiril harfli yazar adlarını okunur hale getirir (Достоевский → Dostoevskiy).
  static String? _latinize(String? value) {
    if (value == null || value.isEmpty) return value;
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_cyrillic[char] ?? char);
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }

  static const Map<String, String> _cyrillic = {
    'А': 'A',
    'Б': 'B',
    'В': 'V',
    'Г': 'G',
    'Д': 'D',
    'Е': 'E',
    'Ё': 'Yo',
    'Ж': 'Zh',
    'З': 'Z',
    'И': 'I',
    'Й': 'Y',
    'К': 'K',
    'Л': 'L',
    'М': 'M',
    'Н': 'N',
    'О': 'O',
    'П': 'P',
    'Р': 'R',
    'С': 'S',
    'Т': 'T',
    'У': 'U',
    'Ф': 'F',
    'Х': 'Kh',
    'Ц': 'Ts',
    'Ч': 'Ch',
    'Ш': 'Sh',
    'Щ': 'Shch',
    'Ъ': '',
    'Ы': 'Y',
    'Ь': '',
    'Э': 'E',
    'Ю': 'Yu',
    'Я': 'Ya',
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ё': 'yo',
    'ж': 'zh',
    'з': 'z',
    'и': 'i',
    'й': 'y',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'kh',
    'ц': 'ts',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'shch',
    'ъ': '',
    'ы': 'y',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
  };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
