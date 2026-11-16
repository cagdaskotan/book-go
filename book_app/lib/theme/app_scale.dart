import 'package:flutter/widgets.dart';

/// Boşluk ölçeği.
///
/// Serbest sayı yerine ölçekten seçmek ekranlar arası ritmi tutarlı tutar:
/// iki kart arasındaki boşluk her yerde aynı olur, "burada 14 orada 16" gibi
/// farklar kaybolur. Taban 4; göz bu aralığı düzen olarak okuyor.
abstract final class Gap {
  /// 4 — ikon ile etiketi arasındaki nefes.
  static const double xs = 4;

  /// 8 — aynı öbeğe ait satırlar.
  static const double sm = 8;

  /// 12 — kart içi bölümler.
  static const double md = 12;

  /// 16 — standart kenar boşluğu ve kartlar arası.
  static const double lg = 16;

  /// 24 — bölüm ayrımı.
  static const double xl = 24;

  /// 32 — ekran içindeki büyük duraklar.
  static const double xxl = 32;

  // Hazır kenar boşlukları — en sık tekrar edenler.
  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);

  // Hazır dikey aralıklar.
  static const Widget vXs = SizedBox(height: xs);
  static const Widget vSm = SizedBox(height: sm);
  static const Widget vMd = SizedBox(height: md);
  static const Widget vLg = SizedBox(height: lg);
  static const Widget vXl = SizedBox(height: xl);

  // Hazır yatay aralıklar.
  static const Widget hXs = SizedBox(width: xs);
  static const Widget hSm = SizedBox(width: sm);
  static const Widget hMd = SizedBox(width: md);
  static const Widget hLg = SizedBox(width: lg);
}

/// Köşe yuvarlaklığı ölçeği.
///
/// Uygulamanın karakteri yumuşak köşeler üzerine kurulu; ama her yerde aynı
/// yarıçap kullanılırsa derinlik kaybolur. Kural: eleman büyüdükçe yarıçap
/// artar — küçük bir etiketle tam ekran bir sayfa aynı köşeyi paylaşmaz.
abstract final class Radii {
  /// 12 — metin düğmeleri, küçük kutucuklar.
  static const double sm = 12;

  /// 14 — düğmeler, menüler.
  static const double md = 14;

  /// 18 — giriş alanları.
  static const double input = 18;

  /// 20 — kartlar.
  static const double lg = 20;

  /// 22 — alt sayfalar, diyaloglar.
  static const double xl = 22;

  /// Tam yuvarlak (hap biçimi).
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brInput = BorderRadius.all(Radius.circular(input));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Alt sayfalar için yalnızca üst köşeler.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Dokunma hedefi alt sınırları.
///
/// Android erişilebilirlik kılavuzu 48dp diyor. Küçük ikon düğmeleri bu
/// sınırın altına düştüğünde titrek parmakla kullanılamıyor.
abstract final class Touch {
  /// En küçük dokunulabilir kenar (dp).
  static const double minTarget = 48;

  /// Yan yana duran ikon düğmeleri arası en az boşluk.
  static const double minSpacing = Gap.sm;
}

/// Gölge ölçeği.
///
/// Eskiden her kart kendi gölgesini elle yazıyordu ve hepsi saf siyahtı
/// (`Colors.black` %6). Saf siyah gölge ılık kâğıt zeminde gri bir leke
/// bırakıyor, kart "yapıştırılmış" duruyor. Buradaki gölgeler mürekkep
/// tonunda ve iki katmanlı: yakın ve sert olan kenarı tanımlıyor, uzak ve
/// yumuşak olan yükseltiyor.
abstract final class Shadows {
  static const Color _ink = Color(0xFF2B2416);

  /// Sayfadaki sıradan kart.
  static List<BoxShadow> get card => [
    BoxShadow(
      color: _ink.withValues(alpha: .05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _ink.withValues(alpha: .06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  /// Öne çıkan kart: kahraman kitap, kutlama, günün alıntısı.
  static List<BoxShadow> get raised => [
    BoxShadow(
      color: _ink.withValues(alpha: .06),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _ink.withValues(alpha: .10),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ];

  /// Renkli bir yüzeyin kendi rengiyle attığı gölge — düğmeler, rozetler.
  static List<BoxShadow> tinted(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: .28),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}
