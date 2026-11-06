# Mobil Kütüphanem

Kişisel kitaplık, okuma günlüğü ve hedef takip uygulaması. **Tamamen cihazda
çalışır** — sunucu, hesap ya da internet bağlantısı gerektirmez.

```
book_app/            Flutter uygulaması (asıl ürün)
tools/exportbackup/  Eski MySQL verisini yedek dosyasına çeviren tek seferlik araç
```

## Mimari

Tüm kullanıcı verisi cihazdaki tek bir SQLite dosyasında (`kutuphanem.db`)
durur. Uygulama açılırken şema kurulur veya yükseltilir; her ekran veriyi
doğrudan diskten okur, dolayısıyla bekleme ekranı yoktur ve uçak modunda da
çalışır.

| Katman | Yer | Not |
| --- | --- | --- |
| Şema ve ayarlar | [app_database.dart](book_app/lib/data/app_database.dart), [settings_store.dart](book_app/lib/data/settings_store.dart) | Şema sürümü artırılarak göç edilir; kullanıcı verisi silinmez |
| Kitaplar ve günlük | [book_service.dart](book_app/lib/services/book_service.dart) | İlerleme ve bitmişlik günlük kayıtlarından türetilir |
| Raflar, alıntılar | [collection_service.dart](book_app/lib/services/collection_service.dart), [quote_service.dart](book_app/lib/services/quote_service.dart) | |
| İstatistik, oyunlaştırma | [gamification_service.dart](book_app/lib/services/gamification_service.dart), [stats_service.dart](book_app/lib/services/stats_service.dart) | XP, seri ve ısı haritası cihazda hesaplanır |
| Öneriler | [recommendation_service.dart](book_app/lib/services/recommendation_service.dart) | Kitaplıktan profil çıkarır, 12 saat önbellekler |
| Profil | [profile_service.dart](book_app/lib/services/profile_service.dart) | Yalnızca görünen ad; hesap/şifre yok |
| Yedekleme | [backup_service.dart](book_app/lib/services/backup_service.dart) | Tek `.zip`: `backup.json` + defter görselleri |

İnternete çıkılan tek yer, yeni kitap eklerken künye doldurmak için
[catalog_service.dart](book_app/lib/services/catalog_service.dart) — Google
Books ve Open Library'nin açık uçlarına doğrudan gider. Bu servisler
erişilemese bile uygulama çalışır, bilgiler elle girilir.

## Geliştirme

```bash
cd book_app
flutter pub get
flutter run              # cihazda çalıştır
flutter test             # birim testleri (gerçek SQLite üstünde)
flutter analyze          # statik analiz
```

## Yedekleme

Kullanıcı `Profil > Yedek al` ile tek bir `.zip` üretir (Drive'a atabilir ya da
dosyaya kaydedebilir). `Profil > Yedekten geri yükle` aynı dosyayı okur ve
cihazdaki kitaplığı onunla **değiştirir**. Arşivin içindeki `backup.json`
insan tarafından okunabilir; düz `.json` dosyaları da geri yüklenebilir.

## Eski sunucu verisini taşıma

Proje başlangıçta Go + MySQL backend ile çalışıyordu; bu bağımlılık kaldırıldı
(sunucu kodu git geçmişinde `local-first-migration` öncesindeki commit'lerde
duruyor). Eski veritabanındaki kitaplığı yeni uygulamaya almak için:

```bash
DB_USER=root DB_PASS=... DB_NAME=bookdb go run ./tools/exportbackup
```

Oluşan JSON dosyasını telefona kopyala, uygulamada `Profil > Yedekten geri
yükle` ile aç.

## Mağazaya çıkmadan önce

- [ ] `AndroidManifest.xml` içindeki AdMob `APPLICATION_ID` hâlâ Google'ın test
      kimliği — kendi AdMob kimliğinle değiştir.
- [ ] [ad_config.dart](book_app/lib/services/ad_config.dart) içindeki reklam
      birimi kimliklerini kontrol et.
- [ ] Reklam SDK'sı veri topladığı için Play Console'da gizlilik politikası
      bağlantısı ve "Veri güvenliği" formu zorunlu.
- [ ] Sürüm numarasını `pubspec.yaml` içinde yükselt, imzalı yayın yapılandır.
