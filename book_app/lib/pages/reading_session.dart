import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';

/// Tam ekran, sakinleştirici okuma oturumu.
/// Kapanırken geçen dakika sayısını (int) döndürür; hiç okuma yoksa null.
class ReadingSessionPage extends StatefulWidget {
  const ReadingSessionPage({super.key, required this.book});
  final Book book;

  @override
  State<ReadingSessionPage> createState() => _ReadingSessionPageState();
}

class _ReadingSessionPageState extends State<ReadingSessionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);
  late final Animation<double> _breathCurve = CurvedAnimation(
    parent: _breath,
    curve: Curves.easeInOut,
  );

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  static const _phrases = [
    'Sadece sen ve sayfalar…',
    'Nefes al, sayfayı çevir.',
    'Kelimeler seni taşısın.',
    'Acele yok; her cümlenin tadını çıkar.',
    'Dış dünya bekleyebilir.',
    'Hikâyenin ritmine bırak kendini.',
    'Her sayfa, küçük bir yolculuk.',
    'Şu an tam olman gereken yerdesin.',
  ];

  // (dx, dy, boyut, faz) — sabit yıldız haritası
  static const _starSeeds = <(double, double, double, double)>[
    (.08, .10, 2.4, .00),
    (.22, .05, 1.6, .35),
    (.36, .14, 2.0, .70),
    (.52, .07, 1.4, .15),
    (.68, .12, 2.6, .55),
    (.84, .06, 1.8, .90),
    (.93, .16, 1.5, .25),
    (.12, .24, 1.7, .60),
    (.45, .22, 1.3, .80),
    (.78, .26, 2.1, .45),
    (.05, .42, 1.5, .30),
    (.92, .40, 1.9, .65),
    (.18, .82, 1.6, .50),
    (.86, .86, 2.2, .10),
  ];

  bool get _running => _stopwatch.isRunning;
  int get _seconds => _stopwatch.elapsed.inSeconds;
  int get _minutes => (_seconds / 60).ceil();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breath.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _start() {
    HapticFeedback.lightImpact();
    _stopwatch.start();
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  void _pause() {
    HapticFeedback.lightImpact();
    _stopwatch.stop();
    setState(() {});
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    _stopwatch.stop();
    setState(() {});
    final save = await _showSessionConfirmation(
      icon: Icons.check_rounded,
      colors: const [Color(0xFF61D8B3), Color(0xFF2BAE8A)],
      title: 'Oturumu tamamla',
      message: '$_time boyunca okudun. Bu oturumu günlüğüne kaydedelim mi?',
      confirmLabel: 'Kaydetmeye devam et',
      cancelLabel: 'Okumaya dön',
    );
    if (!mounted) return;
    if (save == true) {
      Navigator.of(context).pop(_seconds > 0 ? _minutes : null);
    } else {
      _start();
    }
  }

  Future<void> _close() async {
    if (_seconds < 5) {
      Navigator.of(context).pop();
      return;
    }
    final wasRunning = _running;
    _stopwatch.stop();
    setState(() {});
    final discard = await _showSessionConfirmation(
      icon: Icons.close_rounded,
      colors: const [Color(0xFFFFA55B), Color(0xFFF06473)],
      title: 'Oturumdan çık',
      message:
          '$_time boyunca okudun. Çıkarsan bu süre günlüğüne eklenmeyecek.',
      confirmLabel: 'Kaydetmeden çık',
      cancelLabel: 'Oturuma dön',
      destructive: true,
    );
    if (!mounted) return;
    if (discard == true) {
      Navigator.of(context).pop();
    } else if (wasRunning) {
      _start();
    }
  }

  Future<bool?> _showSessionConfirmation({
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _SessionConfirmationSheet(
        icon: icon,
        colors: colors,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
  }

  String get _time {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  String get _phrase {
    if (!_running && _seconds > 0) return 'Mola iyidir. Hazır olunca devam et.';
    return _phrases[(_seconds ~/ 60) % _phrases.length];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _seconds < 5,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF060A1A),
        body: AnimatedBuilder(
          animation: _breathCurve,
          builder: (context, _) {
            final t = _breathCurve.value; // 0..1 (nefes)
            final size = MediaQuery.sizeOf(context);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Gece gradyanı
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF060A1A),
                        Color(0xFF121A38),
                        Color(0xFF261E55),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Yumuşak ışık blobları
                _glow(
                  alignment: const Alignment(-1.2, -0.85),
                  diameter: 300 + 50 * t,
                  color: const Color(0xFF6750E8).withValues(alpha: .20),
                ),
                _glow(
                  alignment: const Alignment(1.25, 0.95),
                  diameter: 360 + 60 * (1 - t),
                  color: const Color(0xFFA063ED).withValues(alpha: .14),
                ),
                // Parıldayan yıldızlar
                for (final (dx, dy, s, phase) in _starSeeds)
                  Positioned(
                    left: size.width * dx,
                    top: size.height * dy,
                    child: Opacity(
                      opacity:
                          .18 +
                          .55 *
                              (0.5 + 0.5 * math.sin(2 * math.pi * (t + phase))),
                      child: Container(
                        width: s,
                        height: s,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      // Üst bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Kapat',
                              onPressed: _close,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .10),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.menu_book_rounded,
                                    size: 15,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 7),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 190,
                                    ),
                                    child: Text(
                                      widget.book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48), // sol X ile denge
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Nefes alan halka + süre
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: .90 + .10 * t,
                              child: Container(
                                width: 272,
                                height: 272,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: .025),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: .08 + .08 * t,
                                    ),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF7567F8,
                                      ).withValues(alpha: .16 + .14 * t),
                                      blurRadius: 70,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: .96 + .04 * (1 - t),
                              child: Container(
                                width: 214,
                                height: 214,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .07),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _time,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: 3,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _phrase,
                          key: ValueKey(_phrase),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .55),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Spacer(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BigRoundButton(
                            icon: _running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onTap: _running ? _pause : _start,
                          ),
                          const SizedBox(width: 18),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _seconds > 0 ? 1 : .35,
                            child: _StopButton(
                              enabled: _seconds > 0,
                              onTap: _finish,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 42),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _glow({
    required Alignment alignment,
    required double diameter,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _BigRoundButton extends StatelessWidget {
  const _BigRoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF7567F8), Color(0xFFA06AF5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7567F8).withValues(alpha: .45),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 42),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF61D8B3), Color(0xFF2BAE8A)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2BAE8A).withValues(alpha: .35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.stop_rounded, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _SessionConfirmationSheet extends StatelessWidget {
  const _SessionConfirmationSheet({
    required this.icon,
    required this.colors,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final IconData icon;
  final List<Color> colors;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF11162C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: .32),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: destructive
                        ? const Color(0xFFF06473)
                        : const Color(0xFF2BAE8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(cancelLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
