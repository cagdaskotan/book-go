import 'ocr_service.dart';
import '../utils/turkish.dart';

/// Kapak fotoğrafından okunan künye tahmini.
class CoverScanResult {
  const CoverScanResult({
    required this.title,
    required this.author,
    required this.lines,
    this.imagePath,
  });

  /// En olası kitap adı. Hiçbir aday bulunamazsa null.
  final String? title;

  /// En olası yazar adı. Emin olunamazsa null.
  final String? author;

  /// Kapakta okunan tüm anlamlı satırlar (kullanıcıya "bunu mu demek
  /// istedin" diye göstermek ve elle düzeltmesi için).
  final List<String> lines;

  /// Çekilen fotoğrafın yolu — künye bulunamasa bile kapak olarak kullanılır.
  final String? imagePath;

  bool get isEmpty => title == null && author == null;

  /// Katalogda aratılacak metin.
  String get query {
    final parts = [
      if (title != null) title!,
      if (author != null) author!,
    ];
    return parts.join(' ').trim();
  }
}

/// Kitap kapağının fotoğrafından künye çıkarır.
///
/// Barkodu kataloglarda bulunmayan Türkçe baskılar için ikinci bir yol:
/// kapaktaki yazıyı okuyup başlık ve yazarı tahmin eder, sonra katalogda
/// arar. Bulunamazsa bile kullanıcı boş forma düşmez — alanlar okunan
/// metinle dolar ve çekilen fotoğraf doğrudan kapak olur.
///
/// Tamamen cihazda çalışır: OCR zaten anı defteri için kurulu olan ML Kit,
/// arama ise mevcut katalog servisi. Yeni bağımlılık ya da ücret yok.
class CoverScanService {
  CoverScanService._();

  /// Kapakta sık görülen ama künyeye ait olmayan kelimeler.
  ///
  /// Bunlar başlık sanılırsa arama tamamen yanlış yere gidiyor: "ROMAN"
  /// yazan her kitabı birbirine karıştırırdık.
  static const Set<String> _noiseWords = {
    'roman',
    'oyku',
    'oykuler',
    'siir',
    'deneme',
    'anlati',
    'cevirmen',
    'ceviren',
    'turkcesi',
    'yayinlari',
    'yayincilik',
    'yayinevi',
    'kitap',
    'kitabevi',
    'basim',
    'baski',
    'cilt',
    'bestseller',
    'cok satan',
    'yeni',
    'nobel',
    'odul',
    'odullu',
    'serisi',
    'seri',
  };

  /// Yazar satırında sık görülen önekler.
  static const Set<String> _authorHints = {'yazan', 'author'};

  /// Fotoğraf çek, oku, künyeyi tahmin et.
  ///
  /// [imagePath] dışarıdan verilebilir (test ve galeriden seçim için).
  static Future<CoverScanResult> scanImage(String imagePath) async {
    final lines = await OcrService.recognizeLines(imagePath);
    return parseLines(lines, imagePath: imagePath);
  }

  /// OCR satırlarından künye çıkarır.
  ///
  /// Dışarıya açık ve saf: fotoğraf çekmeden, OCR çalıştırmadan test
  /// edilebilsin diye. Kapak tahmininin doğruluğu tamamen buraya bağlı.
  static CoverScanResult parseLines(
    List<ScannedLine> lines, {
    String? imagePath,
  }) {
    final candidates = lines.where(_isMeaningful).toList();
    if (candidates.isEmpty) {
      return CoverScanResult(
        title: null,
        author: null,
        lines: const [],
        imagePath: imagePath,
      );
    }

    // Punto büyükten küçüğe: kapakta en büyük yazı başlıktır.
    final byHeight = [...candidates]
      ..sort((a, b) => b.height.compareTo(a.height));

    final biggest = byHeight.first;

    // Başlık birden fazla satıra bölünmüş olabilir ("KÜRK MANTOLU" /
    // "MADONNA"). Benzer puntodaki komşu satırları birleştiriyoruz.
    final titleParts = <ScannedLine>[biggest];
    for (final line in candidates) {
      if (identical(line, biggest)) continue;
      final sameSize = (line.height / biggest.height) >= .72;
      final nearby = (line.top - biggest.top).abs() < biggest.height * 2.6;
      if (sameSize && nearby) titleParts.add(line);
    }
    titleParts.sort((a, b) => a.top.compareTo(b.top));
    final title = _clean(titleParts.map((l) => l.text).join(' '));

    // Yazar: başlıktan küçük ama kapaktaki en belirgin ikinci yazı.
    final author = _findAuthor(byHeight, titleParts);

    return CoverScanResult(
      title: title.isEmpty ? null : title,
      author: author,
      lines: candidates.map((l) => l.text).toList(),
      imagePath: imagePath,
    );
  }

  static String? _findAuthor(
    List<ScannedLine> byHeight,
    List<ScannedLine> titleParts,
  ) {
    for (final line in byHeight) {
      if (titleParts.any((t) => identical(t, line))) continue;

      final text = _clean(line.text);
      if (text.isEmpty) continue;

      // "Yazan: Sabahattin Ali" gibi satırlardan adı ayıkla.
      final withoutHint = _stripAuthorHint(text);
      final words = withoutHint.split(RegExp(r'\s+'));

      // Yazar adı makul uzunlukta olur; uzun cümleler tanıtım metnidir.
      if (words.length > 4 || withoutHint.length < 3) continue;
      return withoutHint;
    }
    return null;
  }

  static String _stripAuthorHint(String text) {
    final folded = foldTurkish(text);
    for (final hint in _authorHints) {
      if (folded.startsWith(hint)) {
        final cut = text.substring(hint.length);
        return cut.replaceFirst(RegExp(r'^[\s:.-]+'), '').trim();
      }
    }
    return text;
  }

  /// Satır künyeye ait olabilir mi?
  static bool _isMeaningful(ScannedLine line) {
    final text = _clean(line.text);
    if (text.length < 2) return false;

    // Çoğunluğu rakam/sembol olan satırlar (ISBN, fiyat, barkod) elenir.
    final letters = text.runes.where((r) {
      final c = String.fromCharCode(r);
      return RegExp(r'[\p{L}]', unicode: true).hasMatch(c);
    }).length;
    if (letters < text.length * .5) return false;

    final folded = foldTurkish(text);
    for (final noise in _noiseWords) {
      // Satır tamamen gürültü kelimesiyse ele; içinde geçiyorsa bırak
      // ("Roman Kahramanları" gerçek bir başlık olabilir).
      if (folded == noise) return false;
    }
    return true;
  }

  static String _clean(String text) => text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '')
      .trim();
}
