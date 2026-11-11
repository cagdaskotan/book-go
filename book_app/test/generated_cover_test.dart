import 'package:book_app/widgets/book_cover.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kapağı olmayan kitap için üretilen cilt rengi.
///
/// Türkçe baskıların çoğunda çevrimiçi kapak bulunmuyor, yani bu yol
/// istisna değil. İki şey şart: aynı kitap her yerde **aynı** renkte
/// çıkmalı (yoksa aynı kitap ana ekranda bir renk, rafta başka renk olur),
/// ve farklı kitaplar birbirinden ayırt edilebilmeli.
void main() {
  test('aynı ad her zaman aynı rengi verir', () {
    final a = GeneratedCover.colorOf('Kürk Mantolu Madonna');
    final b = GeneratedCover.colorOf('Kürk Mantolu Madonna');
    expect(a, b);
  });

  test('farklı adlar paleti dolaşır', () {
    const titles = [
      'Tutunamayanlar',
      'Körlük',
      'Satranç',
      'Dönüşüm',
      'İnce Memed',
      'Saatleri Ayarlama Enstitüsü',
      'Sineklerin Tanrısı',
      'Yüzbaşının Kızı',
    ];
    final colors = titles.map(GeneratedCover.colorOf).toSet();
    // Hepsi tek renge çökmemeli; kitaplık tek tip görünmesin.
    expect(colors.length, greaterThanOrEqualTo(3));
  });

  test('boş ad çökmez', () {
    expect(() => GeneratedCover.colorOf(''), returnsNormally);
  });

  test('Türkçe harfler sorun çıkarmaz', () {
    for (final title in ['Işık', 'ĞÜŞÖÇİ', 'Çalıkuşu']) {
      expect(() => GeneratedCover.colorOf(title), returnsNormally);
    }
  });

  test('uzun ad taşma yapmaz', () {
    // Karakter kodları çarpılırken taşarsa negatif indeks oluşur ve
    // uygulama çöker; maskeleme bunu engelliyor.
    final long = 'Çok uzun bir kitap adı ' * 50;
    expect(() => GeneratedCover.colorOf(long), returnsNormally);
  });
}
