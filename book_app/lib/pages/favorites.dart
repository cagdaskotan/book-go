import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/book_service.dart';
import '../services/api_exception.dart';
import '../services/profile_service.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import 'routes.dart';

// Header/Nav bileşenleri
import '../widgets/app_card.dart';
import '../widgets/appbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/book_cover.dart';
import '../widgets/navigation.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _bookService = BookService();

  List<Book> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _bookService.fetchBooks();
      if (!mounted) return;
      setState(() {
        _items = all.where((b) => b.favorite).toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTab(HeaderTab tab) {
    final dest = (tab == HeaderTab.home) ? AppRoutes.home : AppRoutes.books;
    if (ModalRoute.of(context)?.settings.name != dest) {
      Navigator.pushReplacementNamed(context, dest);
    }
  }

  Future<void> _removeFavorite(Book book) async {
    // optimistic: listeden çıkar, hata olursa geri al
    setState(() {
      _items = _items.where((b) => b.id != book.id).toList();
    });

    try {
      await _bookService.updateFavorite(book.id, false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${book.title}" favorilerden çıkarıldı'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () async {
              try {
                await _bookService.updateFavorite(book.id, true);
                if (mounted) await _fetchFavorites();
              } catch (_) {}
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _items = [..._items, book]);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      setState(() => _items = [..._items, book]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        appBar: MainAppBar(
          activeTab: HeaderTab.favorites,
          showAddButton: false,
          onAddPressed: null,
          onNavSelected: _goTab,
          onToggleTheme: null,
          onProfile: () {
            Navigator.pushNamed(context, AppRoutes.profile);
          },
          onFavorites: () {}, // zaten buradayız
          onInsights: () => Navigator.pushNamed(context, AppRoutes.insights),
          onCollections: () =>
              Navigator.pushNamed(context, AppRoutes.collections),
          userName: profileService.visibleName,
          brandColor: const Color(0xFF4F46E5),
        ),

        bottomNavigationBar: MainNavigation(
          current: HeaderTab.favorites,
          onTabSelected: _goTab,
          onAddPressed: () => showBookAddLauncher(context),
        ),

        body: RefreshIndicator(
          color: cs.primary,
          onRefresh: _fetchFavorites,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 8,
                  child: DecoratedBox(decoration: _heroDecoration(context)),
                ),
              ),

              if (_loading && _items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverList.list(
                    children: const [
                      _LoadingSkeleton(),
                      SizedBox(height: 12),
                      _LoadingSkeleton(),
                    ],
                  ),
                )
              else if (_error != null && _items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: _SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bir sorun oluştu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchFavorites,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_items.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: const _SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: EmptyState(
                        title: 'Favori rafın hazır bekliyor',
                        message:
                            'Bir kitabı kalp ikonuyla işaretle; dönüp dönüp '
                            'baktığın kitaplar burada toplanır.',
                      ),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 16),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Colors.pink),
                        const SizedBox(width: 8),
                        Text(
                          'Favoriler',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_items.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    bottomNavInset(context),
                  ),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final book = _items[i];
                      return InkWell(
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.diary, arguments: book.id);
                        },
                        child: _BookTile(
                          book: book,
                          onRemoveFavorite: () => _removeFavorite(book),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ====== Hero şeridi: Light/Dark'a göre gradyan ======
BoxDecoration _heroDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: const Alignment(0, -1.2),
      end: const Alignment(0, 1),
      colors: isDark
          ? const [
              Color(0xFF0B1020),
              Color(0xFF1F1B4B),
              AppTheme.brandSecondaryDark,
            ]
          : const [
              Color(0xFF0E402B),
              AppTheme.brandPrimary,
              AppTheme.brandSecondary,
            ],
      stops: const [0.0, 0.55, 1.0],
    ),
  );
}

// ====== LIST TILE (favoriler için sade versiyon) ======
class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onRemoveFavorite});
  final Book book;
  final VoidCallback onRemoveFavorite;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverThumb(url: book.coverUrl, title: book.title),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık + fav kaldır
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bu sayfada kalp, "kaldır" işlevi görsün
                      InkResponse(
                        onTap: onRemoveFavorite,
                        radius: 18,
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (book.author == null || book.author!.trim().isEmpty)
                        ? 'Yazar bilgisi yok'
                        : book.author!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _GradientProgressBar.adaptive(
                    value: _progress,
                    height: 16,
                    showCenterPercent: true,
                    bgColor: cs.outlineVariant.withValues(alpha: .35),
                    centerStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        book.isFinished ? Icons.flag : Icons.hourglass_bottom,
                        color: book.isFinished ? cs.primary : cs.secondary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        book.isFinished ? 'Bitti' : 'Devam ediyor',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (book.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${book.rating}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        '${book.currentPage}/${book.totalPages} sayfa',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayfanın kart yüzeyi — görünümü [AppCard] belirliyor.
///
/// Bu sınıf beş ayrı sayfada birebir kopyalanmıştı; her biri kendi
/// gölgesini ve kenarlığını yazıyordu ve zamanla ayrıştılar. Çağrı
/// yerlerini değiştirmemek için ad korundu, görünüm tek kaynağa bağlandı.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) =>
      AppCard(padding: padding ?? const EdgeInsets.all(Gap.lg), child: child);
}

class _GradientProgressBar extends StatelessWidget {
  /// Tema duyarlı varsayılan gradyan
  const _GradientProgressBar.adaptive({
    required this.value,
    this.height = 12,
    this.bgColor,
    this.showCenterPercent = false,
    this.centerStyle,
  }) : gradient = null;

  final double value; // 0..1
  final double height;
  final Gradient? gradient;
  final Color? bgColor;
  final bool showCenterPercent;
  final TextStyle? centerStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultGradient = isDark
        ? const LinearGradient(
            colors: [AppTheme.brandPrimaryDark, AppTheme.brandSecondaryDark],
          )
        : const LinearGradient(
            colors: [AppTheme.brandPrimary, AppTheme.brandSecondary],
          );

    final track =
        bgColor ??
        Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: isDark ? .35 : .3);
    return AppProgressBar(
      value: value,
      height: height,
      showLabel: showCenterPercent,
      gradient: gradient ?? defaultGradient,
      trackColor: track,
      labelStyle: centerStyle,
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url, this.title});
  final String? url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 62,
        height: 86,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainer : const Color(0xFFEFFAF4),
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: CachedCover(url: url, title: title),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bar({double h = 14, double w = double.infinity}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 86,
            decoration: BoxDecoration(
              color: cs.outlineVariant.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                bar(h: 16),
                const SizedBox(height: 8),
                bar(w: 160),
                const SizedBox(height: 14),
                bar(h: 10),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: bar(w: 100, h: 10)),
                    const SizedBox(width: 8),
                    bar(w: 80, h: 10),
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
