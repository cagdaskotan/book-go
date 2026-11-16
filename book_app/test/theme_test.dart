import 'dart:math' as math;

import 'package:book_app/theme/app_accents.dart';
import 'package:book_app/theme/app_theme.dart';
import 'package:book_app/theme/app_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tasarım sisteminin kendisini sınar.
///
/// Tasarım bozulduğunda sebebi genelde tek tek sayfalar değil, farkına
/// varılmayan bir sistem hatası oluyor. Nitekim öyle olmuştu: kart rengi
/// sayfanın zeminiyle birebir aynıydı ve bütün ekran tek düze bir levha
/// gibi duruyordu. Gözle bakmadan yakalanabilecek bu tür hataları
/// buradaki testler tutuyor.

/// WCAG bağıl parlaklık.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// İki rengin kontrast oranı (1 = aynı, 21 = siyah/beyaz).
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Saydam rengi zeminin üstüne düzleştirir — kontrast ancak böyle ölçülür.
Color _flatten(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

void main() {
  // Renk şeması yazı tipinden ayrı durduğu için tema kurmaya (dolayısıyla
  // google_fonts'a) gerek yok: burada ölçülen şey renk ve punto.
  final schemes = {
    'açık': (AppTheme.lightScheme, AppTheme.lightCanvas),
    'koyu': (AppTheme.darkScheme, AppTheme.darkCanvas),
  };

  group('yüzey ayrımı', () {
    schemes.forEach((name, pair) {
      final (cs, page) = pair;
      test('$name temada kart zeminden ayrışıyor', () {
        // Asıl hata buydu: kart rengi sayfa zemini ile birebir aynıydı.
        // Kart sayfadan yalnızca 1 piksellik çizgiyle ayrılınca ekran düz
        // bir levhaya dönüyor.
        expect(cs.surface, isNot(page), reason: 'kart rengi zeminle aynı');
        // 1.09'da kalınca ekranda her şey tek bir tonda eriyordu; telefonda
        // bakıldığında kartın kenarı ancak kenarlıktan anlaşılıyordu.
        expect(
          _contrast(cs.surface, page),
          greaterThan(1.15),
          reason: 'kart ile zemin farkı gözle seçilmiyor',
        );
      });
    });
  });

  group('metin okunurluğu', () {
    schemes.forEach((name, pair) {
      final (cs, page) = pair;

      test('$name temada gövde metni kartın üstünde okunuyor', () {
        // WCAG AA normal metin için 4.5 istiyor.
        expect(_contrast(cs.onSurface, cs.surface), greaterThanOrEqualTo(4.5));
      });

      test('$name temada ikincil metin yeterince koyu', () {
        expect(
          _contrast(cs.onSurfaceVariant, cs.surface),
          greaterThanOrEqualTo(3.0),
        );
      });

      test('$name temada gövde metni sayfa zemininde de okunuyor', () {
        expect(_contrast(cs.onSurface, page), greaterThanOrEqualTo(4.5));
      });

      test('$name temada birincil düğme yazısı okunuyor', () {
        expect(_contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(3.0));
      });

      test('$name temada hata rengi yazısı okunuyor', () {
        expect(_contrast(cs.onError, cs.error), greaterThanOrEqualTo(3.0));
      });
    });
  });

  group('aksan ailesi', () {
    test('aksanlar birbirinden ayırt edilebiliyor', () {
      // Dönüşümlü kullanıldıklarında iki kart aynı görünmemeli.
      expect(
        Accents.cycle.toSet().length,
        Accents.cycle.length,
        reason: 'yinelenen aksan var',
      );
    });

    test('aksanlar aynı parlaklık bandında', () {
      // "Özensiz" görünümün sebebi renklerin farklı açıklıkta olmasıydı:
      // soluk sarı ile doygun teal yan yana aile gibi durmuyordu.
      final lums = Accents.cycle.map(_luminance).toList();
      final spread = lums.reduce(math.max) - lums.reduce(math.min);
      expect(
        spread,
        lessThan(0.30),
        reason: 'aksanların parlaklık farkı açık, aile gibi durmuyorlar',
      );
    });

    test('aksanların üstünde beyaz yazı okunuyor', () {
      for (final accent in Accents.cycle) {
        expect(
          _contrast(Colors.white, accent),
          greaterThanOrEqualTo(3.0),
          reason: '$accent üstünde beyaz yazı sönük kalıyor',
        );
      }
    });

    test('aksan seçimi aynı tohum için değişmiyor', () {
      expect(Accents.at(7), Accents.at(7));
      expect(Accents.at(-3), Accents.at(3));
    });

    test('soluk hâli kartın üstünde görünüyor', () {
      final surface = AppTheme.lightScheme.surface;
      for (final accent in Accents.cycle) {
        final wash = _flatten(accent.withValues(alpha: .11), surface);
        expect(
          _contrast(wash, surface),
          greaterThan(1.02),
          reason: '$accent soluk hâli zeminde kayboluyor',
        );
      }
    });
  });

  group('tipografi ölçeği', () {
    final scale = <String, TextStyle>{
      'overline': AppType.overline,
      'labelSmall': AppType.labelSmall,
      'label': AppType.label,
      'bodySmall': AppType.bodySmall,
      'body': AppType.body,
      'itemTitle': AppType.itemTitle,
      'sectionTitle': AppType.sectionTitle,
      'pageTitle': AppType.pageTitle,
      'display': AppType.display,
    };

    test('basamaklar büyüyerek ilerliyor', () {
      final sizes = scale.values.map((s) => s.fontSize!).toList();
      for (var i = 1; i < sizes.length; i++) {
        expect(
          sizes[i],
          greaterThan(sizes[i - 1]),
          reason: 'ölçek ${scale.keys.elementAt(i)} adımında geriliyor',
        );
      }
    });

    test('hiçbir basamak azami kalınlıkta değil', () {
      // Her şey azami kalın olunca hiçbir şey öne çıkmıyor; ölçeğin kuralı.
      for (final entry in scale.entries) {
        expect(
          entry.value.fontWeight!.value,
          lessThan(FontWeight.w900.value),
          reason: '${entry.key} azami kalınlıkta',
        );
      }
    });

    test('okunacak metnin satır yüksekliği rahat', () {
      expect(AppType.body.height, greaterThanOrEqualTo(1.45));
      expect(AppType.bodySmall.height, greaterThanOrEqualTo(1.4));
    });

    test('başlıklar sıkı, gövde rahat', () {
      expect(AppType.pageTitle.height, lessThan(AppType.body.height!));
    });

    test('negatif harf aralığı yalnızca büyük puntolarda', () {
      for (final entry in scale.entries) {
        final spacing = entry.value.letterSpacing ?? 0;
        if (spacing < 0) {
          expect(
            entry.value.fontSize,
            greaterThanOrEqualTo(16),
            reason: '${entry.key} küçük puntoda harfleri sıkıştırıyor',
          );
        }
      }
    });
  });

  group('tema metin rolleri', () {
    test('Material rolleri ölçeğe bağlı', () {
      // Bağlı olmazsa tema süs olarak kalıyor ve herkes kendi fontSize'ını
      // elle yazmaya başlıyor — nitekim öyle olmuştu.
      final t = AppTheme.scaleTextTheme(const TextTheme());
      expect(t.titleLarge?.fontSize, AppType.sectionTitle.fontSize);
      expect(t.bodyLarge?.fontSize, AppType.body.fontSize);
      expect(t.labelSmall?.fontSize, AppType.overline.fontSize);
      expect(t.headlineSmall?.fontSize, AppType.pageTitle.fontSize);
    });

    test('rollere ağırlık ve satır yüksekliği de geçiyor', () {
      final t = AppTheme.scaleTextTheme(const TextTheme());
      expect(t.bodyLarge?.height, AppType.body.height);
      expect(t.titleLarge?.fontWeight, AppType.sectionTitle.fontWeight);
    });
  });
}
