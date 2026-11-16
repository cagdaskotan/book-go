// lib/screens/books.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/sample_library_service.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/profile_service.dart';
import '../theme/app_type.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import 'collections.dart';
import 'routes.dart';

// Header/Nav bileşenleri
import '../widgets/app_card.dart';
import '../widgets/app_toast.dart';
import '../widgets/appbar.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/book_cover.dart';
import '../widgets/mascot.dart';
import '../widgets/navigation.dart';
import '../models/reading_status.dart';
import '../utils/turkish.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});
  @override
  State<BooksPage> createState() => _BooksPageState();
}

enum _BookSort { recent, title, author, progress, rating }

class _BooksPageState extends State<BooksPage> {
  final _bookService = BookService();
  final _searchCtrl = TextEditingController();

  List<Book> _books = const [];
  bool _isLoading = false;
  bool _installingSample = false;
  String? _errorMessage;
  String _statusFilter = 'all';
  String _query = '';
  _BookSort _sort = _BookSort.recent;
  bool _grid = false;

  static double _progressOf(Book b) =>
      b.totalPages == 0 ? 0 : (b.currentPage / b.totalPages).clamp(0.0, 1.0);

  List<Book> get _visibleBooks {
    Iterable<Book> list = _books;
    if (_statusFilter != 'all') {
      list = list.where((book) => book.readingStatus == _statusFilter);
    }
    // Türkçe harf duyarsız ara ve yayınevi/barkodu da kapsa: kullanıcı
    // "is bankasi" ya da barkodun son hanelerini yazarak da bulabilsin.
    final q = foldTurkish(_query.trim());
    if (q.isNotEmpty) {
      list = list.where(
        (b) =>
            containsTurkish(b.title, q) ||
            containsTurkish(b.author, q) ||
            containsTurkish(b.publisher, q) ||
            containsTurkish(b.category, q) ||
            containsTurkish(b.tags, q) ||
            (b.isbn ?? '').contains(q),
      );
    }
    final sorted = list.toList();
    switch (_sort) {
      case _BookSort.recent:
        sorted.sort((a, b) => b.id.compareTo(a.id));
      case _BookSort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _BookSort.author:
        sorted.sort(
          (a, b) => (a.author ?? '').toLowerCase().compareTo(
            (b.author ?? '').toLowerCase(),
          ),
        );
      case _BookSort.progress:
        sorted.sort((a, b) => _progressOf(b).compareTo(_progressOf(a)));
      case _BookSort.rating:
        sorted.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    }
    return sorted;
  }

  int _countFor(String status) => status == 'all'
      ? _books.length
      : _books.where((b) => b.readingStatus == status).length;

  @override
  void initState() {
    super.initState();
    _fetchBooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _goTab(HeaderTab tab) {
    final dest = (tab == HeaderTab.home) ? AppRoutes.home : AppRoutes.books;
    if (!mounted) return;
    if (ModalRoute.of(context)?.settings.name != dest) {
      Navigator.pushReplacementNamed(context, dest);
    }
  }

  void _upsertBook(Book b) {
    setState(() {
      final i = _books.indexWhere((x) => x.id == b.id);
      if (i >= 0) {
        _books = [..._books.take(i), b, ..._books.skip(i + 1)];
      } else {
        _books = [b, ..._books];
      }
    });
  }

  /// Boş kitaplıktan örnek verileri kurar. Teklif hem burada hem ana
  /// ekranda duruyor: kullanıcı boş rafı hangisinde görürse orada.
  Future<void> _loadSampleLibrary() async {
    setState(() => _installingSample = true);
    try {
      await SampleLibraryService.install();
      if (!mounted) return;
      await _fetchBooks();
      if (!mounted) return;
      AppToast.success(
        context,
        'Örnek kitaplar, raflar ve alıntılar eklendi.',
        title: 'Örnek kitaplık hazır',
      );
    } catch (_) {
      if (mounted) AppToast.error(context, 'Örnek kitaplık eklenemedi.');
    } finally {
      if (mounted) setState(() => _installingSample = false);
    }
  }

  Future<void> _openAdd() async {
    final createdId = await showBookAddLauncher(context);
    if (createdId == null) return;

    try {
      final newBook = await _bookService.getBook(createdId);
      if (!mounted) return;
      _upsertBook(newBook);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kitap eklendi')));
    } catch (_) {
      // Kayıt oluştu ama tek kitap okunamadıysa listeyi baştan çek.
      await _fetchBooks();
    }
  }

  Future<void> _fetchBooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final books = await _bookService.fetchBooks();
      if (!mounted) return;
      setState(() => _books = books);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          activeTab: HeaderTab.books,
          showAddButton: false,
          onAddPressed: null,
          onNavSelected: _goTab,
          onToggleTheme: null,
          onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
          onFavorites: () => Navigator.pushNamed(context, AppRoutes.favorites),
          onInsights: () => Navigator.pushNamed(context, AppRoutes.insights),
          onCollections: () =>
              Navigator.of(context).push(CollectionsPage.route()),
          userName: profileService.visibleName,
          brandColor: const Color(0xFF4F46E5),
        ),

        bottomNavigationBar: MainNavigation(
          current: HeaderTab.books,
          onTabSelected: _goTab,
          onAddPressed: _openAdd,
        ),

        body: RefreshIndicator(
          color: cs.primary,
          onRefresh: _fetchBooks,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                sliver: SliverToBoxAdapter(
                  child: _ShelfPortal(
                    bookCount: _books.length,
                    onTap: () =>
                        Navigator.of(context).push(CollectionsPage.route()),
                  ),
                ),
              ),

              if (_isLoading && _books.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverList.list(
                    children: const [
                      _LoadingSkeleton(),
                      SizedBox(height: 12),
                      _LoadingSkeleton(),
                      SizedBox(height: 12),
                      _LoadingSkeleton(),
                    ],
                  ),
                )
              else if (_errorMessage != null && _books.isEmpty)
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
                            _errorMessage ?? 'Bilinmeyen hata',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: .7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchBooks,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_books.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: _SurfaceCard(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        children: [
                          const Mascot(mood: MascotMood.encourage, size: 104),
                          const SizedBox(height: 8),
                          Text(
                            'Henüz bir kitabınız yok',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'İlk kitabını ekle, Bilge seninle birlikte maceraya başlasın!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: .7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openAdd,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('İlk kitabını ekle'),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _installingSample
                                ? null
                                : _loadSampleLibrary,
                            icon: const Icon(
                              Icons.auto_stories_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _installingSample
                                  ? 'Örnekler ekleniyor'
                                  : 'Örnek kitaplıkla gez',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Liste başlığı + sıralama/görünüm aksiyonları
                SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 12, top: 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Kitap Listesi',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_visibleBooks.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<_BookSort>(
                          tooltip: 'Sırala',
                          initialValue: _sort,
                          icon: Icon(
                            Icons.sort_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          onSelected: (value) => setState(() => _sort = value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: _BookSort.recent,
                              child: Text('En yeni eklenen'),
                            ),
                            PopupMenuItem(
                              value: _BookSort.title,
                              child: Text('Ada göre (A–Z)'),
                            ),
                            PopupMenuItem(
                              value: _BookSort.author,
                              child: Text('Yazara göre (A–Z)'),
                            ),
                            PopupMenuItem(
                              value: _BookSort.progress,
                              child: Text('İlerlemeye göre'),
                            ),
                            PopupMenuItem(
                              value: _BookSort.rating,
                              child: Text('Puana göre'),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: _grid ? 'Liste görünümü' : 'Izgara görünümü',
                          onPressed: () => setState(() => _grid = !_grid),
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (c, a) =>
                                ScaleTransition(scale: a, child: c),
                            child: Icon(
                              _grid
                                  ? Icons.view_agenda_rounded
                                  : Icons.grid_view_rounded,
                              key: ValueKey(_grid),
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Arama
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Kitap, yazar veya kategori ara…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Temizle',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: Row(
                      children: [
                        _StatusFilter(
                          label: 'Tümü (${_countFor('all')})',
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        for (final status in ReadingStatus.values)
                          _StatusFilter(
                            label:
                                '${status.label} (${_countFor(status.value)})',
                            selected: _statusFilter == status.value,
                            onTap: () =>
                                setState(() => _statusFilter = status.value),
                          ),
                      ],
                    ),
                  ),
                ),

                // Sonuç yok
                if (_visibleBooks.isEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      bottomNavInset(context),
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _SurfaceCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 42,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Eşleşen kitap bulunamadı',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Aramanı veya filtreni değiştirip tekrar dene.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                // Izgara görünümü
                else if (_grid)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      bottomNavInset(context),
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: .58,
                          ),
                      itemCount: _visibleBooks.length,
                      itemBuilder: (_, i) {
                        final book = _visibleBooks[i];
                        return _BookGridCard(
                          book: book,
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(AppRoutes.diary, arguments: book.id),
                          onToggleFavorite: (fav) =>
                              _setFavorite(context, book, fav),
                        );
                      },
                    ),
                  )
                // Liste görünümü
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      bottomNavInset(context),
                    ),
                    sliver: SliverList.separated(
                      itemCount: _visibleBooks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final book = _visibleBooks[i];
                        return InkWell(
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.diary, arguments: book.id);
                          },
                          child: _BookTile(
                            book: book,
                            onToggleFavorite: (fav) =>
                                _setFavorite(context, book, fav),
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

  void _replaceBook(Book updated) {
    setState(() {
      _books = _books.map((b) => b.id == updated.id ? updated : b).toList();
    });
  }

  Future<void> _setFavorite(BuildContext context, Book book, bool fav) async {
    final old = book.favorite;
    _replaceBook(book.copyWith(favorite: fav));
    try {
      await _bookService.updateFavorite(book.id, fav);
    } on ApiException catch (e) {
      _replaceBook(book.copyWith(favorite: old));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      _replaceBook(book.copyWith(favorite: old));
    }
  }
}

// ===================== GRID CARD =====================
class _BookGridCard extends StatelessWidget {
  const _BookGridCard({
    required this.book,
    required this.onTap,
    required this.onToggleFavorite,
  });
  final Book book;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleFavorite;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kapak
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: isDark
                        ? cs.surfaceContainer
                        : const Color(0xFFEFFAF4),
                    child: CachedCover(
                      url: book.coverUrl,
                      iconSize: 38,
                      title: book.title,
                    ),
                  ),
                  // Favori
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: cs.surface.withValues(alpha: .88),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onToggleFavorite(!book.favorite),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            book.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: book.favorite
                                ? Colors.redAccent
                                : cs.onSurfaceVariant,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Durum rozeti
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _statusIcon(book.readingStatus),
                            size: 12,
                            color: book.isFinished ? cs.primary : cs.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel(book.readingStatus),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bilgi
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (book.author == null || book.author!.trim().isEmpty)
                        ? 'Yazar bilgisi yok'
                        : book.author!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GradientProgressBar.adaptive(
                    value: _progress,
                    height: 9,
                    bgColor: cs.outlineVariant.withValues(alpha: .35),
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

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: cs.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _statusLabel(String status) => ReadingStatus.parse(status).label;

IconData _statusIcon(String status) => ReadingStatus.parse(status).icon;

// ===================== BOOK TILE =====================
class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onToggleFavorite});
  final Book book;
  final ValueChanged<bool> onToggleFavorite;

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
          _CoverThumb(
            url: book.coverUrl,
            finished: book.isFinished,
            title: book.title,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // başlık + fav
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppSerif.itemTitle.withColor(cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FavButton(
                        isFav: book.favorite,
                        onTap: () => onToggleFavorite(!book.favorite),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _authorText(book),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: .7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Progress bar (tema uyumlu)
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      _MetaPill(
                        icon: _statusIcon(book.readingStatus),
                        label: _statusLabel(book.readingStatus),
                        color: book.isFinished ? cs.primary : cs.secondary,
                      ),
                      if (book.rating != null)
                        _MetaPill(
                          icon: Icons.star_rounded,
                          label: '${book.rating}',
                          color: Colors.amber,
                        ),
                      _MetaPill(
                        icon: Icons.menu_book_rounded,
                        label: '${book.currentPage}/${book.totalPages}',
                        color: cs.onSurfaceVariant,
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

  String _authorText(Book b) => (b.author == null || b.author!.trim().isEmpty)
      ? 'Yazar bilgisi yok'
      : b.author!.trim();
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url, required this.finished, this.title});
  final String? url;
  final String? title;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            width: 62,
            height: 86,
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainer : const Color(0xFFEFFAF4),
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: CachedCover(url: url, title: title),
          ),
        ],
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.isFav, required this.onTap});
  final bool isFav;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isFav ? Colors.redAccent : cs.onSurface.withValues(alpha: .5);
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFav),
          color: color,
          size: 22,
        ),
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
  /*const _GradientProgressBar({
    required this.value,
    this.height = 12,
    this.gradient,
    this.bgColor,
    this.showCenterPercent = false,
    this.centerStyle,
  });*/

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

class _ShelfPortal extends StatelessWidget {
  const _ShelfPortal({required this.bookCount, required this.onTap});

  final int bookCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                // Kutunun çamurlu kahverengi gradyanı ekrandaki tek sıcak
                // leke olarak duruyordu ve kirli görünüyordu. Rafın gerçek
                // ahşap tonuna bağlandı.
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7A5436), Color(0xFF4A3426)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.shelves, color: Color(0xFFFFE5B8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kitaplık görünümü',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$bookCount kitabını raflarında düzenle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
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
