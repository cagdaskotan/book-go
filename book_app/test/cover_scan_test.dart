import 'package:book_app/services/cover_scan_service.dart';
import 'package:book_app/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kapak taramasının doğruluğu tamamen bu ayrıştırmaya bağlı: OCR metni
/// veriyor, hangi satırın başlık hangisinin yazar olduğunu burası karar
/// veriyor. Gerçek kapaklardan alınmış yerleşimlerle sınanıyor.
void main() {
  ScannedLine line(String text, double height, double top) =>
      ScannedLine(text: text, height: height, width: 100, top: top);

  group('başlık tahmini', () {
    test('en büyük yazı başlık sayılır', () {
      final result = CoverScanService.parseLines([
        line('Sabahattin Ali', 20, 40),
        line('KÜRK MANTOLU MADONNA', 48, 120),
        line('Yapı Kredi Yayınları', 12, 400),
      ]);
      expect(result.title, 'KÜRK MANTOLU MADONNA');
      expect(result.author, 'Sabahattin Ali');
    });

    test('iki satıra bölünmüş başlık birleştirilir', () {
      // Kapaklarda uzun başlıklar sık sık alt alta yazılır.
      final result = CoverScanService.parseLines([
        line('KÜRK MANTOLU', 46, 100),
        line('MADONNA', 44, 150),
        line('Sabahattin Ali', 18, 240),
      ]);
      expect(result.title, 'KÜRK MANTOLU MADONNA');
      expect(result.author, 'Sabahattin Ali');
    });

    test('uzak duran benzer puntolu satır başlığa karışmaz', () {
      final result = CoverScanService.parseLines([
        line('TUTUNAMAYANLAR', 40, 90),
        line('OĞUZ ATAY', 38, 800), // kapağın en altında, ayrı öbek
      ]);
      expect(result.title, 'TUTUNAMAYANLAR');
    });
  });

  group('gürültü ayıklama', () {
    test('tür ve yayınevi satırları başlık olamaz', () {
      final result = CoverScanService.parseLines([
        line('ROMAN', 50, 30), // en büyük ama künye değil
        line('Saatleri Ayarlama Enstitüsü', 34, 120),
        line('Ahmet Hamdi Tanpınar', 16, 300),
      ]);
      expect(result.title, 'Saatleri Ayarlama Enstitüsü');
      expect(result.author, 'Ahmet Hamdi Tanpınar');
    });

    test('ISBN ve fiyat gibi sayı satırları elenir', () {
      final result = CoverScanService.parseLines([
        line('9789754700107', 30, 500),
        line('149,90 TL', 24, 540),
        line('İnce Memed', 44, 100),
        line('Yaşar Kemal', 20, 200),
      ]);
      expect(result.title, 'İnce Memed');
      expect(result.author, 'Yaşar Kemal');
      expect(result.lines, isNot(contains('9789754700107')));
    });

    test('tanıtım cümlesi yazar sanılmaz', () {
      final result = CoverScanService.parseLines([
        line('ÇALIKUŞU', 46, 100),
        line('Türk edebiyatının en sevilen romanlarından biri', 20, 300),
        line('Reşat Nuri Güntekin', 18, 360),
      ]);
      expect(result.title, 'ÇALIKUŞU');
      expect(result.author, 'Reşat Nuri Güntekin');
    });
  });

  group('yazar ipuçları', () {
    test('"Yazan:" öneki temizlenir', () {
      final result = CoverScanService.parseLines([
        line('BEYAZ GEMİ', 44, 100),
        line('Yazan: Cengiz Aytmatov', 20, 220),
      ]);
      expect(result.author, 'Cengiz Aytmatov');
    });
  });

  group('sınır durumlar', () {
    test('hiç yazı okunamazsa boş sonuç', () {
      final result = CoverScanService.parseLines(const []);
      expect(result.isEmpty, isTrue);
      expect(result.title, isNull);
      expect(result.query, '');
    });

    test('yalnızca gürültü varsa künye çıkmaz', () {
      final result = CoverScanService.parseLines([
        line('9789754700107', 30, 10),
        line('ROMAN', 28, 60),
      ]);
      expect(result.title, isNull);
    });

    test('tek satır varsa başlık sayılır, yazar boş kalır', () {
      final result = CoverScanService.parseLines([
        line('Körlük', 40, 100),
      ]);
      expect(result.title, 'Körlük');
      expect(result.author, isNull);
    });

    test('arama metni başlık ve yazarı birleştirir', () {
      final result = CoverScanService.parseLines([
        line('Sinekli Bakkal', 40, 100),
        line('Halide Edib Adıvar', 18, 200),
      ]);
      expect(result.query, 'Sinekli Bakkal Halide Edib Adıvar');
    });

    test('fotoğraf yolu sonuçta taşınır', () {
      final result = CoverScanService.parseLines(
        [line('Kitap', 30, 10)],
        imagePath: '/tmp/kapak.jpg',
      );
      // Künye bulunamasa bile bu fotoğraf kapak olarak kullanılabilmeli.
      expect(result.imagePath, '/tmp/kapak.jpg');
    });
  });
}
