import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'book_cover.dart';

/// Raftaki kitap ile detay sayfası arasındaki açılış geçişi.
///
/// Aynı [tag]'i paylaşan iki [BookOpenHero] arasında kitap raftan çıkar,
/// ekranın ortasında **iki sayfalık bir yayılıma** açılır, sayfaları cilt
/// payından sağdan sola çevrilir, sonra kapanıp hedef kapağa oturur.
///
/// Önceki sürümde bu hareket okunmuyordu: yapraklar tam sayfa boyundaydı ve
/// kapakla aynı kenardan menteşeliydi, dolayısıyla tek bir kapak çırpınıyor
/// gibi görünüyordu — açık kitap hissi hiç oluşmuyordu.
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

/// Animasyonun zaman çizelgesi.
///
/// Tek yerde toplandı: hem uçuş dikdörtgeni hem kapak açılması hem sayfa
/// çevirme aynı eşikleri kullanmazsa hareket kendi içinde tutarsız görünüyor.
abstract final class _Beat {
  /// Raftan kalkıp ortadaki yayılım boyutuna büyür.
  static const double grow = .22;

  /// Kapak açılır (yayılım görünür hale gelir).
  static const double openEnd = .34;

  /// Sayfalar çevrilir — zamanın en büyük dilimi, anlatılan şey bu.
  static const double flipEnd = .66;

  /// Kapak kapanır.
  static const double closeEnd = .78;

  /// Hedef kapağa iner.
  static const double settle = .92;
}

/// Uçuş yolu: raftaki sırttan ortadaki açık yayılıma, oradan hedef kapağa.
class _BookArcRectTween extends RectTween {
  _BookArcRectTween(Rect? begin, Rect? end, this.screen)
    : super(begin: begin, end: end);

  final Size screen;

  /// Açık kitap yatay bir dikdörtgendir — kapalı kitabınkinden farklı oranda.
  /// Bu oran değişimi, "açıldı" hissinin yarısını tek başına taşıyor.
  Rect get _spread {
    final w = math.min(screen.width * .92, 520.0);
    final h = w * .66;
    return Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height * .40),
      width: w,
      height: h,
    );
  }

  @override
  Rect lerp(double t) {
    final from = begin ?? Rect.zero;
    final to = end ?? Rect.zero;

    if (t <= _Beat.grow) {
      return Rect.lerp(
        from,
        _spread,
        Curves.easeOutCubic.transform(t / _Beat.grow),
      )!;
    }
    if (t <= _Beat.closeEnd) return _spread;
    if (t <= _Beat.settle) {
      final local = (t - _Beat.closeEnd) / (_Beat.settle - _Beat.closeEnd);
      return Rect.lerp(
        _spread,
        to,
        Curves.easeInOutCubic.transform(local),
      )!;
    }
    // Son dilimde hedefte sabit dur; detay sayfası bu sırada belirir.
    return to;
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

  /// 0 = kapalı kapak, 1 = tamamen açık yayılım.
  double _openAmount(double t) {
    if (t <= _Beat.grow) return 0;
    if (t <= _Beat.openEnd) {
      final local = (t - _Beat.grow) / (_Beat.openEnd - _Beat.grow);
      return Curves.easeOutCubic.transform(local);
    }
    if (t <= _Beat.flipEnd) return 1;
    if (t <= _Beat.closeEnd) {
      final local = (t - _Beat.flipEnd) / (_Beat.closeEnd - _Beat.flipEnd);
      return 1 - Curves.easeInCubic.transform(local);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        final open = _openAmount(t);

        // Sayfa çevirme yalnızca kitap açıkken ve kendi penceresinde akar.
        final flip = t <= _Beat.openEnd || t > _Beat.flipEnd
            ? (t > _Beat.flipEnd ? 1.0 : 0.0)
            : (t - _Beat.openEnd) / (_Beat.flipEnd - _Beat.openEnd);

        return _BookBody(
          open: open,
          flip: flip.clamp(0.0, 1.0),
          coverUrl: coverUrl,
          spineColor: spineColor,
        );
      },
    );
  }
}

class _BookBody extends StatelessWidget {
  const _BookBody({
    required this.open,
    required this.flip,
    required this.coverUrl,
    required this.spineColor,
  });

  /// 0 kapalı, 1 açık.
  final double open;

  /// Sayfa çevirme ilerlemesi (0–1).
  final double flip;

  final String? coverUrl;
  final Color spineColor;

  /// Aynı anda havada olan yaprak sayısı yerine toplam çevrilen yaprak.
  static const int _leafCount = 7;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final half = w / 2;
        final radius = BorderRadius.circular(math.min(w * .035, 10));

        // Kapak kapalıyken tüm dikdörtgeni kaplar; açılırken sol yarıya
        // menteşelenip dışarı döner. Böylece altından iki sayfalık yayılım
        // çıkar — kapalı kitapla aynı dikdörtgen değil.
        final coverAngle = open * math.pi * .92;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // --- Açık yayılım (kapak açıldıkça görünür) ---
            if (open > 0.02) ...[
              Positioned.fill(child: _spread(w, h, radius)),
              ..._turningLeaves(half, h),
              // Cilt payı gölgesi: iki sayfanın birleştiği yer. Açık kitabı
              // "tek bir kâğıt" olmaktan çıkaran ayrıntı bu.
              Positioned(
                left: half - w * .035,
                top: 0,
                bottom: 0,
                width: w * .07,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .30 * open),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // --- Ön kapak: sol kenardan menteşeli ---
            Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0014)
                ..rotateY(-coverAngle),
              child: SizedBox(
                width: open > 0.02 ? w / 2 : w,
                height: h,
                child: _cover(radius, open),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Açık kitabın iki sayfası.
  Widget _spread(double w, double h, BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: const Color(0xFFFBF7EC),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .34),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          children: [
            Expanded(child: _page(alignRight: true)),
            Expanded(child: _page(alignRight: false)),
          ],
        ),
      ),
    );
  }

  /// Tek bir sayfa: kâğıt tonu, cilt payına doğru koyulaşan gölge ve
  /// okunurluğu ima eden satır izleri.
  Widget _page({required bool alignRight}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignRight ? Alignment.centerLeft : Alignment.centerRight,
          end: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [Color(0xFFFDFAF2), Color(0xFFEFE7D5)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 9; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: i == 8 ? .52 : (i.isEven ? .95 : .88),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Cilt payından menteşelenip sağdan sola çevrilen yapraklar.
  ///
  /// Kritik fark: yaprak **yarım sayfa** genişliğinde ve menteşesi ortada.
  /// Gerçek kitapta sayfa oradan döner; tam sayfa boyunda bir yaprak sol
  /// kenardan dönünce kapak gibi görünüyordu.
  List<Widget> _turningLeaves(double half, double h) {
    if (open < .9) return const [];
    final out = <Widget>[];

    for (var i = 0; i < _leafCount; i++) {
      // Yapraklar sırayla kalkar; birkaçı aynı anda havada olur.
      final start = i / (_leafCount + 1.6);
      final local = ((flip - start) * 3.2).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;

      final angle = Curves.easeInOut.transform(local) * math.pi;
      // Dönen yüzün ışığa göre koyulaşması — hacim hissi.
      final shade = math.sin(angle).abs();
      final isBackFace = angle > math.pi / 2;

      out.add(
        Positioned(
          left: half,
          top: h * .012,
          width: half,
          height: h * .976,
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(-angle),
            child: Transform(
              alignment: Alignment.center,
              // Arka yüz aynalanır ki yazı izleri ters akmasın.
              transform: isBackFace
                  ? (Matrix4.identity()..rotateY(math.pi))
                  : Matrix4.identity(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _page(alignRight: isBackFace),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .34 * shade),
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
    return out;
  }

  /// Kitabın ön kapağı. Açılırken dış yüzü döner, iç yüzü görünür.
  Widget _cover(BorderRadius radius, double open) {
    final showInside = open > .52;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (showInside)
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: _coverInside(radius),
          )
        else
          _coverOutside(radius),
        // Açıldıkça kapak ışıktan uzaklaşır.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Colors.black.withValues(
                alpha: .40 * math.sin(open * math.pi).abs(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coverOutside(BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .38),
            blurRadius: 14,
            offset: const Offset(5, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: spineColor),
            // CachedCover hem internetten gelen kapağı hem kullanıcının
            // çektiği fotoğrafı gösterebiliyor.
            CachedCover(url: coverUrl, iconColor: Colors.white70),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: .20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kapağın iç yüzü — kâğıt kaplama, hafif dokulu.
  Widget _coverInside(BorderRadius radius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0E9D8), Color(0xFFDFD4BA)],
        ),
      ),
    );
  }
}
