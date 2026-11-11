import 'ocr_service.dart';
import 'rotated_ocr.dart';
import '../utils/turkish.dart';

/// Raf fotoğrafında tanınan tek bir kitap sırtı.
class SpineCandidate {
  const SpineCandidate({
    required this.text,
    required this.centerX,
    required this.lineCount,
    this.parts = const [],
  });

  /// Sırtta okunan metin (başlık ve yazar birlikte olabilir).
  final String text;

  /// Sırtın fotoğraftaki yatay konumu — sonuçları soldan sağa sıralamak için.
  final double centerX;

  /// Kaç satırdan birleşti.
  final int lineCount;

  /// Sırttaki satırlar ayrı ayrı. Eşleşme puanlamasında yazar satırını
  /// başlık satırından ayırt edebilmek için saklanıyor.
  final List<String> parts;
}

/// Raf fotoğrafından birden çok kitabı tanır.
///
/// Fikir ürünün kimliğinden geliyor: ayırt edici yanımız raf, o hâlde
/// kullanıcı gerçek rafının fotoğrafını çekince dijital rafı dolmalı.
///
/// Gerçek bir raf fotoğrafıyla denendiğinde üç ayrı sorun çıktı ve üçü de
/// burada çözülüyor:
///
/// 1. **Döndürülmüş yazı.** Sırt yazıları dik olduğu için ML Kit onları
///    kötü okuyordu. Artık fotoğraf 90° ve 270° döndürülerek de okunuyor
///    ([RotatedOcr]); döndürülmüş karede sırt yazısı yatay oluyor.
/// 2. **Zincirleme birleşme.** Öbekleme her satırı yalnızca bir öncekiyle
///    kıyaslıyordu, dolayısıyla yan yana duran ince kitaplar peş peşe
///    birbirine yapışıyordu. Artık öbeğin ortalama merkezine bakılıyor.
/// 3. **Yatay yazılar.** Aynı sırtta yazar yatay, başlık dikey yazılabiliyor
///    ("SCOTT SIGLER" üstte yatay, "UYANIŞ" altta dikey). Kutu biçimleri çok
///    farklı olduğu için ayrı öbeklere düşüyor ve yazar kayboluyordu; eşik
///    artık yalnızca dar kutulardan hesaplanıyor.
class ShelfScanService {
  ShelfScanService._();

  /// Fotoğrafı oku ve sırtları çıkar.
  static Future<List<SpineCandidate>> scanImage(String imagePath) async {
    final lines = await RotatedOcr.recognizeAllAngles(imagePath);
    return parseLines(lines);
  }

  /// OCR satırlarından kitap sırtlarını çıkarır.
  ///
  /// Saf ve testli: raf fotoğrafı çekmeden sınanabilsin diye.
  static List<SpineCandidate> parseLines(List<ScannedLine> lines) {
    final usable = lines.where(_isMeaningful).toList();
    if (usable.isEmpty) return const [];

    final tolerance = _clusterTolerance(usable);

    final sorted = [...usable]
      ..sort((a, b) => a.centerX.compareTo(b.centerX));

    final clusters = <List<ScannedLine>>[];
    final centers = <double>[];

    for (final line in sorted) {
      if (clusters.isEmpty) {
        clusters.add([line]);
        centers.add(line.centerX);
        continue;
      }
      // Öbeğin ortalamasıyla kıyasla: son elemanla kıyaslamak zincirleme
      // kaymaya yol açıyor, ince kitaplar tek öbeğe yapışıyordu.
      final mean = centers.last;
      if ((line.centerX - mean).abs() <= tolerance) {
        clusters.last.add(line);
        final c = clusters.last;
        centers[centers.length - 1] =
            c.map((l) => l.centerX).reduce((a, b) => a + b) / c.length;
      } else {
        clusters.add([line]);
        centers.add(line.centerX);
      }
    }

    final out = <SpineCandidate>[];
    for (var i = 0; i < clusters.length; i++) {
      final cluster = clusters[i]..sort((a, b) => a.top.compareTo(b.top));
      final parts = <String>[];
      for (final line in cluster) {
        final text = _clean(line.text);
        if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
      }
      final text = _clean(parts.join(' '));
      if (text.length < 3) continue;
      if (!text.contains(' ') && text.length < 5) continue;

      out.add(
        SpineCandidate(
          text: text,
          centerX: centers[i],
          lineCount: cluster.length,
          parts: parts,
        ),
      );
    }

    out.sort((a, b) => a.centerX.compareTo(b.centerX));
    return out;
  }

  /// Öbek eşiği: kitapların ne kadar yakın sayılacağı.
  ///
  /// Yalnızca **dar** kutulardan hesaplanıyor. Fotoğrafta yatay yazılar
  /// (kapağı dönük kitaplar, yatık yığınlar) çok geniş kutular üretiyor;
  /// onları da hesaba katmak eşiği şişiriyor ve bütün raf tek kitaba
  /// dönüşüyordu.
  static double _clusterTolerance(List<ScannedLine> lines) {
    final narrow = lines.where((l) => l.height >= l.width).toList();
    final source = narrow.length >= 3 ? narrow : lines;
    final widths = source.map((l) => l.width).toList()..sort();
    final median = widths[widths.length ~/ 2];
    return (median * 0.85).clamp(12.0, 90.0);
  }

  /// Raf fotoğrafında künyeye ait olmayan satırlar.
  static const Set<String> _noise = {
    'yayinlari',
    'yayincilik',
    'yayinevi',
    'kitap',
    'kitabevi',
    'yky',
    'iletisim',
    'roman',
    'oyku',
    'siir',
    'cilt',
    'basim',
    'seri',
    'serisi',
    'stage',
    'level',
  };

  static bool _isMeaningful(ScannedLine line) {
    final text = _clean(line.text);
    if (text.length < 2) return false;

    final letters = RegExp(r'[\p{L}]', unicode: true).allMatches(text).length;
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

/// Okunan sırt metniyle katalog sonucunun ne kadar örtüştüğünü ölçer.
///
/// Gerçek denemede katalog "UYANIS" için Kate Chopin'in kitabını döndürdü,
/// oysa raftaki Scott Sigler'ın "Uyanış"ıydı — çünkü ilk sonuç körlemesine
/// alınıyordu. **Yanlış kitap, kitap bulunamamasından kötüdür:** kullanıcı
/// kitaplığına hiç sahip olmadığı bir kitabı ekliyor ve fark etmiyor.
abstract final class SpineMatch {
  /// Bu eşiğin altındaki eşleşmeler "bulunamadı" sayılır.
  static const double minimumScore = .45;

  /// 0–1 arası benzerlik. Sırt metnindeki kelimelerin adayda bulunma oranı.
  static double score({
    required String spineText,
    required String candidateTitle,
    String? candidateAuthor,
  }) {
    final spineTokens = _tokens(spineText);
    if (spineTokens.isEmpty) return 0;

    final titleTokens = _tokens(candidateTitle);
    if (titleTokens.isEmpty) return 0;

    // Başlıktaki kelimelerin kaçı sırtta geçiyor? Yön önemli: sırt metni
    // yazarı da içerdiği için başlıktan uzun olabilir.
    final matchedTitle =
        titleTokens.where((t) => spineTokens.any((s) => _close(s, t))).length;
    var value = matchedTitle / titleTokens.length;

    // Yazar, aynı adlı farklı kitapları ayıran asıl sinyal. Sırt metni
    // genelde yazarı da içerir; dolayısıyla adayın yazarı sırtta hiç
    // geçmiyorsa bu bir **uyarıdır**, sadece "bonus yok" değil.
    //
    // Ödül/ceza ayrımı şart: başlık tam eşleştiğinde puan tavana vuruyor ve
    // yalnızca ödül verilirse yanlış yazarlı aday doğru olanla aynı puanı
    // alıyor. Gerçek denemede "Uyanış" için Kate Chopin tam da böyle seçildi.
    final authorTokens = _tokens(candidateAuthor ?? '');
    if (authorTokens.isNotEmpty) {
      final matchedAuthor = authorTokens
          .where((a) => spineTokens.any((s) => _close(s, a)))
          .length;
      if (matchedAuthor > 0) {
        value = value * .75 + (matchedAuthor / authorTokens.length) * .25;
        value += .15;
      } else {
        // Sırtta yazar hiç geçmiyor: şüpheli ama imkânsız değil (ince
        // kitaplarda yalnızca başlık okunabiliyor), o yüzden eleme değil
        // ağırlık düşürme.
        value *= .6;
      }
    }

    return value.clamp(0.0, 1.0);
  }

  /// Adaylar arasından en iyisini seçer; hiçbiri eşiği geçemezse null.
  static T? best<T>(
    String spineText,
    List<T> candidates, {
    required String Function(T) title,
    required String? Function(T) author,
  }) {
    T? bestItem;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final s = score(
        spineText: spineText,
        candidateTitle: title(candidate),
        candidateAuthor: author(candidate),
      );
      if (s > bestScore) {
        bestScore = s;
        bestItem = candidate;
      }
    }
    return bestScore >= minimumScore ? bestItem : null;
  }

  static List<String> _tokens(String value) => foldTurkish(value)
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toList();

  /// OCR harf hatalarına toleranslı karşılaştırma ("wareross" ≈ "warcross").
  static bool _close(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;
    if ((a.length - b.length).abs() > 2) return false;
    return _editDistance(a, b) <= (a.length > 7 ? 2 : 1);
  }

  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current.add(
          [
            current[j - 1] + 1,
            previous[j] + 1,
            previous[j - 1] + cost,
          ].reduce((x, y) => x < y ? x : y),
        );
      }
      previous = current;
    }
    return previous[b.length];
  }
}
