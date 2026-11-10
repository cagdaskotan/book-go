import 'package:book_app/widgets/star_rating.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puan veritabanında 0–100 duruyor ama kullanıcıya hep yıldız gösteriliyor.
/// Bu dönüşüm iki yönde de kayıpsız olmalı, yoksa kullanıcının verdiği puan
/// kaydedip geri okuyunca değişir.
void main() {
  group('puan - yıldız dönüşümü', () {
    test('tam yıldızlar', () {
      expect(StarRating.starsOf(100), 5.0);
      expect(StarRating.starsOf(80), 4.0);
      expect(StarRating.starsOf(20), 1.0);
      expect(StarRating.starsOf(0), 0.0);
    });

    test('yarım yıldızlar', () {
      expect(StarRating.starsOf(90), 4.5);
      expect(StarRating.starsOf(50), 2.5);
      expect(StarRating.starsOf(10), 0.5);
    });

    test('puansız kitap sıfır yıldız', () {
      expect(StarRating.starsOf(null), 0.0);
    });

    test('ara değerler en yakın yarıma yuvarlanır', () {
      // Eski sürümde elle girilmiş tuhaf puanlar olabilir.
      expect(StarRating.starsOf(73), 3.5);
      expect(StarRating.starsOf(77), 4.0);
      expect(StarRating.starsOf(95), 5.0);
    });

    test('yıldızdan puana geri dönüş kayıpsız', () {
      for (final points in [0, 10, 20, 30, 50, 70, 90, 100]) {
        expect(
          StarRating.pointsOf(StarRating.starsOf(points)),
          points,
          reason: '$points puan yıldıza gidip geri dönünce değişmemeli',
        );
      }
    });
  });

  group('okunur etiket', () {
    test('tam yıldız ondalık göstermez', () {
      expect(StarRating.label(100), '5');
      expect(StarRating.label(80), '4');
    });

    test('yarım yıldız Türkçe virgülle yazılır', () {
      expect(StarRating.label(90), '4,5');
      expect(StarRating.label(30), '1,5');
    });

    test('puansız kitapta sıfır', () {
      expect(StarRating.label(null), '0');
    });
  });
}
