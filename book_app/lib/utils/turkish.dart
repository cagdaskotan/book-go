/// Türkçe metin karşılaştırma yardımcıları.
///
/// `toLowerCase()` Türkçe harflerde beklendiği gibi davranmıyor: "İ" küçültülünce
/// birleşik noktalı bir karaktere dönüşüyor ve "i" ile eşleşmiyor. Dolayısıyla
/// "İnce Memed" aranırken "ince" yazan kullanıcı sonuç alamıyordu.
///
/// Burada yaptığımız şey *katlama* (folding): aksanlı harfleri ASCII
/// karşılıklarına indirip karşılaştırmayı hoşgörülü hale getirmek. Böylece
/// "sabahattin" → "Sabahattin", "oguz" → "Oğuz", "ISI" → "ısı" eşleşir.
library;

const Map<String, String> _foldMap = {
  'ı': 'i',
  'İ': 'i',
  'I': 'i',
  'i': 'i',
  'ş': 's',
  'Ş': 's',
  'ğ': 'g',
  'Ğ': 'g',
  'ü': 'u',
  'Ü': 'u',
  'ö': 'o',
  'Ö': 'o',
  'ç': 'c',
  'Ç': 'c',
  'â': 'a',
  'Â': 'a',
  'î': 'i',
  'Î': 'i',
  'û': 'u',
  'Û': 'u',
};

/// Metni karşılaştırılabilir hale getirir: Türkçe harfler ASCII'ye indirilir,
/// kalanlar küçültülür.
String foldTurkish(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldMap[char] ?? char.toLowerCase());
  }
  return buffer.toString();
}

/// [haystack] içinde [needle] geçiyor mu — Türkçe harf duyarsız.
bool containsTurkish(String? haystack, String foldedNeedle) {
  if (haystack == null || haystack.isEmpty) return false;
  return foldTurkish(haystack).contains(foldedNeedle);
}
