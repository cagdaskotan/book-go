import 'package:flutter/material.dart';

import '../models/catalog_book.dart';
import '../models/recommendation.dart';
import '../pages/plus_screen.dart';
import '../pages/routes.dart';
import '../services/plus_manager.dart';
import '../services/recommendation_service.dart';
import '../utils/web_search.dart';
import 'add_book_modal.dart';
import 'book_cover.dart';

/// Ana sayfadaki "Sana özel öneriler" bölümü. Kendi verisini yükler.
/// Bir öneriye dokununca künyesi önceden doldurulmuş ekleme akışı açılır.
class RecommendationsSection extends StatefulWidget {
  const RecommendationsSection({super.key, this.onBookAdded});
  final VoidCallback? onBookAdded;

  @override
  State<RecommendationsSection> createState() => _RecommendationsSectionState();
}

class _RecommendationsSectionState extends State<RecommendationsSection> {
  final _service = RecommendationService();
  List<Recommendation> _recs = const [];
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    plusManager.addListener(_onPlusChanged);
    if (hasPlusAccess) _load();
  }

  @override
  void dispose() {
    plusManager.removeListener(_onPlusChanged);
    super.dispose();
  }

  void _onPlusChanged() {
    if (hasPlusAccess && _recs.isEmpty && !_loading) {
      setState(() => _loading = true);
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) setState(() => _refreshing = true);
    try {
      final recs = await _service.fetch(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _recs = recs;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _add(Recommendation r) async {
    final created = await showAddBookModal(
      context,
      initial: CatalogBook(
        isbn: '',
        title: r.title,
        totalPages: r.totalPages,
        source: 'recommendation',
        author: r.author,
        coverUrl: r.coverUrl,
      ),
    );
    if (created != null && mounted) {
      setState(() => _recs = _recs.where((x) => x != r).toList());
      widget.onBookAdded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: plusManager,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        if (!hasPlusAccess) return _LockedTeaser();
        return _buildContent(cs);
      },
    );
  }

  Widget _buildContent(ColorScheme cs) {
    // İlk yükleme bitmeden ve öneri yokken bölümü gizleme; yükleme iskeletonu.
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(cs, showRefresh: false),
          const SizedBox(height: 10),
          SizedBox(
            height: 290,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const _SkeletonCard(),
            ),
          ),
        ],
      );
    }

    if (_recs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: .10),
                cs.secondary.withValues(alpha: .08),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.primary.withValues(alpha: .14)),
          ),
          child: Row(
            children: [
              Icon(Icons.recommend_rounded, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sana özel öneriler',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Birkaç kitabını bitir ve puanla; burada zevkine göre öneriler belirsin.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(cs, showRefresh: true),
        const SizedBox(height: 10),
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _recs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                _RecCard(rec: _recs[i], onAdd: () => _add(_recs[i])),
          ),
        ),
      ],
    );
  }

  Widget _header(ColorScheme cs, {required bool showRefresh}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          Icon(Icons.recommend_rounded, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Sana özel öneriler',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          if (showRefresh) ...[
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.recommendations),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text(
                'Tümünü gör',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Yenile',
              onPressed: _refreshing ? null : () => _load(refresh: true),
              icon: _refreshing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Plus üyesi olmayanlar için kilitli teaser (ana sayfada).
class _LockedTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const PlusScreen(),
            ),
          ),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1E63), Color(0xFF6750E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6750E8).withValues(alpha: .25),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD166), Color(0xFFF7A072)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.recommend_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Sana özel öneriler',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD166),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PLUS',
                              style: TextStyle(
                                color: Color(0xFF2A1E63),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Okuduklarına göre kürelenmiş kitaplar. Keşfetmek için dokun.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: .8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.rec, required this.onAdd});
  final Recommendation rec;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 156,
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kapak
              Container(
                height: 150,
                width: double.infinity,
                color: isDark ? cs.surfaceContainer : const Color(0xFFEFFAF4),
                child: CachedCover(
                  url: rec.coverUrl,
                  iconSize: 34,
                  title: rec.title,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (rec.author ?? '').isEmpty ? ' ' : rec.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.recommend_rounded,
                          size: 12,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Çünkü ${rec.reason}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Ekle'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _BuyButton(
                          onTap: () => searchBookOnline(
                            context,
                            rec.title,
                            author: rec.author,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kitabı internette aratan kompakt buton (öneri kartlarında).
class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'İnternette ara',
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 156,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: .25),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 110,
                    color: cs.outlineVariant.withValues(alpha: .3),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 70,
                    color: cs.outlineVariant.withValues(alpha: .2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
