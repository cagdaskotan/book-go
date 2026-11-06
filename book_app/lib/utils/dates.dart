/// Tarih yardımcıları. Veritabanında tarihler her zaman "YYYY-MM-DD"
/// biçiminde metin olarak durur — saat dilimi kaymalarına kapalı.
library;

String ymd(DateTime value) {
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '${value.year}-$m-$d';
}

String todayYmd() => ymd(DateTime.now());

/// "YYYY-MM-DD" (veya ISO) metnini tarihe çevirir; geçersizse null.
DateTime? parseYmd(String? raw) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return null;
  final datePart = s.split('T').first;
  final parts = datePart.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final parsed = DateTime(y, m, d);
  // 31 Şubat gibi taşan tarihleri reddet
  if (parsed.month != m || parsed.day != d) return null;
  return parsed;
}

/// Metni doğrulayıp normalize eder; boşsa null, geçersizse [FormatException].
String? normalizeYmd(String? raw) {
  final s = raw?.trim();
  if (s == null || s.isEmpty) return null;
  final parsed = parseYmd(s);
  if (parsed == null) throw FormatException('Geçersiz tarih: $s');
  return ymd(parsed);
}
