import 'package:flutter/material.dart';

import '../theme/app_scale.dart';

/// Uygulamanın kart yüzeyi.
///
/// Bu bileşen yokken her sayfa kendi `_SurfaceCard`'ını yazmıştı: beş ayrı
/// özel sınıf, beş ayrı gölge ve kenarlık. Zamanla birbirlerinden ayrıştılar
/// ve ekranlar arasında kart görünümü tutmaz oldu. Tek kaynak burası.
///
/// Üç seviye var çünkü her kart aynı ağırlıkta değil:
///
/// * [AppCardLevel.flat] — sayfanın parçası olan sakin kutu.
/// * [AppCardLevel.raised] — dikkat isteyen kart (okumaya devam, kutlama).
/// * [AppCardLevel.tinted] — markanın rengini taşıyan, zeminden ayrışan kart.
enum AppCardLevel { flat, raised, tinted }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.level = AppCardLevel.flat,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.color,
    this.radius = Radii.lg,
    this.border,
  });

  final Widget child;
  final AppCardLevel level;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Kartın kendi rengi — verilmezse seviyeye göre seçilir.
  final Color? color;

  final double radius;

  /// Kenarlık. Varsayılan olarak yok: ılık zeminde beyaz kart zaten
  /// ayrışıyor, üstüne çizgi koymak 2018 görünümü veriyor.
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background =
        color ??
        switch (level) {
          AppCardLevel.flat => cs.surface,
          AppCardLevel.raised => cs.surface,
          AppCardLevel.tinted => cs.primary.withValues(
            alpha: isDark ? .16 : .07,
          ),
        };

    // Koyu temada gölge iş görmüyor — zemin zaten koyu. Orada ayrımı
    // yüzey tonu ve ince bir kenarlık yapıyor.
    final shadows = isDark
        ? null
        : switch (level) {
            AppCardLevel.flat => Shadows.card,
            AppCardLevel.raised => Shadows.raised,
            AppCardLevel.tinted => Shadows.card,
          };

    final effectiveBorder =
        border ?? (isDark ? Border.all(color: cs.outlineVariant) : null);

    final body = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
        border: effectiveBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );

    return body;
  }
}
