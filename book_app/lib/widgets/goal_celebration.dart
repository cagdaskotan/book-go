import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gamification_summary.dart';
import 'mascot.dart';

/// Günlük okuma hedefi tamamlandığında gösterilen kutlama penceresi.
Future<void> showGoalCelebration(
  BuildContext context,
  GamificationSummary summary,
) {
  HapticFeedback.mediumImpact();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .6),
    builder: (_) => _GoalCelebrationDialog(summary: summary),
  );
}

class _GoalCelebrationDialog extends StatelessWidget {
  const _GoalCelebrationDialog({required this.summary});
  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final streak = summary.currentStreak;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3A2C8C), Color(0xFF7A5BE6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6750E8).withValues(alpha: .4),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.celebrate, size: 104),
            const SizedBox(height: 10),
            const Text(
              'Bugünün hedefi tamam! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${summary.todayPages} sayfa okudun. Ritmin harika gidiyor!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.local_fire_department_rounded,
                    color: const Color(0xFFFFB454),
                    value: '$streak',
                    label: streak == 1 ? 'günlük seri' : 'günlük seri',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFF7BE3C0),
                    value: '${summary.xp}',
                    label: 'XP',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4B3CB1),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                child: const Text('Harika!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
