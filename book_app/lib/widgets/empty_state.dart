import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import 'mascot.dart';

/// Boş ekranların tek kaynağı.
///
/// Boş bir liste, kullanıcının bir şeyi yanlış yaptığı an değil; henüz
/// başlamadığı an. O yüzden her boş ekran bir davet: ne olduğunu söyler, ne
/// kazandıracağını anlatır ve mümkünse doğrudan düğmesini önüne koyar.
///
/// Maskot Bilge burada bilinçli olarak var: boş ekran, karakterin görünmesi
/// için doğru yer — kullanıcı o an bir şey okumuyor, yönlendirilmeye açık.
/// Dolu ekranlarda Bilge ortalıkta dolaşmıyor; sessiz bir refakatçi.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.mood = MascotMood.encourage,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  /// Tek satırlık durum başlığı — "Rafın boş duruyor" gibi, suçlamadan.
  final String title;

  /// İki satırı geçmeyen açıklama: ne olacağını ve neye yaradığını söyler.
  final String message;

  /// Bilge'nin ruh hâli. Bekleyen bir boşluk için [MascotMood.encourage],
  /// okumaya dair bir boşluk için [MascotMood.reading] uygun.
  final MascotMood mood;

  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Kart içine gömülen küçük boşluklar için (örneğin alıntı bölümü).
  final bool compact;

  bool get _hasAction => actionLabel != null && onAction != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mascotSize = compact ? 72.0 : 104.0;

    return Padding(
      padding: EdgeInsets.all(compact ? Gap.lg : Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mascot(mood: mood, size: mascotSize),
          SizedBox(height: compact ? Gap.sm : Gap.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: compact ? 15.5 : 17,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12.5 : 13.5,
            ),
          ),
          if (_hasAction) ...[
            SizedBox(height: compact ? Gap.md : Gap.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add_rounded),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
