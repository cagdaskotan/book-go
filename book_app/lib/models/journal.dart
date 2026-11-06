import 'dart:convert';

/// Sayfa metni üzerinde fosforlu kalemle işaretlenmiş bir bölüm (alıntı).
class Highlight {
  Highlight({
    required this.id,
    required this.start,
    required this.end,
    this.colorIndex = 0,
    this.note = '',
  });

  final String id;
  int start; // metindeki başlangıç karakter indeksi
  int end; // bitiş (hariç)
  int colorIndex;
  String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    's': start,
    'e': end,
    'c': colorIndex,
    'n': note,
  };

  factory Highlight.fromJson(Map<String, dynamic> j) {
    int n(dynamic v, int def) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? def;
    return Highlight(
      id: '${j['id']}',
      start: n(j['s'], 0),
      end: n(j['e'], 0),
      colorIndex: n(j['c'], 0),
      note: j['n']?.toString() ?? '',
    );
  }
}

/// Bir kitaba ait, fotoğraflanıp OCR ile metni çıkarılmış bir sayfa.
/// Metin uygulama içinde kitap sayfası gibi gösterilir; üzerine fosforlu
/// kalemle işaretler (alıntılar) konur.
class JournalPage {
  JournalPage({
    required this.id,
    required this.bookId,
    required this.imagePath,
    required this.text,
    required this.createdAt,
    List<Highlight>? highlights,
  }) : highlights = highlights ?? [];

  final String id;
  final int bookId;
  String imagePath; // kaynak fotoğrafın yerel yolu (referans/yeniden tara)
  String text; // OCR metni
  final int createdAt;
  List<Highlight> highlights;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'image': imagePath,
    'text': text,
    'createdAt': createdAt,
    'hl': highlights.map((h) => h.toJson()).toList(),
  };

  factory JournalPage.fromJson(Map<String, dynamic> j) {
    final raw = j['hl'];
    return JournalPage(
      id: '${j['id']}',
      bookId: (j['bookId'] is num) ? (j['bookId'] as num).toInt() : 0,
      imagePath: j['image']?.toString() ?? '',
      text: j['text']?.toString() ?? '',
      createdAt: (j['createdAt'] is num) ? (j['createdAt'] as num).toInt() : 0,
      highlights: raw is List
          ? raw.whereType<Map<String, dynamic>>().map(Highlight.fromJson).toList()
          : <Highlight>[],
    );
  }

  static List<JournalPage> decodeList(String s) {
    final data = jsonDecode(s);
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(JournalPage.fromJson)
        .toList();
  }

  static String encodeList(List<JournalPage> pages) =>
      jsonEncode(pages.map((p) => p.toJson()).toList());
}
