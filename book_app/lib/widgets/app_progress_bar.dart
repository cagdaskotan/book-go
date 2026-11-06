import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = value.clamp(0.0, 1.0);
    final effectiveHeight = showLabel ? height.clamp(18.0, 28.0) : height;

    return Semantics(
      label: 'Okuma ilerlemesi',
      value: '${(progress * 100).round()}%',
      child: ClipRRect(
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
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
                              fontWeight: FontWeight.w900,
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
      ),
    );
  }
}
