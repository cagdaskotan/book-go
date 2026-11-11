import '../models/book.dart';
import '../utils/dates.dart';

/// Okuma temposu hesabı — günlük kayıtlarından türetilir, saf fonksiyonlardır.
///
/// İki ayrı soruya cevap veriyor ve ikisini karıştırmamak önemli:
///
/// * **Okuma hızı** (sayfa/dakika): yalnızca süre tutulmuş kayıtlardan çıkar.
///   "Kalan 120 sayfa ≈ 95 dakika" demek için bu kullanılır.
/// * **Günlük tempo** (sayfa/gün): kitaba başladığından bugüne kadarki *takvim*
///   günlerine bölünür — okumadığın günler de sayılır. "Bu gidişle 14 Kasım'da
///   bitiyor" demek için bu kullanılır, çünkü gerçek hayatta her gün okunmuyor.
class ReadingPace {
  const ReadingPace({
    required this.totalPages,
    required this.timedPages,
    required this.totalMinutes,
    required this.sessionCount,
    required this.timedSessionCount,
    required this.activeDays,
    required this.spanDays,
    required this.firstDate,
    required this.lastDate,
  });

  /// Bu kitap için kaydedilmiş tüm sayfalar.
  final int totalPages;

  /// Yalnızca süresi de tutulmuş kayıtlardaki sayfalar (hız bunlardan çıkar).
  final int timedPages;

  /// Toplam okuma süresi (dakika).
  final int totalMinutes;

  /// Kayıt sayısı.
  final int sessionCount;

  /// Süresi tutulmuş kayıt sayısı.
  final int timedSessionCount;

  /// Okuma yapılan farklı gün sayısı.
  final int activeDays;

  /// İlk kayıttan bugüne kaç takvim günü geçti (en az 1).
  final int spanDays;

  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Sayfa/dakika. Süre tutulmuş kayıt yoksa null.
  double? get pagesPerMinute {
    if (totalMinutes <= 0 || timedPages <= 0) return null;
    return timedPages / totalMinutes;
  }

  /// Bir sayfanın kaç dakika sürdüğü. Hız yoksa null.
  double? get minutesPerPage {
    final speed = pagesPerMinute;
    if (speed == null || speed <= 0) return null;
    return 1 / speed;
  }

  /// Sayfa/gün — okumadığın günler de dâhil (gerçekçi tahmin için).
  double? get pagesPerDay {
    if (totalPages <= 0 || spanDays <= 0) return null;
    return totalPages / spanDays;
  }

  /// Okuma yapılan günlerdeki ortalama (motivasyon için; tahminde kullanılmaz).
  double? get pagesPerActiveDay {
    if (totalPages <= 0 || activeDays <= 0) return null;
    return totalPages / activeDays;
  }

  /// Okuma yapılan günlerdeki ortalama oturum süresi (dakika).
  double? get minutesPerActiveDay {
    if (totalMinutes <= 0 || activeDays <= 0) return null;
    return totalMinutes / activeDays;
  }

  bool get hasTimingData => pagesPerMinute != null;
  bool get isEmpty => sessionCount == 0;
}

/// Verilen günlük kayıtlarından tempo özeti çıkarır.
///
/// [today] testlerde sabitlenebilsin diye parametre; verilmezse bugündür.
ReadingPace computeReadingPace(List<BookLog> logs, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final reference = DateTime(now.year, now.month, now.day);

  var totalPages = 0;
  var timedPages = 0;
  var totalMinutes = 0;
  var timedSessions = 0;
  final days = <String>{};
  DateTime? first;
  DateTime? last;

  for (final log in logs) {
    final pages = log.pagesRead ?? 0;
    final minutes = log.durationMinutes;
    totalPages += pages;
    totalMinutes += minutes;

    if (minutes > 0 && pages > 0) {
      timedPages += pages;
      timedSessions++;
    }

    final date = parseYmd(log.logDate);
    if (date != null) {
      days.add(log.logDate);
      if (first == null || date.isBefore(first)) first = date;
      if (last == null || date.isAfter(last)) last = date;
    }
  }

  // Yayılım: ilk kayıttan bugüne. Kayıt bugünden ileri tarihliyse (kullanıcı
  // elle girmiş olabilir) son kayda kadar say.
  var spanDays = 1;
  if (first != null) {
    final end = (last != null && last.isAfter(reference)) ? last : reference;
    spanDays = end.difference(first).inDays + 1;
    if (spanDays < 1) spanDays = 1;
  }

  return ReadingPace(
    totalPages: totalPages,
    timedPages: timedPages,
    totalMinutes: totalMinutes,
    sessionCount: logs.length,
    timedSessionCount: timedSessions,
    activeDays: days.length,
    spanDays: spanDays,
    firstDate: first,
    lastDate: last,
  );
}

/// Bir kitabın ne zaman biteceğine dair tahmin.
class FinishEstimate {
  const FinishEstimate({
    required this.remainingPages,
    required this.date,
    required this.daysLeft,
    required this.minutesLeft,
  });

  /// Kalan sayfa.
  final int remainingPages;

  /// Tahmini bitiş günü. Tempo bilinmiyorsa null.
  final DateTime? date;

  /// Tahmini kalan gün. Tempo bilinmiyorsa null.
  final int? daysLeft;

  /// Kalan sayfanın tahmini okuma süresi (dakika). Hız bilinmiyorsa null.
  final int? minutesLeft;

  bool get hasDate => date != null;
}

/// Bitiş tahmininin hangi tempoya dayandığı.
enum PaceBasis {
  /// Okuma yapılan günlerin ortalaması. "Bundan sonra her gün okuyacağım"
  /// varsayımı — iyimser ama motive edici.
  activeDays,

  /// Başlangıçtan bugüne tüm takvim günleri; okumadığın günler de sayılır.
  /// Daha temkinli ve gerçekte olana daha yakın.
  calendarDays,
}

/// Kitabın bitiş tahmini. Kitap bitmişse ya da sayfa bilgisi yoksa null.
FinishEstimate? estimateFinish({
  required Book book,
  required ReadingPace pace,
  DateTime? today,
  PaceBasis basis = PaceBasis.calendarDays,
}) {
  if (book.isFinished) return null;
  if (book.totalPages <= 0) return null;

  final remaining = book.totalPages - book.currentPage;
  if (remaining <= 0) return null;

  final now = today ?? DateTime.now();
  final reference = DateTime(now.year, now.month, now.day);

  int? daysLeft;
  DateTime? date;
  final daily = switch (basis) {
    PaceBasis.activeDays => pace.pagesPerActiveDay,
    PaceBasis.calendarDays => pace.pagesPerDay,
  };
  if (daily != null && daily > 0) {
    daysLeft = (remaining / daily).ceil();
    // Çok uzak tahminler anlamını yitirir; 5 yılı aşarsa tarih vermiyoruz.
    if (daysLeft > 365 * 5) {
      daysLeft = null;
    } else {
      date = reference.add(Duration(days: daysLeft));
    }
  }

  int? minutesLeft;
  final speed = pace.pagesPerMinute;
  if (speed != null && speed > 0) {
    minutesLeft = (remaining / speed).ceil();
  }

  return FinishEstimate(
    remainingPages: remaining,
    date: date,
    daysLeft: daysLeft,
    minutesLeft: minutesLeft,
  );
}

/// "2 sa 15 dk" gibi okunur süre metni.
String formatMinutes(int minutes) {
  if (minutes < 1) return '1 dk\'dan az';
  if (minutes < 60) return '$minutes dk';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours < 24) {
    return rest == 0 ? '$hours sa' : '$hours sa $rest dk';
  }
  final days = hours ~/ 24;
  final restHours = hours % 24;
  return restHours == 0 ? '$days gün' : '$days gün $restHours sa';
}

/// Tahmini bitiş gününü insan diline çevirir.
String formatFinishDate(DateTime date, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final reference = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(reference).inDays;

  if (days <= 0) return 'bugün';
  if (days == 1) return 'yarın';
  if (days < 7) return '$days gün içinde';

  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final monthName = months[target.month - 1];
  if (target.year == reference.year) return '${target.day} $monthName';
  return '${target.day} $monthName ${target.year}';
}
