import 'package:flutter/material.dart';

import '../models/gamification_summary.dart';
import 'app_progress_bar.dart';

class ReadingQuestCard extends StatelessWidget {
  const ReadingQuestCard({
    super.key,
    required this.summary,
    required this.onEditGoal,
  });

  final GamificationSummary summary;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF252338), Color(0xFF332B47)]
              : [
                  cs.surface,
                  Color.alphaBlend(
                    const Color(0xFFFFE8D5).withValues(alpha: .5),
                    cs.surface,
                  ),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.primary.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6750E8).withValues(alpha: .09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StreakOrb(streak: summary.currentStreak),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.currentStreak == 0
                          ? 'Serini bugün başlat'
                          : '${summary.currentStreak} günlük harika seri',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _message,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  'Lv. ${summary.level}',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: cs.surface.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onEditGoal,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          summary.dailyGoalMet
                              ? Icons.verified_rounded
                              : Icons.track_changes_rounded,
                          color: summary.dailyGoalMet
                              ? const Color(0xFF2BAE8A)
                              : const Color(0xFFF97373),
                          size: 20,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          summary.dailyGoalMet
                              ? 'Görev tamamlandı! 🎉'
                              : 'Bugünün görevi',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Text(
                          '${summary.todayPages} / ${summary.dailyPageGoal} sayfa',
                          style: TextStyle(
                            color: summary.dailyGoalMet
                                ? const Color(0xFF2BAE8A)
                                : cs.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.edit_rounded, size: 14, color: cs.primary),
                      ],
                    ),
                    const SizedBox(height: 9),
                    AppProgressBar(
                      value: summary.dailyProgress,
                      height: 14,
                      showLabel: true,
                      gradient: summary.dailyGoalMet
                          ? const LinearGradient(
                              colors: [Color(0xFF34D399), Color(0xFF2BAE8A)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFFFA65B), Color(0xFFF97373)],
                            ),
                      trackColor: summary.dailyGoalMet
                          ? const Color(0xFFD7F5E9)
                          : const Color(0xFFFFEAD8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _WeekStrip(days: summary.week),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TinyMetric(
                  icon: Icons.bolt_rounded,
                  text: '${summary.longestStreak} gün rekor',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              Expanded(
                child: _TinyMetric(
                  icon: Icons.bar_chart_rounded,
                  text: '${summary.xp} XP',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              Expanded(
                child: _TinyMetric(
                  icon: Icons.menu_book_rounded,
                  text: '${summary.totalPages} sayfa',
                  color: const Color(0xFF2BAE8A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _message {
    if (summary.dailyGoalMet) return 'Bugünün görevini tamamladın.';
    if (summary.todayPages > 0) {
      return '${summary.remainingPages} sayfa sonra görev tamam.';
    }
    return 'Birkaç sayfa bile ritmini korur.';
  }
}

class _StreakOrb extends StatelessWidget {
  const _StreakOrb({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFBD68), Color(0xFFFF746D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97373).withValues(alpha: .25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 34,
          ),
          if (streak > 0)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$streak',
                  style: const TextStyle(
                    color: Color(0xFFF97316),
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});
  final List<ReadingDay> days;
  static const labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = index < days.length ? days[index] : null;
        final active = (day?.pagesRead ?? 0) > 0;
        final complete = day?.goalMet ?? false;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: complete
                    ? const Color(0xFFFFA65B)
                    : active
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: day?.isToday == true
                    ? Border.all(color: cs.primary, width: 2)
                    : null,
              ),
              child: Icon(
                complete
                    ? Icons.star_rounded
                    : active
                    ? Icons.check_rounded
                    : Icons.circle,
                color: complete || active ? Colors.white : cs.outlineVariant,
                size: complete ? 18 : 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[index],
              style: TextStyle(
                color: day?.isToday == true ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w900,
                fontSize: 9,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
