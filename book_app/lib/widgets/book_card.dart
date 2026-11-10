import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_theme.dart';
import 'star_rating.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onFavoriteToggle,
    required this.favoriteBusy,
  });

  final Book book;
  final VoidCallback onFavoriteToggle;
  final bool favoriteBusy;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRating = book.rating != null;
    final coverUrl = book.coverUrl?.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookCover(coverUrl: coverUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                        color: AppTheme.inkStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _authorText(book),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.inkStrong.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasRating)
                    _Tag(
                      icon: Icons.star_rounded,
                      text: StarRating.label(book.rating),
                      color: _ratingColor(book.rating!),
                    ),
                  const SizedBox(height: 12),
                  _FavoriteButton(
                    isFavorite: book.favorite,
                    busy: favoriteBusy,
                    onTap: onFavoriteToggle,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: _progress,
              backgroundColor: AppTheme.brandSecondary.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                book.isFinished ? Icons.flag : Icons.hourglass_bottom,
                color: book.isFinished
                    ? AppTheme.brandPrimary
                    : AppTheme.brandAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                book.isFinished ? 'Tamamlandi' : 'Devam ediyor',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkStrong,
                ),
              ),
              const Spacer(),
              Text(
                '${book.currentPage}/${book.totalPages} sayfa',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.inkStrong.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (book.startedAt != null && book.startedAt!.isNotEmpty)
                _InfoPill(
                  icon: Icons.play_arrow_rounded,
                  label: 'Baslangic: ${book.startedAt}',
                ),
              if (book.finishedAt != null && book.finishedAt!.isNotEmpty)
                _InfoPill(
                  icon: Icons.flag_rounded,
                  label: 'Bitis: ${book.finishedAt}',
                ),
              if (book.tags != null && book.tags!.isNotEmpty)
                _InfoPill(icon: Icons.tag_rounded, label: book.tags!),
            ],
          ),
        ],
      ),
    );
  }

  String _authorText(Book b) => (b.author == null || b.author!.trim().isEmpty)
      ? 'Yazar bilgisi yok'
      : b.author!.trim();

  static Color _ratingColor(int rating) {
    if (rating >= 80) return const Color(0xFFFFD166);
    if (rating >= 60) return const Color(0xFF6EE7B7);
    return const Color(0xFF93C5FD);
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null || coverUrl!.isEmpty) {
      return Container(
        width: 64,
        height: 92,
        decoration: BoxDecoration(
          color: AppTheme.brandSecondary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: AppTheme.inkStrong,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        coverUrl!,
        width: 64,
        height: 92,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 64,
            height: 92,
            decoration: BoxDecoration(
              color: AppTheme.brandSecondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppTheme.inkStrong,
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.busy,
    required this.onTap,
  });

  final bool isFavorite;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: busy
                  ? const SizedBox(
                      key: ValueKey('busy'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey<bool>(isFavorite),
                      color: isFavorite ? Colors.redAccent : AppTheme.inkStrong,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.inkStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.brandSecondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.inkStrong),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.inkStrong,
            ),
          ),
        ],
      ),
    );
  }
}
