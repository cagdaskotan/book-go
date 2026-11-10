import 'package:book_app/services/ocr_service.dart';
import 'package:book_app/services/shelf_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Raf taramasının isabeti tamamen öbeklemeye bağlı: OCR satırları veriyor,
/// hangi satırın hangi kitap sırtına ait olduğuna burası karar veriyor.
/// Dik sırt yazıları dar ve uzun kutular üretir; kitapları yatay konuma
/// göre ayırıyoruz.
void main() {
  /// Dikey sırt yazısı: dar ve uzun kutu.
  ScannedLine spine(String text, double left, double top) => ScannedLine(
    text: text,
    width: 28,
    height: 180,
    left: left,
    top: top,
    angle: 90,
  );

  group('sırt öbekleme', () {
    test('yan yana üç kitap ayrı ayrı tanınır', () {
      final spines = ShelfScanService.parseLines([
        spine('Tutunamayanlar', 20, 40),
        spine('Kürk Mantolu Madonna', 120, 30),
        spine('İnce Memed', 230, 50),
      ]);
      expect(spines, hasLength(3));
      expect(spines[0].text, 'Tutunamayanlar');
      expect(spines[1].text, 'Kürk Mantolu Madonna');
      expect(spines[2].text, 'İnce Memed');
    });

    test('aynı sırttaki başlık ve yazar birleşir', () {
      // Sırtta yazar ve başlık ayrı satırlarda ama aynı dikey şeritte.
      final spines = ShelfScanService.parseLines([
        spine('Oğuz Atay', 50, 40),
        spine('Tutunamayanlar', 54, 260),
      ]);
      expect(spines, hasLength(1));
      expect(spines.single.text, 'Oğuz Atay Tutunamayanlar');
      expect(spines.single.lineCount, 2);
    });

    test('sonuçlar soldan sağa sıralanır', () {
      // Kullanıcı listeyi gerçek rafıyla eşleştirebilmeli.
      final spines = ShelfScanService.parseLines([
        spine('Sağdaki Kitap', 300, 40),
        spine('Soldaki Kitap', 20, 40),
        spine('Ortadaki Kitap', 160, 40),
      ]);
      expect(
        spines.map((s) => s.text).toList(),
        ['Soldaki Kitap', 'Ortadaki Kitap', 'Sağdaki Kitap'],
      );
    });

    test('yakın duran ince kitaplar birbirine karışmaz', () {
      final spines = ShelfScanService.parseLines([
        spine('Birinci Kitap', 100, 40),
        spine('İkinci Kitap', 145, 40),
      ]);
      expect(spines, hasLength(2));
    });
  });

  group('gürültü ayıklama', () {
    test('yayınevi adları sırt sayılmaz', () {
      final spines = ShelfScanService.parseLines([
        spine('Tutunamayanlar', 40, 40),
        spine('İletişim', 300, 400),
        spine('Yayınları', 340, 400),
      ]);
      expect(spines.map((s) => s.text), contains('Tutunamayanlar'));
      expect(spines.map((s) => s.text), isNot(contains('İletişim')));
    });

    test('sayı ve sembol yığınları elenir', () {
      final spines = ShelfScanService.parseLines([
        spine('9789754700107', 40, 40),
        spine('Saatleri Ayarlama Enstitüsü', 200, 40),
      ]);
      expect(spines, hasLength(1));
      expect(spines.single.text, 'Saatleri Ayarlama Enstitüsü');
    });

    test('tek kelimelik kısa okumalar atılır', () {
      final spines = ShelfScanService.parseLines([
        spine('ABC', 40, 40),
        spine('Körlük Saramago', 200, 40),
      ]);
      expect(spines, hasLength(1));
      expect(spines.single.text, 'Körlük Saramago');
    });
  });

  group('sınır durumlar', () {
    test('boş fotoğraf boş liste döndürür', () {
      expect(ShelfScanService.parseLines(const []), isEmpty);
    });

    test('hiç anlamlı yazı yoksa sonuç çıkmaz', () {
      final spines = ShelfScanService.parseLines([
        spine('123456', 40, 40),
        spine('!!!', 120, 40),
      ]);
      expect(spines, isEmpty);
    });

    test('tek kitaplık raf da çalışır', () {
      final spines = ShelfScanService.parseLines([
        spine('Beyaz Gemi', 100, 40),
      ]);
      expect(spines, hasLength(1));
    });

    test('yakından çekilmiş fotoğrafta geniş kutular ayrışır', () {
      // Yakın çekimde kutular büyür; eşik sabit olsaydı her şey tek
      // kitapta birleşirdi. Ölçek satır genişliğinden türetiliyor.
      ScannedLine wide(String text, double left) => ScannedLine(
        text: text,
        width: 110,
        height: 520,
        left: left,
        top: 20,
        angle: 90,
      );
      final spines = ShelfScanService.parseLines([
        wide('Birinci Kitap', 40),
        wide('İkinci Kitap', 400),
      ]);
      expect(spines, hasLength(2));
    });
  });
}
