import 'package:flutter/material.dart';

/// Tipografi ölçeği.
///
/// Uygulamanın en büyük tasarım sorunu buradaydı: 180 yerde `w900`, yüzlerce
/// elle yazılmış `fontSize` ve 9'dan 32'ye kadar rastgele dağılmış boyutlar.
/// Her şey azami kalın olunca hiçbir şey öne çıkmıyor; sayfa bir "kalın
/// küçük yazı" yığınına dönüşüyor ve ucuz görünüyor.
///
/// Buradaki kurallar:
///
/// * **Hiyerarşi ağırlıkla değil boyutla kurulur.** İki seviye arasında en
///   az %20 boyut farkı var; göz farkı okumadan görüyor.
/// * **Ağırlık üçe iner:** başlıklar `w700`, vurgu `w600`, gövde `w500`.
///   `w800` yalnızca sayfa başlıklarında, `w900` hiç kullanılmıyor.
/// * **Satır yüksekliği okunurluğa göre:** başlıkta sıkı (1.1–1.2), gövdede
///   rahat (1.45–1.5). Kitap uygulamasında metin okunacak, sıkışmayacak.
/// * **Negatif harf aralığı yalnızca büyük puntolarda.** Küçük yazıda
///   harfleri sıkıştırmak okunurluğu bozuyor.
abstract final class AppType {
  /// Yıl karnesi, kutlama gibi tek bir sayının sahne aldığı yerler.
  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
  );

  /// Sayfa başlığı — ekran başına bir tane.
  static const TextStyle pageTitle = TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
  );

  /// Kart ya da bölüm başlığı.
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 19,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.35,
  );

  /// Liste satırındaki kitap adı gibi öne çıkan satırlar.
  static const TextStyle itemTitle = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// Okunacak metin: açıklama, alıntı, not.
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  /// İkincil açıklama — başlığın altındaki tek satır.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13.5,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  /// Etiket: rozet, sekme, alan adı.
  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// Küçük etiket — sayaçlar, "s. 42" gibi üst bilgiler.
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// Bölüm üstü küçük başlık (GÜNÜN ALINTISI gibi).
  ///
  /// Büyük harf ve geniş harf aralığı burada bilinçli: küçük punto büyük
  /// harfle yazıldığında harfler birbirine girer, aralık onu açıyor.
  static const TextStyle overline = TextStyle(
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );

  /// Rakamın kendisinin konuştuğu yerler: istatistik kutusu, sayaç.
  ///
  /// Tabular rakamlar şart — değişen bir sayacın rakam genişliği oynarsa
  /// satır titriyor.
  static const TextStyle stat = TextStyle(
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Küçük istatistik rakamı.
  static const TextStyle statSmall = TextStyle(
    fontSize: 18,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Metin stillerini renklendirmek için kısayol.
///
/// `AppType.body.withColor(cs.onSurfaceVariant)` yazmak, her çağrı yerinde
/// `copyWith(color: ...)` tekrarından okunaklı.
extension AppTypeColor on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);

  /// Yarı saydam ikincil ton — "soluk" metin için tek yol.
  TextStyle muted(BuildContext context) =>
      copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
}
