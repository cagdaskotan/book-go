import 'package:flutter/material.dart';

/// Puanlama: 5 yıldız, yarım adımlarla.
///
/// Veritabanında puan 0–100 olarak duruyor (geçmiş kayıtlarla uyumlu kalsın
/// diye değiştirmedik) ama kullanıcıya hiçbir zaman "73/100" gösterilmiyor —
/// kimse kitaba 73 vermiyor. Her yarım yıldız 10 puan: 4,5 yıldız = 90.
///
/// Yarım yıldız şart: beş tam adım, bir kitabı "iyi ama şaheser değil" diye
/// ayırmaya yetmiyor; StoryGraph ve Hardcover da yarım yıldız kullanıyor.
abstract final class StarRating {
  /// Bir yıldızın puan karşılığı.
  static const int pointsPerStar = 20;

  /// 0–100 puanı yıldıza çevirir (0–5, yarım adımlarla).
  static double starsOf(int? rating) {
    if (rating == null) return 0;
    return ((rating / pointsPerStar) * 2).round() / 2;
  }

  /// Yıldızı 0–100 puana çevirir.
  static int pointsOf(double stars) => (stars * pointsPerStar).round();

  /// "4,5" / "4" biçiminde okunur metin (Türkçe ondalık ayracı virgül).
  static String label(int? rating) {
    final stars = starsOf(rating);
    if (stars == stars.roundToDouble()) return stars.toInt().toString();
    return stars.toStringAsFixed(1).replaceAll('.', ',');
  }
}

/// Puanı yalnızca gösterir (dokunulamaz).
class StarRatingView extends StatelessWidget {
  const StarRatingView({
    super.key,
    required this.rating,
    this.size = 18,
    this.color = const Color(0xFFF59E0B),
    this.emptyColor,
    this.showLabel = false,
  });

  final int? rating;
  final double size;
  final Color color;
  final Color? emptyColor;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final stars = StarRating.starsOf(rating);
    final empty =
        emptyColor ?? Theme.of(context).colorScheme.outlineVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            stars >= i
                ? Icons.star_rounded
                : (stars >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded),
            size: size,
            color: stars >= i - 0.5 ? color : empty,
          ),
        if (showLabel && rating != null) ...[
          SizedBox(width: size * .35),
          Text(
            StarRating.label(rating),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: size * .78,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

/// Dokunarak puan verme — yıldızın sol yarısı yarım, sağ yarısı tam puan.
///
/// Aynı değere tekrar dokunmak puanı kaldırır; kullanıcı yanlışlıkla verdiği
/// puandan dönebilmeli.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
    this.starSize = 34,
  });

  final int? rating;
  final ValueChanged<int?> onChanged;
  final bool enabled;
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stars = StarRating.starsOf(rating);

    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          _StarTarget(
            index: i,
            current: stars,
            size: starSize,
            enabled: enabled,
            color: enabled ? const Color(0xFFF59E0B) : cs.outlineVariant,
            onPick: (value) {
              // Aynı değere tekrar dokunmak puanı kaldırır.
              final next = value == stars ? null : StarRating.pointsOf(value);
              onChanged(next);
            },
          ),
        const Spacer(),
        if (rating != null)
          Text(
            StarRating.label(rating),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: cs.onSurface,
            ),
          )
        else
          Text(
            'Puan yok',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Tek yıldızın dokunma alanı: sol yarı = x,5 · sağ yarı = x,0.
///
/// Dokunma hedefi en az 48 piksel yükseklikte tutuluyor (erişilebilirlik).
class _StarTarget extends StatelessWidget {
  const _StarTarget({
    required this.index,
    required this.current,
    required this.size,
    required this.enabled,
    required this.color,
    required this.onPick,
  });

  final int index;
  final double current;
  final double size;
  final bool enabled;
  final Color color;
  final ValueChanged<double> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = current >= index
        ? Icons.star_rounded
        : (current >= index - 0.5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded);

    return SizedBox(
      width: size + 8,
      height: 48,
      child: Semantics(
        button: true,
        label: '$index yıldız',
        child: Stack(
          children: [
            Center(
              child: Icon(
                icon,
                size: size,
                color: current >= index - 0.5 ? color : cs.outlineVariant,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onPick(index - 0.5) : null,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onPick(index.toDouble()) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
