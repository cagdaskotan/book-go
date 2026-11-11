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
      expect(spines.map((s) => s.text).toList(), [
        'Soldaki Kitap',
        'Ortadaki Kitap',
        'Sağdaki Kitap',
      ]);
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

  group('eşleşme puanlaması', () {
    // Gerçek denemeden: "UYANIS" için katalog Kate Chopin'in kitabını
    // döndürdü, oysa raftaki Scott Sigler'ın "Uyanış"ıydı. İlk sonucu
    // körlemesine almak kullanıcının kitaplığına yanlış kitap ekliyordu.
    test('yazar sırtta geçiyorsa puan yükselir', () {
      final dogru = SpineMatch.score(
        spineText: 'SCOTT SIGLER UYANIŞ',
        candidateTitle: 'Uyanış',
        candidateAuthor: 'Scott Sigler',
      );
      final yanlis = SpineMatch.score(
        spineText: 'SCOTT SIGLER UYANIŞ',
        candidateTitle: 'Uyanış',
        candidateAuthor: 'Kate Chopin',
      );
      expect(dogru, greaterThan(yanlis));
    });

    test('OCR harf hatasına toleranslı', () {
      // Gerçek okuma: "WARCROSS" -> "WAREROSS"
      final score = SpineMatch.score(
        spineText: 'MARIE LU WAREROSS',
        candidateTitle: 'Warcross',
        candidateAuthor: 'Marie Lu',
      );
      expect(score, greaterThanOrEqualTo(SpineMatch.minimumScore));
    });

    test('alakasız kitap eşiği geçemez', () {
      final score = SpineMatch.score(
        spineText: 'KURTULUŞ SCOTT SIGLER',
        candidateTitle: 'Sefiller',
        candidateAuthor: 'Victor Hugo',
      );
      expect(score, lessThan(SpineMatch.minimumScore));
    });

    test('hiçbiri eşiği geçemezse null döner', () {
      final chosen = SpineMatch.best<String>(
        'ALAKASIZ SIRT METNI',
        ['Sefiller', 'Suç ve Ceza'],
        title: (t) => t,
        author: (_) => null,
      );
      // Yanlış kitap eklemektense hiç eklememek doğru.
      expect(chosen, isNull);
    });

    test('doğru aday seçilir', () {
      final chosen = SpineMatch.best<String>(
        'SCOTT SIGLER KURTULUŞ',
        ['Sefiller', 'Kurtuluş', 'Körlük'],
        title: (t) => t,
        author: (_) => null,
      );
      expect(chosen, 'Kurtuluş');
    });

    test('boş metin eşleşmez', () {
      expect(SpineMatch.score(spineText: '', candidateTitle: 'Kitap'), 0);
    });
  });

  /// Yatık duran kitap: yazı düz okunur, kutu geniş ve basık.
  ///
  /// Raf fotoğraflarının çoğunda rafın üstünde böyle bir yığın oluyor.
  /// Bütün yığın aynı yatay aralıkta durduğu için "dar dikey şerit"
  /// mantığına girmiyor; kitapları ayıran şey dikey konum.
  ScannedLine flat(
    String text,
    double top, {
    double left = 40,
    double w = 300,
  }) => ScannedLine(
    text: text,
    width: w,
    height: 24,
    left: left,
    top: top,
    angle: 0,
  );

  group('yatık yığın', () {
    test('üst üste duran kitaplar ayrı ayrı tanınır', () {
      // Dört kitap üst üste: kalınlıkları kadar aralıklı.
      final spines = ShelfScanService.parseLines([
        flat('Aleksandr Puşkin Yüzbaşının Kızı', 20),
        flat('Dede Korkut Hikayeleri', 90),
        flat('Lewis Carroll Alice Harikalar Diyarında', 160),
        flat('Jack London Beyaz Diş', 230),
      ]);

      expect(spines, hasLength(4));
      expect(
        spines.map((s) => s.text),
        containsAll([
          'Aleksandr Puşkin Yüzbaşının Kızı',
          'Dede Korkut Hikayeleri',
          'Lewis Carroll Alice Harikalar Diyarında',
          'Jack London Beyaz Diş',
        ]),
      );
    });

    test('aynı kapaktaki iki satır tek kitap sayılır', () {
      // Yakın duran iki satır (başlık ve altındaki yazar) bölünmemeli.
      final spines = ShelfScanService.parseLines([
        flat('Beyaz Diş', 100),
        flat('Jack London', 118),
      ]);

      expect(spines, hasLength(1));
      expect(spines.single.lineCount, 2);
      expect(spines.single.text, 'Beyaz Diş Jack London');
    });

    test('aynı hizadaki iki ayrı yığın karışmaz', () {
      // Rafın iki ucunda, aynı yükseklikte iki yığın: yatayda örtüşmüyorlar.
      final spines = ShelfScanService.parseLines([
        flat('Beyaz Diş Jack London', 100, left: 20, w: 240),
        flat('Dede Korkut Hikayeleri', 104, left: 420, w: 240),
      ]);

      expect(spines, hasLength(2));
    });

    test('ayakta duranlarla yatıklar bir arada çözülür', () {
      // Gerçek raf: altta ayakta sırtlar, üstte yatık yığın.
      final spines = ShelfScanService.parseLines([
        spine('Tutunamayanlar', 20, 300),
        spine('Kürk Mantolu Madonna', 120, 300),
        flat('Jack London Beyaz Diş', 20, left: 20, w: 300),
        flat('Dede Korkut Hikayeleri', 90, left: 24, w: 300),
      ]);

      expect(spines, hasLength(4));
      // Yatık satırlar ayakta duran sırtlara yapışmamalı.
      expect(
        spines.map((s) => s.text),
        containsAll(['Tutunamayanlar', 'Kürk Mantolu Madonna']),
      );
    });

    test('yatık satırlar sütun eşiğini şişirmez', () {
      // Yatık kutular 600 piksel geniş. Eşik onlardan hesaplanırsa yan yana
      // duran ince sırtlar tek kitaba çöker.
      final spines = ShelfScanService.parseLines([
        flat('Dede Korkut Hikayeleri Oğuz Boyları', 20, left: 10, w: 600),
        spine('Tutunamayanlar', 100, 300),
        spine('Kürk Mantolu Madonna', 150, 300),
        spine('İnce Memed', 200, 300),
      ]);

      expect(spines, hasLength(4));
    });
  });
}
