import 'package:book_app/models/reading_status.dart';
import 'package:book_app/utils/turkish.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Türkçe katlama', () {
    test('büyük İ ile küçük i eşleşir', () {
      // toLowerCase() burada yanılıyordu: "İ" birleşik noktalı karaktere
      // dönüşüp "i" ile eşleşmiyordu.
      expect(foldTurkish('İnce Memed'), 'ince memed');
      expect(containsTurkish('İnce Memed', foldTurkish('ince')), isTrue);
    });

    test('noktasız ı ile i eşleşir', () {
      expect(containsTurkish('Işık', foldTurkish('isik')), isTrue);
      expect(containsTurkish('ışık', foldTurkish('ISIK')), isTrue);
    });

    test('ş ğ ü ö ç karşılıkları', () {
      expect(foldTurkish('Oğuz Atay'), 'oguz atay');
      expect(foldTurkish('Şeker Portakalı'), 'seker portakali');
      expect(foldTurkish('Çalıkuşu'), 'calikusu');
      expect(containsTurkish('Gülün Adı', foldTurkish('gulun')), isTrue);
    });

    test('şapkalı harfler de indirilir', () {
      expect(foldTurkish('Kâğıt'), 'kagit');
    });

    test('boş değerler patlamaz', () {
      expect(containsTurkish(null, 'abc'), isFalse);
      expect(containsTurkish('', 'abc'), isFalse);
      expect(foldTurkish(''), '');
    });
  });

  group('okuma durumu', () {
    test('veritabanı değerinden okunur', () {
      expect(ReadingStatus.parse('reading'), ReadingStatus.reading);
      expect(ReadingStatus.parse('abandoned'), ReadingStatus.abandoned);
      expect(ReadingStatus.parse('finished'), ReadingStatus.finished);
    });

    test('tanınmayan değer listemde sayılır', () {
      expect(ReadingStatus.parse('kimbilir'), ReadingStatus.wantToRead);
      expect(ReadingStatus.parse(null), ReadingStatus.wantToRead);
      expect(ReadingStatus.parse(''), ReadingStatus.wantToRead);
    });

    test('ara verilen ve bırakılan kitaplar uykuda sayılır', () {
      // Bu ikisine sayfa kaydı gelse bile kitap kendiliğinden "okuyorum"a
      // dönmemeli; kullanıcının kararı korunur.
      expect(ReadingStatus.paused.isDormant, isTrue);
      expect(ReadingStatus.abandoned.isDormant, isTrue);
      expect(ReadingStatus.reading.isDormant, isFalse);
      expect(ReadingStatus.wantToRead.isDormant, isFalse);
    });

    test('tüm durumların veritabanı değeri benzersiz', () {
      expect(ReadingStatus.dbValues, hasLength(ReadingStatus.values.length));
    });

    test('bıraktım durumu mevcut', () {
      expect(ReadingStatus.abandoned.label, 'Bıraktım');
      expect(ReadingStatus.dbValues, contains('abandoned'));
    });
  });
}
