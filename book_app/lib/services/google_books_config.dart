/// Google Books API anahtarı — OPSİYONEL ve ÜCRETSİZ.
///
/// Boş bırakılırsa anahtarsız (paylaşımlı, günlük kotası düşük) denenir;
/// kota dolarsa arama yalnızca Open Library'den gelir.
///
/// Kendi ÜCRETSİZ anahtarın için (kredi kartı/ödeme gerekmez):
///   1. https://console.cloud.google.com → yeni proje oluştur
///   2. "APIs & Services" → "Library" → "Books API" → Enable
///   3. "Credentials" → "Create credentials" → "API key"
///   4. Anahtarı kopyala, aşağıdaki tırnakların içine yapıştır
///   5. (Önerilir) Anahtarı "Books API" ile sınırlandır
///
/// Günde 1.000 sorgu ücretsizdir — kişisel kullanım için fazlasıyla yeterli.
const String googleBooksApiKey = '';
