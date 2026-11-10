import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Cihaz-içi (ücretsiz, çevrimdışı) metin tanıma.
class OcrService {
  /// Fotoğraftaki tüm yazıyı düz metin olarak döndürür (anı defteri kullanır).
  static Future<String> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  /// Yazıyı satır satır, konum ve boyutuyla birlikte döndürür.
  ///
  /// Kapak taraması için gerekli: kapakta hangi yazının başlık olduğunu
  /// anlamanın en güvenilir yolu punto — en büyük yazı başlıktır. Düz metin
  /// bu bilgiyi kaybediyor.
  static Future<List<ScannedLine>> recognizeLines(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final lines = <ScannedLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          lines.add(
            ScannedLine(
              text: text,
              height: line.boundingBox.height,
              width: line.boundingBox.width,
              top: line.boundingBox.top,
            ),
          );
        }
      }
      return lines;
    } finally {
      await recognizer.close();
    }
  }
}

/// Fotoğrafta tanınan tek bir yazı satırı.
class ScannedLine {
  const ScannedLine({
    required this.text,
    required this.height,
    required this.width,
    required this.top,
  });

  final String text;

  /// Satırın piksel yüksekliği — punto yerine geçer.
  final double height;

  final double width;

  /// Üst kenardan uzaklık; kapakta başlık genelde üst üçte ikide durur.
  final double top;
}
