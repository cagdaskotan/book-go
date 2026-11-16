import 'package:book_app/theme/app_theme.dart';
import 'package:book_app/theme/app_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Yazı tiplerinin uygulamanın içinde olduğunu doğrular.
///
/// google_fonts varsayılan olarak yazı tipini **çalışma anında
/// internetten** indiriyor. Bilge çevrimdışı çalışan bir uygulama:
/// kullanıcı ağsızken ilk kez açtığında bütün tipografi yedek yazı
/// tipine düşüyor, ölçek çöküyor ve uygulama başka bir uygulamaya
/// benziyordu.
///
/// Dosyalar varlıklara gömülünce paket indirmeyi atlıyor. Bu testin işi
/// gömmenin bozulmadığını tutmak: `allowRuntimeFetching` kapalıyken yazı
/// tipi varlıklarda bulunamazsa google_fonts hata fırlatıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // İnternete çıkma izni yok: yazı tipi ya varlıklardan gelir ya da
    // test patlar. Asıl sınanan şey bu.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('arayüz yazı tipi (Manrope) gömülü', () {
    expect(() => GoogleFonts.manrope(), returnsNormally);
    expect(
      () => GoogleFonts.manrope(fontWeight: FontWeight.w700),
      returnsNormally,
    );
    expect(
      () => GoogleFonts.manrope(fontWeight: FontWeight.w800),
      returnsNormally,
    );
  });

  test('içerik yazı tipi (Lora) gömülü', () {
    expect(() => GoogleFonts.lora(), returnsNormally);
    expect(
      () => GoogleFonts.lora(fontWeight: FontWeight.w600),
      returnsNormally,
    );
  });

  test('alıntının eğik hâli de gömülü', () {
    // Alıntılar eğik yazılıyor; italik dosya eksik olsaydı sistem sahte
    // eğim üretirdi ve serif harflerde çirkin durur.
    expect(
      () => GoogleFonts.lora(fontStyle: FontStyle.italic),
      returnsNormally,
    );
  });

  test('ölçekteki serif stilleri ağa çıkmadan kurulabiliyor', () {
    expect(() => AppSerif.title, returnsNormally);
    expect(() => AppSerif.quote, returnsNormally);
    expect(() => AppSerif.itemTitle, returnsNormally);
    expect(() => AppSerif.display, returnsNormally);
  });

  test('temalar ağa çıkmadan kurulabiliyor', () {
    // Asıl senaryo: uçak modunda uygulamayı ilk kez açmak.
    expect(() => AppTheme.light(), returnsNormally);
    expect(() => AppTheme.dark(), returnsNormally);
  });
}
