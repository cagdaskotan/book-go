import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MascotMood { greeting, happy, celebrate, encourage, sleepy, reading }

class Mascot extends StatefulWidget {
  const Mascot({
    super.key,
    this.mood = MascotMood.greeting,
    this.size = 96,
    this.animate = true,
  });

  final MascotMood mood;
  final double size;
  final bool animate;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  static const _openAsset = 'assets/mascot/bilge-reading.png';
  static const _blinkAsset = 'assets/mascot/bilge-reading-blink.png';

  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  Timer? _blinkTimer;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _motion.repeat(reverse: true);
      _scheduleBlink();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!widget.animate || widget.mood == MascotMood.sleepy) return;
    _blinkTimer = Timer(
      Duration(milliseconds: 2400 + math.Random().nextInt(2600)),
      () async {
        if (!mounted) return;
        setState(() => _blinking = true);
        await Future<void>.delayed(const Duration(milliseconds: 140));
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleBlink();
      },
    );
  }

  @override
  void didUpdateWidget(covariant Mascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate || oldWidget.mood != widget.mood) {
      if (widget.animate) {
        _motion.repeat(reverse: true);
        _scheduleBlink();
      } else {
        _motion.stop();
        _blinkTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final movement = widget.animate
            ? Curves.easeInOut.transform(_motion.value)
            : .5;
        final celebrate = widget.mood == MascotMood.celebrate;
        final dy = (movement - .5) * (celebrate ? 9 : 5);
        final scale = celebrate ? .98 + movement * .04 : 1.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Image.asset(
              widget.mood == MascotMood.sleepy || _blinking
                  ? _blinkAsset
                  : _openAsset,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
            if (widget.mood == MascotMood.celebrate) ...[
              const Positioned(
                top: 2,
                left: 3,
                child: _MascotSparkle(color: Color(0xFFFFD166), size: 15),
              ),
              const Positioned(
                top: 15,
                right: 0,
                child: _MascotSparkle(color: Color(0xFF75E6C3), size: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MascotSparkle extends StatelessWidget {
  const _MascotSparkle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.emoji_events_rounded, color: color, size: size);
  }
}

class MascotBubble extends StatelessWidget {
  const MascotBubble({
    super.key,
    required this.message,
    this.title,
    this.mood = MascotMood.greeting,
  });

  final String message;
  final String? title;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Mascot(mood: mood, size: 88),
          const SizedBox(width: 6),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -7,
                  bottom: 18,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(width: 15, height: 15, color: cs.surface),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        message,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          height: 1.32,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
