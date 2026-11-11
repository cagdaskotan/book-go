import 'package:flutter/material.dart';

import '../theme/app_scale.dart';

/// Uygulamanın alt sayfalarını (modal) tek bir iskeletten açar.
///
/// Flutter'ın `showModalBottomSheet` varsayılanı içeriği ekranın yarısıyla
/// sınırlıyor ve taşan kısmı **sessizce kırpıyor** — hata vermiyor, sadece
/// alttaki seçenek yarım görünüyor. "Kitap ekle" sayfasında seçenek sayısı
/// beşe çıkınca tam olarak bu oldu.
///
/// Ayrıca her çağrı yerinde köşe yarıçapı, tutamak, güvenli alan ve klavye
/// boşluğu elle yazılıyordu; biri unutulduğunda o modal diğerlerinden farklı
/// görünüyordu. Burası hepsini tek yerden veriyor.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required Widget child,

  /// İçerik uzunsa ekranın tamamına kadar büyüsün mü? Varsayılan olarak
  /// %92'ye kadar büyür ve taşarsa kaydırılır.
  double maxHeightFactor = .92,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // İkisi birden şart: biri olmadan içerik kırpılıyor ya da sistem
    // çubuğunun altında kalıyor.
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    builder: (_) => AppSheet(maxHeightFactor: maxHeightFactor, child: child),
  );
}

/// Alt sayfa kabuğu: tutamak, yuvarlatılmış üst köşeler, klavye boşluğu ve
/// taşınca kaydırma.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = .92,
    this.scrollable = true,
  });

  final Widget child;
  final double maxHeightFactor;

  /// İçerik kendi kaydırmasını yönetiyorsa (liste gibi) kapatılabilir.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: Radii.sheet,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(child: child)
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: cs.outlineVariant,
          borderRadius: Radii.brPill,
        ),
      ),
    );
  }
}

/// Alt sayfa başlığı — başlık, açıklama ve kapatma düğmesi.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: onClose ?? () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
