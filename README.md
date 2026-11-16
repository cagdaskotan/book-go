# Bilge — Mobil Kütüphanem

Kişisel kitaplık, okuma günlüğü, alıntı defteri ve hedef takip uygulaması.
**Tamamen cihazda çalışır** — sunucu, hesap ya da internet bağlantısı
gerektirmez. Mağazada "Bilge: Mobil Kütüphanem" adıyla çıkıyor.

```
book_app/            Flutter uygulaması (asıl ürün)
design/              Maskot kaynak görselleri (uygulamaya paketlenmez)
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

## Mağazaya çıkış

Uygulama mağaza için hazır: imza yapılandırması bağlı, R8 küçültmesi açık,
reklam ve analitik yok, hiçbir veri cihazdan çıkmıyor.

### 1. İmza anahtarı (yalnızca bir kez)

Anahtarı **yalnızca sen üretmelisin** ve kaybetmemelisin: kaybolursa
uygulamanın güncellemesi bir daha yayınlanamaz, yeni paket adıyla sıfırdan
çıkmak gerekir.

```bash
keytool -genkey -v -keystore ~/bilge-release.jks         -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias bilge
```

Sonra şablonu kopyalayıp doldur:

```bash
cp book_app/android/key.properties.example book_app/android/key.properties
```

`key.properties` ve `.jks` dosyaları `.gitignore`'da — depoya girmezler.
Anahtar yoksa yayın derlemesi hata vermez, hata ayıklama anahtarıyla
imzalanır; o APK mağazaya yüklenemez ama geliştirme sürer.

### 2. Paket

Play Store'a **AAB** gider, APK değil:

```bash
cd book_app && flutter build appbundle --release
```

Tek APK 125 MB çünkü dört işlemci mimarisini birden taşıyor. AAB'de Play
cihaza göre bölüyor, indirilen boyut çok daha küçük oluyor. Elle APK
dağıtacaksan `--split-per-abi` kullan.

### 3. Play Console

- **Uygulama adı:** Bilge: Mobil Kütüphanem (cihazda ikon adı "Bilge")
- **Paket:** `com.book.bilge`
- **Veri güvenliği formu:** "Veri toplanmıyor" — uygulama ağ üzerinden
  hiçbir kullanıcı verisi göndermiyor. Tek dış çağrı kitap künyesi ve
  kapağı için Open Library'ye yapılan aramalar; bunlar kullanıcıya ait
  bilgi taşımıyor.
- **Gizlilik politikası:** Play her uygulamadan bir adres istiyor, veri
  toplanmasa bile. Kısa bir sayfa yeterli.
- **İzinler:** kamera (barkod, kapak ve raf tarama), bildirim (okuma
  hatırlatıcısı), depolama (yedek dosyası). Üçü de kullanıcı isteyince
  soruluyor.

### 4. Sürüm

`book_app/pubspec.yaml` içindeki `version:` satırı hem sürüm adını hem
derleme numarasını veriyor (`1.1.0+4`). Play aynı derleme numarasını iki
kez kabul etmiyor, her yüklemede artır.
