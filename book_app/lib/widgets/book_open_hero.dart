import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Raftaki kitap ile detay sayfasının kapağı arasındaki imza geçişi.
///
/// Aynı [tag]'i paylaşan iki [BookOpenHero] arasında, kitap raftan çıkıp
/// ekranın ortasına doğru büyür, 3B perspektifle kapağını açıp sayfalarını
/// hızlıca çevirir, sonra kapanarak hedef kapağa oturur. Geri dönüşte tersi
/// otomatik oynar.
class BookOpenHero extends StatelessWidget {
  const BookOpenHero({
    super.key,
    required this.bookId,
    required this.coverUrl,
    required this.spineColor,
    required this.child,
    this.tag,
    this.finished = false,
  });

  final int bookId;
  final String? coverUrl;
  final Color spineColor;
  final Widget child;

  /// Aynı kitap birden çok rafta görünebildiği için çağıran taraf benzersiz
  /// bir etiket verebilir; verilmezse varsayılan `book-cover-$id` kullanılır.
  final Object? tag;
  final bool finished;

  static Object defaultTag(int id) => 'book-cover-$id';

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Hero(
      tag: tag ?? defaultTag(bookId),
      createRectTween: (begin, end) => _BookArcRectTween(begin, end, screen),
      flightShuttleBuilder: (flightCtx, animation, dir, fromCtx, toCtx) {
        return _OpeningBook(
          animation: animation,
          direction: dir,
          coverUrl: coverUrl,
          spineColor: spineColor,
        );
      },
      child: child,
    );
  }
}

/// Uçuş yolu: önce ekranın ortasındaki büyük "okuma" boyutuna yumuşakça büyür,
/// orada bir süre kalır (sayfalar çevrilir), sonra hedef kapağa yumuşakça iner.
/// Geçişler easeInOut olduğu için hiçbir aşamada sıçrama/kesinti olmaz.
/// Uçuş yolu: kitap önce ekranın ortasındaki büyük "okuma" boyutuna büyür,
/// orada bir süre kalır (sayfalar çevrilir), sonra hedef kapağa iner ve
/// son dilimde orada SABİT durur (detay sayfası o sırada açılır).
class _BookArcRectTween extends RectTween {
  _BookArcRectTween(Rect? begin, Rect? end, this.screen)
    : super(begin: begin, end: end);

  final Size screen;

  Rect get _mid {
    final w = screen.width * 0.88;
    final h = w * 1.16;
    return Rect.fromCenter(
      center: Offset(screen.width * 0.5, screen.height * 0.40),
      width: w,
      height: h,
    );
  }

  @override
  Rect lerp(double t) {
    final b = begin ?? Rect.zero;
    final e = end ?? Rect.zero;
    const grow = 0.28, hold = 0.55, settle = 0.80;
    if (t <= grow) {
      return Rect.lerp(b, _mid, Curves.easeOutCubic.transform(t / grow))!;
    }
    if (t <= hold) return _mid;
    if (t <= settle) {
      return Rect.lerp(
        _mid,
        e,
        Curves.easeInOutCubic.transform((t - hold) / (settle - hold)),
      )!;
    }
    return e; // 0.80 → 1.0: kapakta sabit dur, detay sayfası açılırken
  }
}

class _OpeningBook extends StatelessWidget {
  const _OpeningBook({
    required this.animation,
    required this.direction,
    required this.coverUrl,
    required this.spineColor,
  });

  final Animation<double> animation;
  final HeroFlightDirection direction;
  final String? coverUrl;
  final Color spineColor;

  // Büyürken açılır, ortada açık kalır (sayfalar akıp giderken), sonra
  // inişten önce kapanır — inişin sonunda kapalı kapak olarak oturur.
  double _openAmount(double t) {
    if (t < 0.12) return 0;
    if (t < 0.30) return Curves.easeInOutCubic.transform((t - 0.12) / 0.18);
    if (t < 0.52) return 1;
    if (t < 0.72) return 1 - Curves.easeInOutCubic.transform((t - 0.52) / 0.20);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        final open = _openAmount(t);
        // Sayfa akışı açık-kalma penceresine yayılır (güzelce çevrilir).
        final pageTurn = Curves.easeInOut.transform(
          ((t - .14) / .40).clamp(0.0, 1.0),
        );
        final book = _BookBody(
          open: open,
          pageTurn: pageTurn,
          coverUrl: coverUrl,
          spineColor: spineColor,
        );

        // İnişe yaklaşırken temiz kapağa yumuşakça karış (sert kesme/kırmızı yok).
        final landing = direction == HeroFlightDirection.push ? t : (1 - t);
        final fade = ((landing - 0.80) / 0.14).clamp(0.0, 1.0);
        if (fade <= 0) return book;
        return Stack(
          fit: StackFit.expand,
          children: [
            book,
            Opacity(
              opacity: Curves.easeInOut.transform(fade),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: spineColor),
                    if ((coverUrl ?? '').isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BookBody extends StatelessWidget {
  const _BookBody({
    required this.open,
    required this.pageTurn,
    required this.coverUrl,
    required this.spineColor,
  });

  final double open;
  final double pageTurn;
  final String? coverUrl;
  final Color spineColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final radius = BorderRadius.circular(math.min(w * 0.07, 14));
        final coverDeg = open * 166.0; // 0 (kapalı) → 166 (açık)
        final showBack = coverDeg > 90;
        final coverShade = math.sin(coverDeg * math.pi / 180).abs();
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Sayfa bloğu — dikdörtgeni doldurur (kapak açılınca görünür)
              Positioned.fill(child: _pages(w, h, radius)),
              // Riffling yapraklar
              ..._leaves(w, h, radius),
              // Ön kapak — sol kenardan (sırt) menteşeli; dikdörtgeni doldurur
              Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(-coverDeg * math.pi / 180),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      showBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _coverBack(radius),
                            )
                          : _coverFront(w, h, radius),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            color: Colors.black.withValues(
                              alpha: .42 * coverShade,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pages(double w, double h, BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBF7EC), Color(0xFFF1EAD8)],
        ),
      ),
      child: Stack(
        children: [
          // Cilt payı gölgesi (sol)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: w * 0.16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: .22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Sayfa kenarı çizgileri (sağ)
          Positioned(
            right: w * 0.05,
            top: h * 0.1,
            bottom: h * 0.1,
            child: Row(
              children: List.generate(
                3,
                (_) => Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 1.4),
                  color: Colors.black.withValues(alpha: .06),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _leaves(double w, double h, BorderRadius radius) {
    // Çok sayıda yaprak sağdan sola süzülerek çevrilir — sürekli akan riffle.
    const n = 12;
    final out = <Widget>[];
    for (var i = 0; i < n; i++) {
      final lp = ((pageTurn * (n + 2)) - i).clamp(0.0, 1.0);
      if (lp <= 0 || lp >= 1) continue;
      final deg = Curves.easeInOut.transform(lp) * 168;
      final shade = math.sin(deg * math.pi / 180).abs();
      out.add(
        Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(-deg * math.pi / 180),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFFCF8EE), Color(0xFFEFE7D3)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    color: Colors.black.withValues(alpha: .4 * shade),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _coverFront(double w, double h, BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .38),
            blurRadius: 11,
            offset: const Offset(5, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Sırt rengi taban — kapak yüklenene kadar bile boşluk görünmez
            ColoredBox(color: spineColor),
            // Kapak fotoğrafı dikdörtgeni DOLDURUR (cover) — boş renkli kutu yok
            if ((coverUrl ?? '').isNotEmpty)
              CachedNetworkImage(
                imageUrl: coverUrl!,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => ColoredBox(color: spineColor),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            // Sırt vurgusu (sol)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w * 0.1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: .22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Diyagonal parlama
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .14),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .12),
                    ],
                    stops: const [0, .5, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverBack(BorderRadius radius) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFE8D6), Color(0xFFE2D8C0)],
        ),
        border: Border.all(color: Colors.black.withValues(alpha: .10)),
      ),
    );
  }
}
