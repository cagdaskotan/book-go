import 'package:book_app/models/quote.dart';
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

  group('defter süzmesi', () {
    Quote q(
      int id,
      String text, {
      String? book,
      String? author,
      bool fav = false,
    }) => Quote(
      id: id,
      bookId: id,
      text: text,
      favorite: fav,
      bookTitle: book,
      bookAuthor: author,
    );

    final sample = [
      q(
        1,
        'Şu dağların ardında bir ışık vardı.',
        book: 'İnce Memed',
        author: 'Yaşar Kemal',
        fav: true,
      ),
      q(
        2,
        'Noktalama yokluğuna alışınca akıp gidiyor.',
        book: 'Körlük',
        author: 'José Saramago',
      ),
      q(
        3,
        'Bir insanın bütün hayatını değiştiren anlar.',
        book: 'Kürk Mantolu Madonna',
        author: 'Sabahattin Ali',
        fav: true,
      ),
    ];

    test('sorgu boşken hepsi görünür', () {
      expect(filterQuotes(sample), hasLength(3));
    });

    test('cümlede aksansız arama tutar', () {
      final found = filterQuotes(sample, query: 'su daglarin');
      expect(found.map((e) => e.id).toList(), [1]);
    });

    test('kitap adında ve yazarda da arar', () {
      expect(filterQuotes(sample, query: 'ince memed').single.id, 1);
      expect(filterQuotes(sample, query: 'saramago').single.id, 2);
      expect(filterQuotes(sample, query: 'SABAHATTIN').single.id, 3);
    });

    test('alakasız sorgu boş döner', () {
      expect(filterQuotes(sample, query: 'kafka'), isEmpty);
    });

    test('başucu süzgeci yalnızca favorileri bırakır', () {
      final favs = filterQuotes(sample, onlyFavorites: true);
      expect(favs.map((e) => e.id).toList(), [1, 3]);
    });

    test('süzgeç ve arama birlikte çalışır', () {
      // Körlük favori değil: başucu süzgeciyle birlikte sonuç çıkmamalı.
      expect(
        filterQuotes(sample, query: 'korluk', onlyFavorites: true),
        isEmpty,
      );
      expect(
        filterQuotes(sample, query: 'madonna', onlyFavorites: true).single.id,
        3,
      );
    });

    test('yalnızca boşluk yazmak süzmez', () {
      expect(filterQuotes(sample, query: '   '), hasLength(3));
    });
  });

  group('günün alıntısı', () {
    Quote q(int id, {bool fav = false}) =>
        Quote(id: id, bookId: 1, text: 'metin $id', favorite: fav);

    test('defter boşken seçim yok', () {
      expect(pickDailyQuote(const [], DateTime(2026, 11, 11)), isNull);
    });

    test('aynı gün içinde seçim değişmez', () {
      final pool = [q(1), q(2), q(3)];
      final a = pickDailyQuote(pool, DateTime(2026, 11, 11, 8));
      final b = pickDailyQuote(pool, DateTime(2026, 11, 11, 23));
      expect(a!.id, b!.id);
    });

    test('gün değişince alıntı da değişir', () {
      final pool = [q(1), q(2)];
      final today = pickDailyQuote(pool, DateTime(2026, 11, 11))!;
      final tomorrow = pickDailyQuote(pool, DateTime(2026, 11, 12))!;
      expect(today.id, isNot(tomorrow.id));
    });

    test('başucu alıntısı varsa oradan seçer', () {
      final pool = [q(1), q(2), q(3, fav: true)];
      for (var day = 1; day <= 14; day++) {
        final pick = pickDailyQuote(pool, DateTime(2026, 11, day))!;
        expect(pick.id, 3, reason: '$day. gün favori dışından seçti');
      }
    });

    test('tek alıntı varsa her gün onu verir', () {
      final pool = [q(7)];
      expect(pickDailyQuote(pool, DateTime(2026, 1, 1))!.id, 7);
      expect(pickDailyQuote(pool, DateTime(2026, 6, 30))!.id, 7);
    });
  });
}
