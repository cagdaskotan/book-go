import 'package:flutter/material.dart';

/// Bir kitabın okuma durumu.
///
/// Daha önce bu değerler dört ayrı dosyada ham metin olarak duruyordu
/// ('want_to_read', 'paused'…); yeni bir durum eklemek her yeri tek tek
/// bulmayı gerektiriyordu. Tek kaynak burası: etiket, ikon ve veritabanı
/// değeri bir arada.
enum ReadingStatus {
  /// Alınmış ama henüz başlanmamış.
  wantToRead('want_to_read', 'Listemde', Icons.bookmark_add_outlined),

  /// Şu an okunuyor.
  reading('reading', 'Okuyorum', Icons.auto_stories_rounded),

  /// Geçici olarak bırakıldı; dönülecek.
  paused('paused', 'Ara verdim', Icons.pause_circle_outline_rounded),

  /// Bitirilmeyecek. Dönmeye niyet yok.
  ///
  /// Bu durum olmadan, yarıda bırakılan her kitap sonsuza kadar "okuyorum"da
  /// asılı kalıyor: kitaplık kirli görünüyor, istatistik yalan söylüyor.
  abandoned('abandoned', 'Bıraktım', Icons.do_not_disturb_on_outlined),

  /// Bitirildi.
  finished('finished', 'Bitti', Icons.flag_rounded);

  const ReadingStatus(this.value, this.label, this.icon);

  /// Veritabanında saklanan değer.
  final String value;

  /// Arayüzde gösterilen Türkçe etiket.
  final String label;

  final IconData icon;

  /// Kullanıcının elle seçebildiği durumlar.
  ///
  /// "Bitti" listede var ama bitirme akışı günlük üzerinden de tetikleniyor;
  /// ilerleme toplam sayfayı yakalayınca kitap kendiliğinden bitmiş sayılır.
  static const List<ReadingStatus> selectable = values;

  /// Okuması fiilen sürmeyen durumlar — ilerleme kaydı gelse bile kitabı
  /// kendiliğinden "okuyorum"a çevirmemeliyiz; kullanıcının kararı korunur.
  bool get isDormant => this == paused || this == abandoned;

  /// Veritabanı değerinden okur; tanınmayan değer [wantToRead] sayılır.
  static ReadingStatus parse(String? raw) {
    final value = raw?.trim();
    for (final status in values) {
      if (status.value == value) return status;
    }
    return wantToRead;
  }

  /// Geçerli veritabanı değerleri.
  static Set<String> get dbValues => {for (final s in values) s.value};
}
