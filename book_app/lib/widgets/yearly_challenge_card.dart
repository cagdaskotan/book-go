import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/reading_goal_service.dart';

/// Ana sayfada yıllık okuma hedefini gösteren tatlı kart.
/// Dairesel halka + tempo geri bildirimi ("öndesin / geride").
class YearlyChallengeCard extends StatelessWidget {
  const YearlyChallengeCard({
    super.key,
    required this.finished,
    required this.goal,
    required this.onEditGoal,
  });

  final int finished;
  final int goal;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final year = DateTime.now().year;
    final ratio = goal == 0 ? 0.0 : (finished / goal).clamp(0.0, 1.0);
    final expected = ReadingGoalService.expectedByNow(goal);
    final ahead = finished - expected;

    final (paceText, paceColor, paceIcon) = finished >= goal
        ? ('Hedefini tamamladın! 🎉', const Color(0xFF2BAE8A),
            Icons.verified_rounded)
        : ahead >= 0.5
        ? ('${ahead.floor()} kitap öndesin', const Color(0xFF2BAE8A),
            Icons.trending_up_rounded)
        : ahead <= -0.5
        ? ('${(-ahead).ceil()} kitap geridesin', const Color(0xFFF59E0B),
            Icons.trending_down_rounded)
        : ('Tam temponda gidiyorsun', cs.primary, Icons.bolt_rounded);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEditGoal,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF232140), Color(0xFF2E2750)]
                    : const [Color(0xFFF4F1FF), Color(0xFFFDF2EC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withValues(alpha: .14)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6750E8).withValues(alpha: .08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                _Ring(ratio: ratio, finished: finished, goal: goal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$year Okuma Hedefi',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: cs.onSurface,
                              letterSpacing: -.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        finished >= goal
                            ? 'Bu yıl $finished kitap bitirdin — efsanesin!'
                            : 'Hedefe $goal kitaptan $finished tanesi tamam.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: paceColor.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(paceIcon, size: 14, color: paceColor),
                            const SizedBox(width: 5),
                            Text(
                              paceText,
                              style: TextStyle(
                                color: paceColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
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
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.ratio,
    required this.finished,
    required this.goal,
  });
  final double ratio;
  final int finished;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 86,
        height: 86,
        child: CustomPaint(
          painter: _RingPainter(
            ratio: value,
            track: cs.outlineVariant.withValues(alpha: .5),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$finished',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ratio, required this.track});
  final double ratio;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (ratio <= 0) return;

    final shaderRect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          Color(0xFF6750E8),
          Color(0xFFA063ED),
          Color(0xFFF7A072),
          Color(0xFF6750E8),
        ],
      ).createShader(shaderRect);

    canvas.drawArc(
      shaderRect,
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.track != track;
}
