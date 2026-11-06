import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Önbellekli kitap kapağı görseli. Disk + bellek önbelleği kullanır;
/// böylece kapaklar her açılışta yeniden indirilmez (veri/performans kazancı).
///
/// Boş URL → kitap ikonu; yükleme → soluk arka plan; hata → kitap ikonu.
class CachedCover extends StatelessWidget {
  const CachedCover({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 24,
    this.iconColor,
  });

  final String? url;
  final BoxFit fit;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = (url ?? '').trim();
    final icon = Center(
      child: Icon(
        Icons.menu_book_rounded,
        color: iconColor ?? cs.primary,
        size: iconSize,
      ),
    );
    if (u.isEmpty) return icon;

    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Center(
        child: SizedBox(
          width: iconSize * .8,
          height: iconSize * .8,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: (iconColor ?? cs.primary).withValues(alpha: .5),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => icon,
    );
  }
}
