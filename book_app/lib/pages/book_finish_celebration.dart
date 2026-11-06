import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/book.dart';
import '../widgets/book_cover.dart';

/// Bir kitap bittiğinde açılan tam ekran kutlama sahnesi.
class BookFinishCelebration extends StatefulWidget {
  const BookFinishCelebration({
    super.key,
    required this.book,
    required this.daysToFinish,
    required this.yearlyFinished,
    required this.yearlyGoal,
    this.level,
    this.totalPagesAllTime,
  });

  final Book book;
  final int? daysToFinish;
  final int yearlyFinished;
  final int yearlyGoal;
  final int? level;
  final int? totalPagesAllTime;

  @override
  State<BookFinishCelebration> createState() => _BookFinishCelebrationState();
}

class _BookFinishCelebrationState extends State<BookFinishCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();

  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  late final List<_Confetto> _pieces = _buildConfetti();
  late final List<_SparkParticle> _sparks = _buildSparks();
  late final List<_SpeedLine> _speedLines = _buildSpeedLines();
  late final List<_Star> _stars = _buildStars();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _flight.dispose();
    _ambient.dispose();
    super.dispose();
  }

  List<_Confetto> _buildConfetti() {
    final rnd = math.Random(7);
    const colors = [
      Color(0xFF7C5CFF),
      Color(0xFFB56BFF),
      Color(0xFFFFC65B),
      Color(0xFF52E0B7),
      Color(0xFFFF7AAE),
      Color(0xFF73D2FF),
    ];
    return List.generate(120, (_) {
      return _Confetto(
        x: rnd.nextDouble(),
        delay: .50 + rnd.nextDouble() * .30,
        speed: .95 + rnd.nextDouble() * .95,
        drift: (rnd.nextDouble() - .5) * .5,
        size: 5 + rnd.nextDouble() * 9,
        color: colors[rnd.nextInt(colors.length)],
        rotation: rnd.nextDouble() * math.pi,
        rotationSpeed: (rnd.nextDouble() - .5) * 9,
        square: rnd.nextBool(),
      );
    });
  }

  List<_SparkParticle> _buildSparks() {
    final rnd = math.Random(24);
    const colors = [
      Color(0xFFFFD166),
      Color(0xFF73D2FF),
      Color(0xFFB56BFF),
      Color(0xFF52E0B7),
      Color(0xFFFF7AAE),
    ];
    return List.generate(44, (index) {
      return _SparkParticle(
        angle: rnd.nextDouble() * math.pi * 2,
        distance: 44 + rnd.nextDouble() * 210,
        delay: rnd.nextDouble() * .22,
        size: 2.5 + rnd.nextDouble() * 6,
        color: colors[index % colors.length],
        spin: (rnd.nextDouble() - .5) * math.pi,
      );
    });
  }

  List<_Star> _buildStars() {
    final rnd = math.Random(91);
    return List.generate(110, (_) {
      return _Star(
        x: rnd.nextDouble(),
        y: rnd.nextDouble() * .72, // üst kısımda yoğun
        size: .6 + rnd.nextDouble() * 2.0,
        twinklePhase: rnd.nextDouble(),
        twinkleSpeed: .6 + rnd.nextDouble() * 1.8,
        warm: rnd.nextDouble() < .35,
      );
    });
  }

  List<_SpeedLine> _buildSpeedLines() {
    final rnd = math.Random(55);
    const colors = [
      Color(0xFFFFD166),
      Color(0xFF73D2FF),
      Color(0xFFFF7AAE),
      Color(0xFFB56BFF),
      Color(0xFF52E0B7),
    ];
    return List.generate(150, (index) {
      return _SpeedLine(
        angle: -math.pi / 2 + (rnd.nextDouble() - .5) * .9,
        lane: rnd.nextDouble(),
        length: 90 + rnd.nextDouble() * 280,
        width: 1.3 + rnd.nextDouble() * 4.4,
        delay: rnd.nextDouble(),
        color: colors[index % colors.length],
      );
    });
  }

  int get _ratingStars => ((widget.book.rating ?? 0) / 20).round().clamp(0, 5);

  Future<void> _share() async {
    final b = widget.book;
    final author = (b.author ?? '').trim();
    final lines = <String>[
      '📖 "${b.title}" kitabını bitirdim!',
      if (author.isNotEmpty) '✍️ $author',
      '📄 ${b.totalPages} sayfa',
      if (widget.daysToFinish != null && widget.daysToFinish! > 0)
        '⏱️ ${widget.daysToFinish} günde',
      if (widget.book.rating != null)
        '⭐ ${'★' * _ratingStars}${'☆' * (5 - _ratingStars)} (${b.rating}/100)',
      '🏆 ${widget.yearlyFinished}/${widget.yearlyGoal} yıllık hedef',
    ];
    try {
      await Share.share(lines.join('\n'), subject: 'Bir kitap daha bitti!');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF100B2B),
      body: AnimatedBuilder(
        animation: Listenable.merge([_flight, _ambient]),
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_flight.value);
          final contentT = ((_flight.value - .74) / .26).clamp(0.0, 1.0);
          final contentCurve = Curves.easeOutCubic.transform(contentT);
          final effectsOpacity = (1 - contentCurve).clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CelebrationSkyPainter(
                    flight: _flight.value,
                    ambient: _ambient.value,
                    sparks: _sparks,
                    stars: _stars,
                  ),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: effectsOpacity,
                  child: CustomPaint(
                    painter: _LightSpeedPainter(
                      progress: _flight.value,
                      ambient: _ambient.value,
                      lines: _speedLines,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: effectsOpacity,
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                      pieces: _pieces,
                      progress: _flight.value,
                      area: size,
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .10),
                        foregroundColor: Colors.white.withValues(alpha: .74),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: effectsOpacity,
                child: _FlightStage(progress: t, rawProgress: _flight.value),
              ),
              // Işık patlaması — fırlama anında ekranı dolduran beyaz parlama
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity:
                        (1 - (_flight.value - .52).abs() / .05).clamp(0.0, 1.0) *
                        .92,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.15,
                          colors: [Colors.white, Color(0x66FFFFFF), Color(0x00FFFFFF)],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0, _lerp(.58, .08, contentCurve)),
                child: Transform.translate(
                  offset: Offset(0, 26 * (1 - contentCurve)),
                  child: Opacity(
                    opacity: contentCurve,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 78, 18, 18 + bottomSafe),
                      child: Transform.scale(
                        scale: _lerp(.94, 1, contentCurve),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HeroTitle(bookTitle: widget.book.title),
                            const SizedBox(height: 16),
                            _ReportCard(
                              book: widget.book,
                              daysToFinish: widget.daysToFinish,
                              ratingStars: _ratingStars,
                            ),
                            const SizedBox(height: 12),
                            _YearlyBump(
                              finished: widget.yearlyFinished,
                              goal: widget.yearlyGoal,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _share,
                                    icon: const Icon(
                                      Icons.ios_share_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Karneyi paylaş'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: .28,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFC65B),
                                      foregroundColor: const Color(0xFF23133D),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text(
                                      'Harika!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FlightStage extends StatelessWidget {
  const _FlightStage({required this.progress, required this.rawProgress});

  final double progress;
  final double rawProgress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final r = rawProgress;

    // ---------------- Fazlar ----------------
    final flapWin = (r / .50).clamp(0.0, 1.0); // çırpınma + süzülme
    final charge = ((r - .44) / .10).clamp(0.0, 1.0); // toparlanma (crouch)
    final launchT = ((r - .52) / .07).clamp(0.0, 1.0); // fırlama anı
    final exitT = Curves.easeInCubic.transform(
      ((r - .54) / .34).clamp(0.0, 1.0), // ışık hızı çıkış
    );
    final vanish = Curves.easeIn.transform(((r - .72) / .22).clamp(0.0, 1.0));

    // ------------- Kanat çırpma: sprite kareleri (çok hızlı, ivmeli) -------
    // 5 kare, hepsi aynı tuvalde (492×385) gövde hizalı — zıplama yok.
    const flyFrames = [
      'assets/mascot/fly1.png',
      'assets/mascot/fly2.png',
      'assets/mascot/fly3.png',
      'assets/mascot/fly4.png',
      'assets/mascot/fly5.png',
    ];
    const seq = [0, 1, 2, 3, 4, 3, 2, 1]; // ping-pong: yumuşak tam çırpma
    final flapTicks = (r * (54 + 110 * flapWin)).floor(); // hızlanarak artar
    final flyIdx = seq[flapTicks % seq.length];
    final spriteAsset = r < .52 ? flyFrames[flyIdx] : flyFrames[4];

    // ------------- Dikey hareket -------------
    final hover = math.sin(r * math.pi * 7) * 6 * (1 - charge) * (1 - exitT);
    final crouchDy = 14 * charge * (1 - launchT) * (1 - exitT);
    final baseDy = hover + crouchDy;
    final dy = _lerp(baseDy, -size.height * 1.6, exitT);

    // ------------- Ölçek: crouch → ışık çizgisi → noktaya küçül -------------
    final crouchScale = 1 - .12 * charge * (1 - launchT);
    final stretchY = 1 + 1.9 * exitT; // dikey gerilme (motion blur)
    final stretchX = 1 - .55 * exitT; // incelme
    final shrink = _lerp(1.0, .10, vanish); // sona doğru noktaya küçül
    final sx = crouchScale * stretchX * shrink;
    final sy = crouchScale * stretchY * shrink;

    final tilt = math.sin(r * math.pi * 4) * .02 * (1 - charge) * (1 - exitT);
    final opacity = (1 - ((r - .84) / .10).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    // ------------- Efekt opaklıkları -------------
    final beamOpacity = ((r - .38) / .14).clamp(0.0, 1.0) * (1 - exitT);
    final burstOpacity =
        ((r - .50) / .05).clamp(0.0, 1.0) *
        (1 - ((r - .60) / .14).clamp(0.0, 1.0));

    return Align(
      alignment: const Alignment(0, -.12),
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scaleX: sx,
                scaleY: sy,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Alttan yükselen ışık huzmesi
                    Positioned(
                      top: 118,
                      child: Opacity(
                        opacity: beamOpacity,
                        child: CustomPaint(
                          size: Size(
                            120,
                            _lerp(40, 240, charge + launchT * .6),
                          ),
                          painter: _LiftBeamPainter(progress: r),
                        ),
                      ),
                    ),
                    // Fırlama patlaması (Bilge'nin merkezinde, çevreye yayılan)
                    Opacity(
                      opacity: burstOpacity,
                      child: CustomPaint(
                        size: const Size(360, 360),
                        painter: _LaunchBurstPainter(progress: r),
                      ),
                    ),
                    _BilgeFlightSprite(asset: spriteAsset, width: 208),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BilgeFlightSprite extends StatelessWidget {
  const _BilgeFlightSprite({required this.asset, required this.width});

  final String asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Tüm kareler aynı tuvalden eşit kırpıldığı için birebir hizalı —
    // kare değişiminde zıplama olmaz. Genişliğe göre ölçeklenir.
    return SizedBox(
      width: width,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _LaunchBurstPainter extends CustomPainter {
  _LaunchBurstPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = ((progress - .36) / .15).clamp(0.0, 1.0);
    if (p <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - p).clamp(0.0, 1.0);
    final maxR = size.width * .5;
    final eased = Curves.easeOutCubic.transform(p);

    // --- Sıcak çekirdek parlaması (merkezde patlama topu) ---
    final core = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: .95 * fade),
          const Color(0xFFFFE9A8).withValues(alpha: .62 * fade),
          const Color(0xFFFFB347).withValues(alpha: .26 * fade),
          const Color(0xFF73D2FF).withValues(alpha: .08 * fade),
          Colors.transparent,
        ],
        stops: const [0.0, .22, .5, .78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, core);

    // --- Genişleyen şok dalgası halkaları (ince, hızla açılan) ---
    for (var ring = 0; ring < 2; ring++) {
      final rp = (eased - ring * .12).clamp(0.0, 1.0);
      if (rp <= 0) continue;
      final rad = maxR * (.18 + .86 * rp);
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _lerp(5.0, .6, rp)
          ..color = (ring == 0 ? Colors.white : const Color(0xFFFFD166))
              .withValues(alpha: .55 * (1 - rp) * fade),
      );
    }

    // --- Her yöne fırlayan huzmeler (360° ışınlar, motion-blur'lu) ---
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const colors = [
      Color(0xFFFFE9A8),
      Color(0xFFFFD166),
      Color(0xFF73D2FF),
      Color(0xFFFF7AAE),
      Colors.white,
    ];
    const n = 22;
    for (var i = 0; i < n; i++) {
      // Her ışın altın orana göre farklı uzunlukta — düzensiz, gerçekçi
      final angle = (i / n) * math.pi * 2 + (i % 3) * .04;
      final jitter = .6 + ((i * 37) % 11) / 11 * .9; // 0.6–1.5
      final inner = maxR * (.12 + .30 * eased);
      final outer = maxR * (.30 + .92 * eased * jitter);
      final dir = Offset(math.cos(angle), math.sin(angle));
      ray
        ..strokeWidth = _lerp(4.0, .8, p) * (i.isEven ? 1.0 : .6)
        ..color = colors[i % colors.length].withValues(alpha: .8 * fade);
      canvas.drawLine(center + dir * inner, center + dir * outer, ray);
    }
  }

  @override
  bool shouldRepaint(_LaunchBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.bookTitle});

  final String bookTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
          ),
          child: const Text(
            'KİTAP TAMAMLANDI',
            style: TextStyle(
              color: Color(0xFFFFD166),
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Bir kitap daha bitti!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 27,
            height: 1.05,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          bookTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .72),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            height: 1.22,
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.book,
    required this.daysToFinish,
    required this.ratingStars,
  });

  final Book book;
  final int? daysToFinish;
  final int ratingStars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 64,
              height: 90,
              color: Colors.white.withValues(alpha: .08),
              child: CachedCover(url: book.coverUrl, iconColor: Colors.white54),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    height: 1.18,
                  ),
                ),
                if ((book.author ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    book.author!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .58),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Stat(
                      icon: Icons.menu_book_rounded,
                      label: '${book.totalPages} sayfa',
                    ),
                    if (daysToFinish != null && daysToFinish! > 0)
                      _Stat(
                        icon: Icons.schedule_rounded,
                        label: '$daysToFinish gün',
                      ),
                    if (book.rating != null)
                      _Stat(
                        icon: Icons.star_rounded,
                        label: '${'★' * ratingStars}${'☆' * (5 - ratingStars)}',
                        iconColor: const Color(0xFFFFC65B),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor ?? Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyBump extends StatelessWidget {
  const _YearlyBump({required this.finished, required this.goal});

  final int finished;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final safeGoal = goal <= 0 ? 1 : goal;
    final ratio = (finished / safeGoal).clamp(0.0, 1.0);
    final done = finished >= safeGoal;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: done
              ? const [Color(0xFF2BAE8A), Color(0xFF44D7C4)]
              : const [Color(0xFF6750E8), Color(0xFFA063ED)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (done ? const Color(0xFF2BAE8A) : const Color(0xFF6750E8))
                .withValues(alpha: .24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  done
                      ? 'Yıllık hedef tamam!'
                      : '${DateTime.now().year} hedefinde yeni adım',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$finished / $safeGoal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: .25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrationSkyPainter extends CustomPainter {
  _CelebrationSkyPainter({
    required this.flight,
    required this.ambient,
    required this.sparks,
    required this.stars,
  });

  final double flight;
  final double ambient;
  final List<_SparkParticle> sparks;
  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    final center = Offset(size.width / 2, size.height * .34);
    final burst = Curves.easeOutCubic.transform(
      ((flight - .55) / .35).clamp(0.0, 1.0),
    );

    // Derin uzay gradyanı (üstte mor şafak, altta lacivert derinlik)
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF2A1568),
        Color(0xFF180F3D),
        Color(0xFF0C0820),
        Color(0xFF1A0E33),
      ],
      stops: [0.0, .42, .74, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, paint);

    // --- Yıldız alanı (titreşen) ---
    for (final s in stars) {
      final tw =
          .35 +
          .65 *
              (.5 +
                  .5 *
                      math.sin(
                        (ambient * s.twinkleSpeed + s.twinklePhase) *
                            math.pi *
                            2,
                      ));
      // Patlama sırasında yıldızlar kısa süre parlar
      final boost = 1 + burst * .6;
      final c = s.warm ? const Color(0xFFFFE6B0) : const Color(0xFFCFE4FF);
      final pos = Offset(s.x * size.width, s.y * size.height);
      canvas.drawCircle(
        pos,
        s.size * (1 + tw * .3),
        Paint()..color = c.withValues(alpha: (.85 * tw * boost).clamp(0.0, 1.0)),
      );
      // Büyük yıldızlara hafif hâle
      if (s.size > 1.9) {
        canvas.drawCircle(
          pos,
          s.size * 2.6,
          Paint()..color = c.withValues(alpha: .10 * tw),
        );
      }
    }

    final glow1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(
            0xFF8C70FF,
          ).withValues(alpha: .34 + .08 * math.sin(ambient * math.pi * 2)),
          const Color(0xFF8C70FF).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .62));
    canvas.drawCircle(center, size.width * .62, glow1);

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC65B).withValues(alpha: .24 * burst),
          const Color(0xFFFF7AAE).withValues(alpha: .08 * burst),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .74));
    canvas.drawCircle(center, size.width * .74 * burst, glow2);

    for (var i = 0; i < 4; i++) {
      final y =
          size.height * (.15 + i * .13) +
          math.sin(ambient * math.pi * 2 + i) * 10;
      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = [
          const Color(0xFF73D2FF),
          const Color(0xFFFF7AAE),
          const Color(0xFFFFD166),
          const Color(0xFF52E0B7),
        ][i].withValues(alpha: .10);
      final path = Path()..moveTo(-40, y);
      for (double x = -40; x <= size.width + 40; x += 28) {
        path.lineTo(
          x,
          y +
              math.sin(
                    (x / size.width * math.pi * 2) + ambient * math.pi * 2 + i,
                  ) *
                  14,
        );
      }
      canvas.drawPath(path, wavePaint);
    }

    if (burst > 0) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..color = Colors.white.withValues(alpha: .28 * (1 - burst));
      canvas.drawCircle(center, 64 + 220 * burst, ringPaint);
      canvas.drawCircle(
        center,
        26 + 132 * burst,
        ringPaint
          ..color = const Color(
            0xFFFFD166,
          ).withValues(alpha: .34 * (1 - burst)),
      );

      for (final spark in sparks) {
        final t = ((burst - spark.delay) / (1 - spark.delay)).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final eased = Curves.easeOut.transform(t);
        final p =
            center +
            Offset(
              math.cos(spark.angle) * spark.distance * eased,
              math.sin(spark.angle) * spark.distance * eased,
            );
        final alpha = (1 - t).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(spark.spin + ambient * math.pi * 2);
        paint
          ..shader = null
          ..color = spark.color.withValues(alpha: .9 * alpha);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: spark.size,
              height: spark.size * 2.2,
            ),
            Radius.circular(spark.size),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationSkyPainter oldDelegate) =>
      oldDelegate.flight != flight || oldDelegate.ambient != ambient;
}

class _LightSpeedPainter extends CustomPainter {
  _LightSpeedPainter({
    required this.progress,
    required this.ambient,
    required this.lines,
  });

  final double progress;
  final double ambient;
  final List<_SpeedLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final charge = ((progress - .38) / .16).clamp(0.0, 1.0);
    final cruise = ((progress - .46) / .24).clamp(0.0, 1.0);
    final exit = ((progress - .70) / .16).clamp(0.0, 1.0);
    final intensity = (charge * (1 - exit)).clamp(0.0, 1.0);
    if (intensity <= 0) return;

    final centerX = size.width / 2;
    final paint = Paint()..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF73D2FF).withValues(alpha: 0),
          const Color(0xFF73D2FF).withValues(alpha: .20 * intensity),
          const Color(0xFFFFD166).withValues(alpha: .30 * intensity),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height * .52),
          width: size.width * .48,
          height: size.height,
        ),
        const Radius.circular(999),
      ),
      glow,
    );

    for (final line in lines) {
      // Çok daha hızlı akış (ışık hızı): faz çarpanı büyütüldü.
      final phase = (progress * (8 + cruise * 18) + line.delay) % 1.0;
      final y = _lerp(size.height * 1.08, -size.height * .28, phase);
      final laneOffset = (line.lane - .5) * size.width * .82;
      final drift = math.sin(ambient * math.pi * 2 + line.delay * 8) * 10;
      final start = Offset(centerX + laneOffset + drift, y);
      // Hızlandıkça çizgiler uzar (motion blur)
      final stretch = 1 + cruise * 1.4;
      final end = Offset(
        start.dx + math.sin(line.angle) * 20,
        y + line.length * stretch,
      );
      final fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      paint
        ..strokeWidth = line.width * _lerp(.8, 1.3, intensity)
        ..color = line.color.withValues(alpha: .88 * intensity * fade);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(_LightSpeedPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ambient != ambient;
}

class _LiftBeamPainter extends CustomPainter {
  _LiftBeamPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = .5 + math.sin(progress * math.pi * 4) * .5;
    final centerX = size.width / 2;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: .18 + pulse * .06),
          const Color(0xFFFFD166).withValues(alpha: .12),
          const Color(0xFF73D2FF).withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height * .46),
          width: size.width * .34,
          height: size.height,
        ),
        const Radius.circular(999),
      ),
      paint,
    );

    for (var i = 0; i < 5; i++) {
      final x = centerX + (i - 2) * 18.0;
      final phase = (progress * 2.8 + i * .19) % 1.0;
      final startY = _lerp(size.height * .92, -20, phase);
      final endY = startY + _lerp(34, 88, phase);
      paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 2 ? 1.7 : 1.0
        ..strokeCap = StrokeCap.round
        ..color = [
          const Color(0xFFFFD166),
          const Color(0xFF73D2FF),
          const Color(0xFFFF7AAE),
          const Color(0xFF52E0B7),
          Colors.white,
        ][i].withValues(alpha: .24 * math.sin(phase * math.pi));
      canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
    }
  }

  @override
  bool shouldRepaint(_LiftBeamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Confetto {
  _Confetto({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.square,
  });

  final double x;
  final double delay;
  final double speed;
  final double drift;
  final double size;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final bool square;
}

class _SpeedLine {
  _SpeedLine({
    required this.angle,
    required this.lane,
    required this.length,
    required this.width,
    required this.delay,
    required this.color,
  });

  final double angle;
  final double lane;
  final double length;
  final double width;
  final double delay;
  final Color color;
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinklePhase,
    required this.twinkleSpeed,
    required this.warm,
  });

  final double x;
  final double y;
  final double size;
  final double twinklePhase;
  final double twinkleSpeed;
  final bool warm;
}

class _SparkParticle {
  _SparkParticle({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.size,
    required this.color,
    required this.spin,
  });

  final double angle;
  final double distance;
  final double delay;
  final double size;
  final Color color;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.area,
  });

  final List<_Confetto> pieces;
  final double progress;
  final Size area;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final fall = t * p.speed;
      final dy = -0.08 * size.height + fall * size.height * 1.18;
      if (dy > size.height) continue;
      final dx =
          p.x * size.width + math.sin(t * math.pi * 3) * p.drift * size.width;
      final fade = t > .84 ? (1 - (t - .84) / .16) : 1.0;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + p.rotationSpeed * t);
      paint.color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      if (p.square) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * .62,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
