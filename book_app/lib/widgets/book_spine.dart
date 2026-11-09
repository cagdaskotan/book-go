import 'package:flutter/material.dart';

import '../models/book.dart';
import 'book_open_hero.dart';

/// Rafta duran bir kitabın sırtı.
///
/// Uygulamanın en ayırt edici görseli bu: sırt kalınlığı sayfa sayısından
/// geliyor (ince kitap ince sırt), silindirik parlama ciltli kitap hissi
/// veriyor, başlık altın çerçeveli plakada dik yazılıyor. Rakiplerin hepsi
/// kitapları ızgara listesinde gösteriyor; bizim rafımız gerçek bir rafa
/// benziyor.
///
/// Hem raf ekranında hem ana ekrandaki şeritte kullanılıyor — iki ayrı kopya
/// tutmamak için buraya çıkarıldı.

Color spineBaseColor(Book book, Color shelfColor) {
  final seed = book.id.abs();
  const palette = <Color>[
    Color(0xFF5B4B8A),
    Color(0xFFB85C74),
    Color(0xFF367C75),
    Color(0xFFC77D3B),
    Color(0xFF426B9B),
    Color(0xFF8A5A34),
  ];
  return Color.lerp(palette[seed % palette.length], shelfColor, .30)!;
}

class BookSpine extends StatelessWidget {
  const BookSpine({
    super.key,
    required this.book,
    required this.base,
    required this.index,
    required this.tag,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final Color base;
  final int index;
  final String tag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final seed = book.id.abs() + index;
    // Kalınlık (sırt genişliği) doğrudan sayfa sayısından: ince kitap ince sırt.
    final thick = book.totalPages <= 0
        ? 0.30
        : (book.totalPages.clamp(60, 900) - 60) / 840; // 0..1
    final width = 30.0 + thick * 34 + (seed % 3); // ~30–66
    final pageHeight = book.totalPages <= 0
        ? 0
        : (book.totalPages.clamp(80, 800) - 80) / 720;
    final height = 124.0 + (pageHeight * 40) + (seed % 9);
    final labelLen = (height - 66).clamp(50.0, 240.0);
    final progress = book.totalPages <= 0
        ? 0.0
        : (book.currentPage / book.totalPages).clamp(0.0, 1.0);
    final gold = Color.lerp(base, const Color(0xFFF2D79A), .72)!;
    final inset = Color.lerp(base, Colors.black, .34)!;
    return BookOpenHero(
      bookId: book.id,
      tag: tag,
      coverUrl: book.coverUrl,
      spineColor: base,
      finished: book.isFinished,
      child: Semantics(
        button: true,
        label: book.title,
        child: Tooltip(
          message: book.title,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: base,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .38),
                    blurRadius: 5,
                    offset: const Offset(3, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Silindirik parlama — yuvarlak cilt sırtı hissi
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: .34),
                            Colors.black.withValues(alpha: .06),
                            Colors.white.withValues(alpha: .20),
                            Colors.black.withValues(alpha: .10),
                            Colors.black.withValues(alpha: .40),
                          ],
                          stops: const [0, .22, .5, .78, 1],
                        ),
                      ),
                    ),
                  ),
                  // Baş kapağı (üst kenar)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 4,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: .22),
                    ),
                  ),
                  // Üst kabartma hub bandı
                  Positioned(top: 13, left: 0, right: 0, child: _hub()),
                  // Altın çerçeveli başlık plakası (kabartma)
                  Positioned(
                    top: 24,
                    bottom: 30,
                    left: 4,
                    right: 4,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: inset.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: gold.withValues(alpha: .85),
                          width: 1,
                        ),
                      ),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SizedBox(
                          width: labelLen,
                          child: Text(
                            book.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: gold,
                              fontSize: 8.5,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .2,
                              shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 1.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Alt kabartma hub bandı
                  Positioned(bottom: 20, left: 0, right: 0, child: _hub()),
                  // Yazar (rotasyonlu, küçük)
                  if ((book.author ?? '').trim().isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      height: 12,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            book.author!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: gold.withValues(alpha: .8),
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (book.favorite)
                    Positioned(
                      top: 5,
                      right: 3,
                      child: Icon(
                        Icons.star_rounded,
                        size: 10,
                        color: gold,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 2),
                        ],
                      ),
                    ),
                  // İlerleme (etek)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      alignment: Alignment.centerLeft,
                      color: Colors.black.withValues(alpha: .3),
                      child: FractionallySizedBox(
                        widthFactor: book.isFinished ? 1 : progress,
                        child: Container(color: const Color(0xFF9EF0C5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Cilt sırtındaki kabartma yatay bant.
  Widget _hub() {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: .32),
            Colors.white.withValues(alpha: .18),
            Colors.black.withValues(alpha: .30),
          ],
          stops: const [0, .5, 1],
        ),
      ),
    );
  }
}
