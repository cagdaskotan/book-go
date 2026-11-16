import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/cover_photo_service.dart';

/// Kitap kapağı görseli.
///
/// İki kaynağı birden kaldırır: internetten gelen kapaklar önbelleğe alınır
/// (her açılışta yeniden inmez), kullanıcının kendi çektiği kapaklar ise
/// cihazdan okunur. Türkçe baskıların çoğunda çevrimiçi kapak bulunmadığı
/// için ikincisi istisna değil, sık kullanılan yol.
///
/// Kapak yoksa (ya da inmezse) yerine **üretilmiş bir cilt** konuyor:
/// kitabın adından türetilen sabit bir renk ve üzerinde başlık. Eskiden
/// burada tek bir kitap ikonu vardı; Türkçe baskıların çoğunda çevrimiçi
/// kapak bulunmadığı için kitaplık aynı ikonun tekrarına dönüşüyordu ve
/// hiçbir kitap diğerinden ayırt edilemiyordu. Üretilmiş cilt hem rafa
/// benziyor hem de aynı kitap her yerde aynı renkte çıkıyor.
class CachedCover extends StatelessWidget {
  const CachedCover({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 24,
    this.iconColor,
    this.title,
  });

  final String? url;
  final BoxFit fit;
  final double iconSize;
  final Color? iconColor;

  /// Kapak yoksa cilde yazılacak ad. Verilmezse yalnızca ikon çıkar.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = (url ?? '').trim();
    final name = (title ?? '').trim();
    final icon = name.isEmpty
        ? Center(
            child: Icon(
              Icons.menu_book_rounded,
              color: iconColor ?? cs.primary,
              size: iconSize,
            ),
          )
        : GeneratedCover(title: name, compact: iconSize < 26);
    if (u.isEmpty) return icon;

    // Kullanıcının kendi çektiği kapak: diskten oku.
    if (CoverPhotoService.isLocalPath(u)) {
      return Image.file(File(u), fit: fit, errorBuilder: (_, __, ___) => icon);
    }

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

/// Kapağı olmayan kitap için üretilmiş cilt.
///
/// Renk kitabın adından türetiliyor; aynı kitap uygulamanın her yerinde aynı
/// renkte çıkıyor ve iki kitap yan yana geldiğinde ayırt edilebiliyor. Palet
/// rafın sırt renkleriyle aynı — üretilmiş kapak rafa yabancı durmasın.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({super.key, required this.title, this.compact = false});

  final String title;

  /// Küçük kutularda (liste satırı gibi) yazı yerine yalnızca baş harf.
  final bool compact;

  /// Rafın sırt paletiyle aynı renkler.
  static const List<Color> _palette = [
    Color(0xFF5B4B8A),
    Color(0xFFB85C74),
    Color(0xFF367C75),
    Color(0xFFC77D3B),
    Color(0xFF426B9B),
    Color(0xFF8A5A34),
  ];

  /// Addan sabit bir renk: aynı kitap her açılışta aynı renkte.
  static Color colorOf(String title) {
    var hash = 0;
    for (final unit in title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final base = colorOf(title);
    final initial = title.characters.isEmpty
        ? '?'
        : title.characters.first.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, Color.lerp(base, Colors.black, .28)!],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Sırttaki cilt çizgisi: dar bir şerit kitabın yönünü belli eder.
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: .13,
              child: ColoredBox(color: Colors.black.withValues(alpha: .22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Align(
              alignment: compact ? Alignment.center : Alignment.bottomLeft,
              child: compact
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    )
                  : Text(
                      title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .94),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        height: 1.25,
                        letterSpacing: -.1,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
