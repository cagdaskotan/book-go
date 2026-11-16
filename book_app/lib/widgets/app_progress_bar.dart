import 'package:flutter/material.dart';

/// Okuma ilerlemesi çubuğu.
///
/// Çubuk ve yüzde etiketi **tek bir animasyondan** beslenir: sayfa
/// kaydedildiğinde çubuk kayarken sayı da sayarak yükselir. Daha önce çubuk
/// akıcı, sayı anlıktı; göz bu uyumsuzluğu "bitmemiş" diye okuyor.
///
/// Sistemde "animasyonları azalt" açıksa değer anında yerine oturur.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.showLabel = true,
    this.gradient,
    this.trackColor,
    this.labelStyle,
  });

  final double value;
  final double height;
  final bool showLabel;
  final Gradient? gradient;
  final Color? trackColor;
  final TextStyle? labelStyle;

  static const Duration _duration = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Okuma ilerlemesi',
      value: '${(target * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: target, end: target),
        duration: reduceMotion ? Duration.zero : _duration,
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => _bar(context, progress),
      ),
    );
  }

  Widget _bar(BuildContext context, double progress) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final effectiveHeight = showLabel ? height.clamp(18.0, 28.0) : height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveHeight),
      child: SizedBox(
        height: effectiveHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color:
                    trackColor ??
                    cs.surfaceContainerHighest.withValues(alpha: .82),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                    gradient:
                        gradient ??
                        LinearGradient(colors: [cs.primary, cs.secondary]),
                    borderRadius: BorderRadius.circular(effectiveHeight),
                  ),
                ),
              ),
              if (showLabel)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(effectiveHeight),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: .45),
                      ),
                    ),
                    child: Text(
                      '${(progress * 100).round()}%',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: (labelStyle ?? theme.textTheme.labelMedium)
                          ?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            shadows: null,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
