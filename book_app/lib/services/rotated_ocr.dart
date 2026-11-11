import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'ocr_service.dart';

/// Döndürülmüş metin için çok açılı OCR.
///
/// ML Kit yatay yazıyı iyi okuyor ama **90 derece döndürülmüş yazıda
/// çöküyor** — gerçek raf fotoğrafında "WARCROSS" → "WAREROSS",
/// "DIŞARIDAKİLER" → "SAPOKLEP" oldu. Kitap sırtlarındaki yazı neredeyse
/// her zaman döndürülmüş olduğu için bu, raf taramasının en büyük hata
/// kaynağıydı.
///
/// Çözüm basit ve etkili: fotoğrafı döndürüp OCR'ı tekrar çalıştırıyoruz.
/// Döndürülmüş karede sırt yazıları yatay hale geliyor ve doğru okunuyor.
/// Sonra koordinatları geri çeviriyoruz ki konum bilgisi (öbekleme buna
/// dayanıyor) orijinal fotoğrafa göre doğru kalsın.
class RotatedOcr {
  RotatedOcr._();

  /// Fotoğrafı 0°, 90° ve 270°'de okur, sonuçları orijinal koordinat
  /// düzlemine çevirip birleştirir.
  ///
  /// 180° eklenmiyor: ters duran kitap neredeyse yok ve her ek açı hem
  /// süreyi hem yanlış okuma riskini artırıyor.
  static Future<List<ScannedLine>> recognizeAllAngles(String imagePath) async {
    final original = await OcrService.recognizeLines(imagePath);

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    final width = decoded.width.toDouble();
    final height = decoded.height.toDouble();
    final out = <ScannedLine>[...original];

    for (final angle in [90, 270]) {
      try {
        final rotatedPath = await _writeRotated(decoded, angle);
        final lines = await OcrService.recognizeLines(rotatedPath);
        out.addAll(
          lines.map((l) => _mapBack(l, angle, width, height)),
        );
        try {
          await File(rotatedPath).delete();
        } catch (_) {
          // geçici dosya silinemezse sorun değil
        }
      } catch (_) {
        // Bir açı başarısız olursa diğerleriyle devam et.
      }
    }

    return _dedupe(out);
  }

  static Future<String> _writeRotated(img.Image source, int angle) async {
    final rotated = img.copyRotate(source, angle: angle);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/ocr_rot_${angle}_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(img.encodeJpg(rotated, quality: 92));
    return path;
  }

  /// Döndürülmüş karedeki kutuyu orijinal fotoğraftaki yerine geri taşır.
  ///
  /// [w] ve [h] orijinal görüntünün ölçüleri. 90° döndürmede orijinalin
  /// yüksekliği yeni genişlik oluyor; eksenler yer değiştiriyor.
  static ScannedLine _mapBack(
    ScannedLine line,
    int angle,
    double w,
    double h,
  ) {
    final double left;
    final double top;
    if (angle == 90) {
      // Saat yönünde 90°: yeni (x, y) → orijinal (x: y, y: w - x - genişlik)
      left = line.top;
      top = w - line.left - line.width;
    } else {
      // 270°: diğer yön
      left = h - line.top - line.height;
      top = line.left;
    }

    return ScannedLine(
      text: line.text,
      // Döndürülmüş karede yatay okunan yazı, orijinalde dikeydir:
      // kutunun en ve boyu da yer değiştirir.
      width: line.height,
      height: line.width,
      left: left,
      top: top,
      angle: 90,
    );
  }

  /// Aynı yazı birden çok açıda okunmuş olabilir; en uzun okumayı tutuyoruz.
  ///
  /// Uzunluk iyi bir ölçüt: bozuk okumalar genelde kısalıyor ve harf
  /// kaybediyor ("DIŞARIDAKİLER" → "SAPOKLEP").
  static List<ScannedLine> _dedupe(List<ScannedLine> lines) {
    final kept = <ScannedLine>[];
    for (final line in lines) {
      var replaced = false;
      for (var i = 0; i < kept.length; i++) {
        final other = kept[i];
        if (!_sameArea(line, other)) continue;
        if (line.text.length > other.text.length) kept[i] = line;
        replaced = true;
        break;
      }
      if (!replaced) kept.add(line);
    }
    return kept;
  }

  /// İki kutu kabaca aynı yeri mi gösteriyor?
  static bool _sameArea(ScannedLine a, ScannedLine b) {
    final tolerance = (a.width + b.width) / 2;
    return (a.centerX - b.centerX).abs() < tolerance &&
        (a.top - b.top).abs() < (a.height + b.height) / 2;
  }
}
