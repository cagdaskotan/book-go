import 'ocr_service.dart';
import '../utils/turkish.dart';

/// Raf fotoğrafında tanınan tek bir kitap sırtı.
class SpineCandidate {
  const SpineCandidate({
    required this.text,
    required this.centerX,
    required this.lineCount,
  });

  /// Sırtta okunan metin (başlık ve yazar birlikte olabilir).
  final String text;

  /// Sırtın fotoğraftaki yatay konumu — sonuçları soldan sağa sıralamak
  /// için; kullanıcı listeyi gerçek rafıyla eşleştirebilsin.
  final double centerX;

  /// Kaç satırdan birleşti. Tek satırlık okumalar daha şüphelidir.
  final int lineCount;
}

/// Raf fotoğrafından birden çok kitabı tanır.
///
/// Fikir ürünün kimliğinden geliyor: bu uygulamanın ayırt edici yanı raf,
/// o hâlde kullanıcı **gerçek rafının fotoğrafını çekince dijital rafı
/// dolmalı.** Tek tek barkod okutmak yerine bir kare.
///
/// Yöntem: sırt yazıları dik olduğu için OCR kutuları dar ve uzun çıkar.
/// Her kitap sırtı fotoğrafta dar bir **dikey şerit** kaplar, dolayısıyla
/// satırları yatay konumlarına göre öbeklemek kitapları ayırmaya yetiyor.
/// Model eğitmiyoruz, bulut servisi kullanmıyoruz — her şey cihazda.
class ShelfScanService {
  ShelfScanService._();

  /// Fotoğrafı oku ve sırtları çıkar.
  static Future<List<SpineCandidate>> scanImage(String imagePath) async {
    final lines = await OcrService.recognizeLines(imagePath);
    return parseLines(lines);
  }

  /// OCR satırlarından kitap sırtlarını çıkarır.
  ///
  /// Saf ve testli: raf fotoğrafı çekmeden sınanabilsin diye. Tanımanın
  /// isabeti tamamen buraya bağlı.
  static List<SpineCandidate> parseLines(List<ScannedLine> lines) {
    final usable = lines.where(_isMeaningful).toList();
    if (usable.isEmpty) return const [];

    // Şerit genişliği sabit olamaz: fotoğraf uzaktan da yakından da
    // çekilebilir. Satırların kendi genişliğinden ölçek çıkarıyoruz.
    final widths = usable.map((l) => l.width).toList()..sort();
    final medianWidth = widths[widths.length ~/ 2];
    final tolerance = (medianWidth * 1.1).clamp(18.0, 140.0);

    final sorted = [...usable]
      ..sort((a, b) => a.centerX.compareTo(b.centerX));

    final clusters = <List<ScannedLine>>[];
    for (final line in sorted) {
      final current = clusters.isEmpty ? null : clusters.last;
      if (current == null) {
        clusters.add([line]);
        continue;
      }
      final lastCenter = current.last.centerX;
      if ((line.centerX - lastCenter).abs() <= tolerance) {
        current.add(line);
      } else {
        clusters.add([line]);
      }
    }

    final out = <SpineCandidate>[];
    for (final cluster in clusters) {
      // Sırt üzerinde yazılar yukarıdan aşağıya sıralanır.
      cluster.sort((a, b) => a.top.compareTo(b.top));
      final text = _clean(cluster.map((l) => l.text).join(' '));
      if (text.length < 3) continue;

      // Tek kelimelik okumalar çoğunlukla yayınevi logosu ya da seri adı.
      if (!text.contains(' ') && text.length < 6) continue;

      final centerX =
          cluster.map((l) => l.centerX).reduce((a, b) => a + b) /
          cluster.length;

      out.add(
        SpineCandidate(
          text: text,
          centerX: centerX,
          lineCount: cluster.length,
        ),
      );
    }

    // Soldan sağa: kullanıcı listeyi gerçek rafıyla eşleştirebilsin.
    out.sort((a, b) => a.centerX.compareTo(b.centerX));
    return out;
  }

  /// Raf fotoğrafında künyeye ait olmayan satırlar.
  static const Set<String> _noise = {
    'yayinlari',
    'yayincilik',
    'yayinevi',
    'kitap',
    'kitabevi',
    'yky',
    'can',
    'iletisim',
    'roman',
    'oyku',
    'siir',
    'cilt',
    'basim',
    'seri',
    'serisi',
  };

  static bool _isMeaningful(ScannedLine line) {
    final text = _clean(line.text);
    if (text.length < 2) return false;

    final letters = RegExp(r'[\p{L}]', unicode: true)
        .allMatches(text)
        .length;
    if (letters < text.length * .55) return false;

    final folded = foldTurkish(text);
    if (_noise.contains(folded)) return false;
    return true;
  }

  static String _clean(String text) => text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '')
      .trim();
}
