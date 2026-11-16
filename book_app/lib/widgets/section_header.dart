import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import '../theme/app_type.dart';

/// Bölüm başlığı.
///
/// Her sayfa kendi başlığını farklı yazmıştı: ana sayfada 17.5 punto ve
/// renkli ikon kutusu, istatistiklerde `titleLarge` ve ikon yok, alıntı
/// defterinde başka. Aynı rolü üstlenen şeyler farklı göründüğünde sayfalar
/// birbirinin devamı gibi okunmuyor.
///
/// [icon] isteğe bağlı: başlığın yanında küçük renkli bir kutu, sayfayı
/// tararken bölüm sınırlarını belli ediyor.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(Gap.xs, Gap.xl, 0, Gap.sm),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// İkon kutusunun rengi — verilmezse marka rengi.
  final Color? accent;

  /// Sağ uçtaki eylem ("Tümünü gör" gibi).
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = accent ?? cs.primary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: Radii.brSm,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            Gap.hMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppType.sectionTitle.withColor(cs.onSurface),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppType.labelSmall.withColor(cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
