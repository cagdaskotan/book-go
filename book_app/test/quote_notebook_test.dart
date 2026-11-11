import 'package:book_app/services/book_service.dart';
import 'package:book_app/services/quote_service.dart';
import 'package:book_app/utils/turkish.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Alıntı defteri: kitaplığın tamamından toplanan alıntılar.
///
/// İki iddia sınanıyor. Birincisi deponun kitap künyesini alıntıyla birlikte
/// getirmesi — defter "hangi kitaptan" sorusuna cevap veremezse işe
/// yaramaz. İkincisi aramanın Türkçe harflerde çalışması; "İ" ile "i"
/// eşleşmezse kullanıcı kendi yazdığı alıntıyı bulamaz.
void main() {
  late Database db;
  late QuoteService quotes;
  late BookService books;

  setUp(() async {
    db = await openTestDatabase();
    quotes = QuoteService();
    books = BookService();
  });

  tearDown(() async => db.close());

  test('alıntılar kitap künyesiyle birlikte gelir', () async {
    final id = await books.createBook(
      title: 'Kürk Mantolu Madonna',
      totalPages: 160,
      author: 'Sabahattin Ali',
    );
    await quotes.createQuote(bookId: id, text: 'Bir cümle', page: 14);

    final all = await quotes.fetchQuotes();
    expect(all, hasLength(1));
    expect(all.single.bookTitle, 'Kürk Mantolu Madonna');
    expect(all.single.bookAuthor, 'Sabahattin Ali');
    expect(all.single.page, 14);
  });

  test('tüm kitapların alıntıları bir arada, yeniden eskiye', () async {
    final a = await books.createBook(title: 'Körlük', totalPages: 328);
    final b = await books.createBook(title: 'Satranç', totalPages: 76);

    await quotes.createQuote(bookId: a, text: 'Birinci');
    await quotes.createQuote(bookId: b, text: 'İkinci');
    await quotes.createQuote(bookId: a, text: 'Üçüncü');

    final all = await quotes.fetchQuotes();
    expect(all.map((q) => q.text).toList(), ['Üçüncü', 'İkinci', 'Birinci']);
    // Kitap süzgeci hâlâ çalışıyor: detay sayfası bunu kullanıyor.
    expect(await quotes.fetchQuotes(bookId: b), hasLength(1));
  });

  test('arama Türkçe harflerde eşleşir', () async {
    final id = await books.createBook(
      title: 'İnce Memed',
      totalPages: 440,
      author: 'Yaşar Kemal',
    );
    await quotes.createQuote(
      bookId: id,
      text: 'Şu dağların ardında bir ışık vardı.',
    );

    final all = await quotes.fetchQuotes();
    final quote = all.single;

    // Defterdeki arama bu üç alanda birlikte bakıyor.
    bool matches(String raw) {
      final needle = foldTurkish(raw.trim());
      return containsTurkish(quote.text, needle) ||
          containsTurkish(quote.bookTitle ?? '', needle) ||
          containsTurkish(quote.bookAuthor ?? '', needle);
    }

    // Kullanıcı aksansız yazıyor.
    expect(matches('su daglarin'), isTrue, reason: 'cümlede bulunmalı');
    expect(matches('ince memed'), isTrue, reason: 'kitap adında bulunmalı');
    expect(matches('yasar'), isTrue, reason: 'yazarda bulunmalı');
    // Kullanıcı aksanlı yazıyor — ikisi de tutmalı.
    expect(matches('Işık'), isTrue);
    expect(matches('ışık'), isTrue);
    expect(matches('Kafka'), isFalse);
  });

  test('katlama harf sayısını korur', () async {
    // Alıntı defteri eşleşen parçayı vurgularken katlanmış metindeki
    // konumu olduğu gibi kullanıyor; uzunluk değişirse vurgu kayar.
    for (final sample in [
      'İstanbul',
      'ŞIĞĞÜÖÇ',
      'Düşünceler ışığında',
      'Straße',
      'normal metin 123',
    ]) {
      expect(
        foldTurkish(sample).length,
        sample.length,
        reason: '"$sample" katlanınca uzunluk değişti',
      );
    }
  });
}
