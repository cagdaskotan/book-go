import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.totalBooks,
    required this.completedBooks,
    required this.favoriteBooks,
    required this.inProgressBooks,
  });

  final int totalBooks;
  final int completedBooks;
  final int favoriteBooks;
  final int inProgressBooks;

  double get _progress =>
      totalBooks == 0 ? 0 : (completedBooks / totalBooks).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFDFFFD3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGreen.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugun neler okuyacaksin?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppTheme.darkGreen,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: _progress,
              backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${(_progress * 100).round()}% tamamlandi',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkGreen,
                ),
              ),
              const Spacer(),
              _Badge(icon: Icons.menu_book, label: '$totalBooks kitap'),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                icon: Icons.hourglass_bottom,
                label: 'Devam eden',
                value: inProgressBooks,
                color: AppTheme.accentOrange,
              ),
              _StatChip(
                icon: Icons.check_circle,
                label: 'Tamamlanan',
                value: completedBooks,
                color: AppTheme.primaryGreen,
              ),
              _StatChip(
                icon: Icons.favorite,
                label: 'Favori',
                value: favoriteBooks,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$value $label',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.darkGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
        ],
      ),
    );
  }
}
