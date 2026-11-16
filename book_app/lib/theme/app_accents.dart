import 'package:flutter/material.dart';

/// Aksan paleti.
///
/// Uygulamada 247 ayrı sabit renk vardı; her bileşen kendi tonunu seçmişti.
/// Sorun renklerin çokluğu değil, **birbirine göre ayarlanmamış** olmaları:
/// soluk bir sarı (#FFD166), doygun bir teal (#2BAE8A) ve pastel bir mavi
/// (#73D2FF) yan yana gelince hiçbiri diğerine ait görünmüyor — göz bunu
/// "özensiz" diye okuyor.
///
/// Buradaki altı renk aynı doygunluk ve açıklık bandından seçildi: yan yana
/// dizildiklerinde bir aile gibi duruyorlar, tek başlarına da marka moruyla
/// çarpışmıyorlar.
abstract final class Accents {
  /// Marka moru — birincil eylem, ilerleme.
  static const Color violet = Color(0xFF6750E8);

  /// Yeşil — tamamlanan, hedef tutan, seri süren.
  static const Color teal = Color(0xFF17A68B);

  /// Altın sarısı — başarım, rozet, seviye.
  static const Color amber = Color(0xFFD99A33);

  /// Mercan — sıcak vurgu, "sana özel".
  static const Color coral = Color(0xFFE2714F);

  /// Gök mavisi — bilgi, sakin veri.
  static const Color sky = Color(0xFF3B87CE);

  /// Gül — favori, kalp, alıntı.
  static const Color rose = Color(0xFFD1527A);

  /// Dönüşümlü aksan gereken yerler (alıntı kartı, raf rengi) için sıra.
  ///
  /// Sıralama bilinçli: yan yana düşen iki renk birbirinden yeterince uzak
  /// ki arka arkaya gelen iki kart aynı görünmesin.
  static const List<Color> cycle = [violet, teal, amber, coral, sky, rose];

  /// [seed] için her zaman aynı aksanı verir.
  static Color at(int seed) => cycle[seed.abs() % cycle.length];

  /// Aksanın zemin olarak kullanılan soluk hâli.
  ///
  /// Elle `withValues(alpha: .12)` yazmak yerine tek yer: açık ve koyu
  /// temada farklı oran gerekiyor, koyu zeminde %12 hiç görünmüyor.
  static Color wash(BuildContext context, Color accent) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return accent.withValues(alpha: dark ? .20 : .11);
  }
}
