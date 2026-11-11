import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/book.dart';
import '../models/book_collection.dart';
import '../widgets/app_sheet.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/collection_service.dart';
import '../widgets/appbar.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_open_hero.dart';
import '../widgets/navigation.dart';
import 'diary.dart';
import 'routes.dart';
import '../widgets/book_spine.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  /// Kütüphanem sayfasından raflara bağlantılı, sıcak geçiş — dolap öne gelir.
  static Route<void> route() => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 540),
    reverseTransitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (_, __, ___) => const CollectionsPage(),
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.90, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final _service = CollectionService();
  final _booksService = BookService();
  List<BookCollection> _collections = const [];
  List<Book> _books = const [];
  bool _loading = true;
  String? _error;

  // Düzenleme modu: çoklu seçim + sıralama + toplu işlem.
  bool _editMode = false;
  final Set<(int, int)> _selected = {}; // (collectionId, bookId)

  static const colors = [
    '#6750E8',
    '#F97373',
    '#2BAE8A',
    '#F59E0B',
    '#4D8DF7',
    '#A063ED',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        _service.fetchCollections(),
        _booksService.fetchBooks(),
      ]);
      if (!mounted) return;
      setState(() {
        _collections = result[0] as List<BookCollection>;
        _books = result[1] as List<Book>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Koleksiyonlar şu anda yüklenemedi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCollectionSheet(
        colors: colors,
        onSubmit: _service.createCollection,
      ),
    );
    if (created == true) await _load();
  }

  /// Rafın adını ve rengini düzenleme alt sayfası.
  Future<void> _editCollection(BookCollection collection) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCollectionSheet(
        colors: colors,
        initialName: collection.name,
        initialColor: collection.color,
        title: 'Rafı düzenle',
        submitLabel: 'Kaydet',
        busyLabel: 'Kaydediliyor',
        onSubmit: (name, color) =>
            _service.updateCollection(collection.id, name, color),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openCollection(
    BookCollection collection,
    List<Book> books,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final color = _hex(collection.color);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.collections_bookmark_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text('${books.length} kitap'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: books.isEmpty
                      ? const _EmptyShelf()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: books.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final book = books[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                              tileColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              leading: _BookCover(url: book.coverUrl),
                              title: Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                book.author?.trim().isNotEmpty == true
                                    ? book.author!
                                    : 'Yazar bilgisi yok',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Raftan çıkar',
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                ),
                                onPressed: () async {
                                  try {
                                    await _service.removeBook(
                                      collection.id,
                                      book.id,
                                    );
                                    books.removeAt(index);
                                    setSheetState(() {});
                                    if (mounted) {
                                      setState(() {
                                        _collections = _collections
                                            .map(
                                              (item) => item.id == collection.id
                                                  ? BookCollection(
                                                      id: item.id,
                                                      name: item.name,
                                                      color: item.color,
                                                      bookIds: item.bookIds
                                                          .where(
                                                            (id) =>
                                                                id != book.id,
                                                          )
                                                          .toList(),
                                                    )
                                                  : item,
                                            )
                                            .toList();
                                      });
                                    }
                                  } on ApiException catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.message)),
                                    );
                                  }
                                },
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.pushNamed(
                                  this.context,
                                  AppRoutes.diary,
                                  arguments: book.id,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteCollection(BookCollection collection) async {
    final confirmed = await showAppConfirm(
      context,
      title: '${collection.name} silinsin mi?',
      message: 'Kitapların silinmez; yalnızca bu raf kitaplığından kaldırılır.',
      confirmLabel: 'Rafı kaldır',
      destructive: true,
    );
    if (confirmed != true) return;
    await _service.deleteCollection(collection.id);
    await _load();
  }

  Future<void> _addBooksToCollection(BookCollection collection) async {
    final available = _books
        .where((book) => !collection.bookIds.contains(book.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kütüphanendeki tüm kitaplar bu rafta.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ShelfBookPicker(collection: collection, books: available),
    );
    if (selected == null || selected.isEmpty) return;

    try {
      await Future.wait(
        selected.map((bookId) => _service.addBook(collection.id, bookId)),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.length == 1
                ? 'Kitap ${collection.name} rafına yerleştirildi.'
                : '${selected.length} kitap ${collection.name} rafına yerleştirildi.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Kitaba dokununca: raftan çıkıp ortada açılan, sonra detay kapağına
  /// oturan imza Hero geçişiyle detay sayfasını açar.
  void _openBook(BookCollection collection, Book book) {
    final tag = 'shelf-${collection.id}-${book.id}';
    final spineColor = spineBaseColor(book, _hex(collection.color));
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 2200),
        reverseTransitionDuration: const Duration(milliseconds: 1150),
        pageBuilder: (_, __, ___) => DiaryPage(
          bookId: book.id,
          heroTag: tag,
          initialCoverUrl: book.coverUrl,
          initialSpineColor: spineColor,
          initialFinished: book.isFinished,
        ),
        // Karanlık sahne uçuş boyunca rafı karartır; detay sayfası ise ancak
        // kitap kapağa OTURDUKTAN sonra (0.80+) yumuşakça yükselip açılır.
        transitionsBuilder: (context, anim, __, child) {
          return AnimatedBuilder(
            animation: anim,
            builder: (context, _) {
              final t = anim.value;
              if (t >= 1.0) return child;
              final scrim =
                  (t / 0.16).clamp(0.0, 1.0) *
                  (1 - ((t - 0.82) / 0.16).clamp(0.0, 1.0));
              final reveal = Curves.easeOutCubic.transform(
                ((t - 0.80) / 0.20).clamp(0.0, 1.0),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: const Color(
                          0xFF0B0716,
                        ).withValues(alpha: 0.92 * scrim),
                      ),
                    ),
                  ),
                  if (reveal > 0)
                    Opacity(
                      opacity: reveal,
                      child: Transform.translate(
                        offset: Offset(0, (1 - reveal) * 30),
                        child: Transform.scale(
                          scale: 0.96 + 0.04 * reveal,
                          child: child,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------------- Düzenleme modu ----------------
  void _enterEdit(BookCollection collection, Book book) {
    HapticFeedback.mediumImpact();
    setState(() {
      _editMode = true;
      _selected.add((collection.id, book.id));
    });
  }

  void _exitEdit() {
    setState(() {
      _editMode = false;
      _selected.clear();
    });
  }

  void _toggleSelect(BookCollection collection, Book book) {
    final key = (collection.id, book.id);
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  /// Raftaki sırayı kaydeder (iyimser, sonra sunucuya yazar).
  Future<void> _reorder(BookCollection collection, List<int> orderedIds) async {
    setState(() {
      _collections = _collections
          .map(
            (c) => c.id == collection.id
                ? BookCollection(
                    id: c.id,
                    name: c.name,
                    color: c.color,
                    bookIds: orderedIds,
                    displayModes: c.displayModes,
                  )
                : c,
          )
          .toList();
    });
    try {
      await _service.reorder(collection.id, orderedIds);
    } catch (_) {
      if (mounted) await _load();
    }
  }

  /// Seçili kitaplar için toplu işlem menüsü.
  Future<void> _bulkEdit() async {
    if (_selected.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkEditSheet(count: _selected.length),
    );
    if (action == null || !mounted) return;
    if (action.startsWith('mode:')) {
      final mode = shelfDisplayModeFromString(action.substring(5));
      await _applyToSelected(
        (cid, bid) => _service.setDisplayMode(cid, bid, mode),
        localUpdate: (c) {
          final modes = Map<int, ShelfDisplayMode>.from(c.displayModes);
          for (final (cid, bid) in _selected) {
            if (cid == c.id) modes[bid] = mode;
          }
          return c.copyWith(displayModes: modes);
        },
      );
    } else if (action == 'remove') {
      await _applyToSelected((cid, bid) => _service.removeBook(cid, bid));
      if (mounted) await _load();
    }
    if (mounted) _exitEdit();
  }

  Future<void> _applyToSelected(
    Future<void> Function(int collectionId, int bookId) op, {
    BookCollection Function(BookCollection)? localUpdate,
  }) async {
    final items = List<(int, int)>.of(_selected);
    if (localUpdate != null) {
      setState(() {
        _collections = _collections.map(localUpdate).toList();
      });
    }
    for (final (cid, bid) in items) {
      try {
        await op(cid, bid);
      } catch (_) {}
    }
  }

  void _goTab(HeaderTab tab) {
    Navigator.pushReplacementNamed(
      context,
      tab == HeaderTab.home ? AppRoutes.home : AppRoutes.books,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: MainAppBar(
        activeTab: HeaderTab.books,
        titleOverride: 'Kitaplığım',
        subtitleOverride: 'Raflarım',
        onNavSelected: _goTab,
        onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
        onFavorites: () => Navigator.pushNamed(context, AppRoutes.favorites),
        onInsights: () => Navigator.pushNamed(context, AppRoutes.insights),
      ),
      floatingActionButton: _editMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_selected.isNotEmpty)
                  Badge.count(
                    count: _selected.length,
                    child: FloatingActionButton.extended(
                      heroTag: 'edit',
                      onPressed: _bulkEdit,
                      elevation: 3,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text(
                        'Düzenle',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                FloatingActionButton(
                  heroTag: 'done',
                  backgroundColor: const Color(0xFF2BAE8A),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  tooltip: 'Düzenlemeyi bitir',
                  onPressed: _exitEdit,
                  child: const Icon(Icons.check_rounded, size: 28),
                ),
              ],
            )
          : FloatingActionButton.small(
              heroTag: 'new-shelf',
              tooltip: 'Yeni raf',
              onPressed: _create,
              backgroundColor: const Color(0xFFFFE9C7),
              foregroundColor: const Color(0xFF4A2A16),
              elevation: 5,
              child: const Icon(Icons.add_rounded, size: 24),
            ),
      bottomNavigationBar: MainNavigation(
        current: null,
        allowCurrentSelection: true,
        onTabSelected: _goTab,
        onAddPressed: () => showBookAddLauncher(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  14,
                  14,
                  14,
                  bottomNavInset(context),
                ),
                children: [
                  _LibraryCabinet(
                    collections: _collections,
                    allBooks: _books,
                    shelfCount: _collections.length,
                    bookCount: _collections.fold<int>(
                      0,
                      (total, item) => total + item.bookIds.length,
                    ),
                    onCreate: _create,
                    onDelete: _deleteCollection,
                    onAddBooks: _addBooksToCollection,
                    onEditShelf: _editCollection,
                    onOpenShelf: _openCollection,
                    onOpenBook: _openBook,
                    editMode: _editMode,
                    selected: _selected,
                    onEnterEdit: _enterEdit,
                    onToggleSelect: _toggleSelect,
                    onReorder: _reorder,
                  ),
                ],
              ),
            ),
    );
  }
}

class _CabinetHeaderPanel extends StatelessWidget {
  const _CabinetHeaderPanel({
    required this.wood,
    required this.shelfCount,
    required this.bookCount,
    required this.onCreate,
  });

  final _WoodTones wood;
  final int shelfCount;
  final int bookCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFFFE9C7);
    const gold = Color(0xFFE7C27A);
    return shelfCount >= 0
        ? _RefinedCabinetHeader(
            shelfCount: shelfCount,
            bookCount: bookCount,
            wood: wood,
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 2, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 18,
                            color: gold,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'KİŞİSEL KİTAPLIĞIM',
                            style: TextStyle(
                              color: gold,
                              fontSize: 11,
                              letterSpacing: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Her raf başka\nbir dünyaya açılır.',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: cream,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                              letterSpacing: -.7,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: .45),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _LibraryStat(
                            icon: Icons.shelves,
                            value: '$shelfCount raf',
                          ),
                          _LibraryStat(
                            icon: Icons.menu_book_rounded,
                            value: '$bookCount kitap',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Image.asset(
                      'assets/mascot/bilge-reading.png',
                      width: 78,
                      height: 78,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_library_rounded,
                        size: 56,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FilledButton.tonalIcon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Yeni raf'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cream,
                        foregroundColor: wood.frameDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
  }
}

class _LibraryStat extends StatelessWidget {
  const _LibraryStat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: const Color(0xFFE7C27A).withValues(alpha: .4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE7C27A)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFE9C7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// Kitaplık karkas ölçüleri (yan dikme, tepe kornişi, taban yüksekliği).
class _RefinedCabinetHeader extends StatelessWidget {
  const _RefinedCabinetHeader({
    required this.shelfCount,
    required this.bookCount,
    required this.wood,
  });

  final int shelfCount;
  final int bookCount;
  final _WoodTones wood;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE7C27A);
    return SizedBox(
      height: 188,
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: Transform.translate(
              offset: const Offset(0, 21),
              child: Transform.scale(
                scale: 1.13,
                alignment: Alignment.bottomCenter,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(0, 3, 0, 0),
                  child: _BlinkingArmchairBilge(),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 15, 6, 14),
              child: Center(
                child: _CarvedWoodPlaque(
                  wood: wood,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PlaqueStat(value: '$shelfCount', label: 'RAF'),
                      Container(
                        height: 1,
                        width: 64,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: gold.withValues(alpha: .4),
                      ),
                      _PlaqueStat(value: '$bookCount', label: 'KİTAP'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plakadaki tek istatistik satırı — büyük sayı + küçük etiket.
class _PlaqueStat extends StatelessWidget {
  const _PlaqueStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFFFE9C7),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
            height: 1,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE7C27A),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CarvedWoodPlaque extends StatelessWidget {
  const _CarvedWoodPlaque({required this.wood, required this.child});

  final _WoodTones wood;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CarvedWoodPlaquePainter(wood),
      child: SizedBox(
        height: 76,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
      ),
    );
  }
}

class _CarvedWoodPlaquePainter extends CustomPainter {
  const _CarvedWoodPlaquePainter(this.wood);

  final _WoodTones wood;

  Path _shape(Rect r) {
    final mid = r.center.dy;
    return Path()
      ..moveTo(r.left + 13, r.top)
      ..lineTo(r.right - 13, r.top)
      ..quadraticBezierTo(r.right - 3, r.top, r.right - 3, r.top + 11)
      ..lineTo(r.right - 3, mid - 9)
      ..quadraticBezierTo(r.right + 5, mid, r.right - 3, mid + 9)
      ..lineTo(r.right - 3, r.bottom - 11)
      ..quadraticBezierTo(r.right - 3, r.bottom, r.right - 13, r.bottom)
      ..lineTo(r.left + 13, r.bottom)
      ..quadraticBezierTo(r.left + 3, r.bottom, r.left + 3, r.bottom - 11)
      ..lineTo(r.left + 3, mid + 9)
      ..quadraticBezierTo(r.left - 5, mid, r.left + 3, mid - 9)
      ..lineTo(r.left + 3, r.top + 11)
      ..quadraticBezierTo(r.left + 3, r.top, r.left + 13, r.top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = _shape(rect.deflate(6));
    canvas.drawShadow(outer, Colors.black.withValues(alpha: .72), 8, false);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [wood.boardLight, wood.board, wood.frameDark],
          stops: const [0, .52, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFE7C27A).withValues(alpha: .92),
    );
    final inner = _shape(rect.deflate(11));
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: .42),
    );
    canvas.drawLine(
      Offset(19, 10),
      Offset(size.width - 19, 10),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: .17),
    );
    final stud = Paint()..color = const Color(0xFFE7C27A);
    canvas.drawCircle(Offset(13, size.height / 2), 2.3, stud);
    canvas.drawCircle(Offset(size.width - 13, size.height / 2), 2.3, stud);
  }

  @override
  bool shouldRepaint(_CarvedWoodPlaquePainter oldDelegate) =>
      oldDelegate.wood != wood;
}

class _BlinkingArmchairBilge extends StatefulWidget {
  const _BlinkingArmchairBilge();

  @override
  State<_BlinkingArmchairBilge> createState() => _BlinkingArmchairBilgeState();
}

class _BlinkingArmchairBilgeState extends State<_BlinkingArmchairBilge> {
  Timer? _timer;
  bool _eyesClosed = false;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      const AssetImage('assets/mascot/bilge-armchair-reading.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot/bilge-armchair-reading-wink.png'),
      context,
    );
  }

  void _scheduleBlink() {
    final wait = Duration(milliseconds: 2800 + math.Random().nextInt(1800));
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() => _eyesClosed = true);
      _timer = Timer(const Duration(milliseconds: 190), () {
        if (!mounted) return;
        setState(() => _eyesClosed = false);
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _eyesClosed
          ? 'assets/mascot/bilge-armchair-reading-wink.png'
          : 'assets/mascot/bilge-armchair-reading.png',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
    );
  }
}

const double _postW = 18;
const double _corniceH = 26;
const double _baseH = 28;

class _LibraryCabinet extends StatelessWidget {
  const _LibraryCabinet({
    required this.collections,
    required this.allBooks,
    required this.shelfCount,
    required this.bookCount,
    required this.onCreate,
    required this.onDelete,
    required this.onAddBooks,
    required this.onEditShelf,
    required this.onOpenShelf,
    required this.onOpenBook,
    required this.editMode,
    required this.selected,
    required this.onEnterEdit,
    required this.onToggleSelect,
    required this.onReorder,
  });

  final List<BookCollection> collections;
  final List<Book> allBooks;
  final int shelfCount;
  final int bookCount;
  final VoidCallback onCreate;
  final Future<void> Function(BookCollection collection) onDelete;
  final Future<void> Function(BookCollection collection) onAddBooks;
  final void Function(BookCollection collection) onEditShelf;
  final Future<void> Function(BookCollection collection, List<Book> books)
  onOpenShelf;
  final void Function(BookCollection collection, Book book) onOpenBook;
  final bool editMode;
  final Set<(int, int)> selected;
  final void Function(BookCollection collection, Book book) onEnterEdit;
  final void Function(BookCollection collection, Book book) onToggleSelect;
  final Future<void> Function(BookCollection collection, List<int> orderedIds)
  onReorder;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wood = _WoodTones.of(dark);
    final byId = {for (final b in allBooks) b.id: b};
    return Container(
      decoration: BoxDecoration(
        color: wood.frame,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: wood.frameDark, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .42),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Sürekli ahşap arkalık (lambri) — tüm gövde boyunca tek parça
            Positioned.fill(
              child: CustomPaint(painter: _CabinetBackPainter(wood)),
            ),
            // Taç + başlık + raflar + taban — tek gövde
            Column(
              children: [
                _CabinetCornice(wood: wood),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _postW),
                  child: Column(
                    children: [
                      _CabinetHeaderPanel(
                        wood: wood,
                        shelfCount: shelfCount,
                        bookCount: bookCount,
                        onCreate: onCreate,
                      ),
                      _ShelfBoard(wood: wood),
                      for (final collection in collections)
                        _BookshelfSection(
                          collection: collection,
                          // bookIds sırasına göre diz (manuel sıralama burada uygulanır)
                          books: [
                            for (final id in collection.bookIds)
                              if (byId[id] != null) byId[id]!,
                          ],
                          wood: wood,
                          onOpen: onOpenShelf,
                          onDelete: onDelete,
                          onAddBooks: onAddBooks,
                          onEditShelf: onEditShelf,
                          onOpenBook: onOpenBook,
                          editMode: editMode,
                          selected: selected,
                          onEnterEdit: onEnterEdit,
                          onToggleSelect: onToggleSelect,
                          onReorder: onReorder,
                        ),
                      _NewShelfSlot(onCreate: onCreate, wood: wood),
                    ],
                  ),
                ),
                _CabinetBase(wood: wood),
              ],
            ),
            // Yan dikmeler — taç ile taban arasında, raf kenarlarına gölge düşürür
            Positioned(
              left: 0,
              top: _corniceH,
              bottom: _baseH,
              child: IgnorePointer(child: _Post(wood: wood, left: true)),
            ),
            Positioned(
              right: 0,
              top: _corniceH,
              bottom: _baseH,
              child: IgnorePointer(child: _Post(wood: wood, left: false)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kitaplığın tepe tahtası (taç) — hafif aydınlık, altına gölge düşürür.
class _CabinetCornice extends StatelessWidget {
  const _CabinetCornice({required this.wood});

  final _WoodTones wood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _corniceH,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(wood.boardLight, Colors.white, .16)!,
                    wood.board,
                    wood.frameDark,
                  ],
                  stops: const [0, .5, 1],
                ),
              ),
            ),
          ),
          // Üst kenar parlaması
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: ColoredBox(color: Colors.white.withValues(alpha: .26)),
          ),
          // Alt gölge (başlığa düşer)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .42),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kitaplığın yan dikmesi — silindirik kabartma (orta highlight) + iç gölge.
class _Post extends StatelessWidget {
  const _Post({required this.wood, required this.left});

  final _WoodTones wood;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _postW,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    wood.frameDark,
                    wood.board,
                    Color.lerp(wood.boardLight, Colors.white, .12)!,
                    wood.board,
                    wood.frameDark,
                  ],
                  stops: const [0, .28, .5, .72, 1],
                ),
              ),
            ),
          ),
          // İç kenara doğru gölge (raf oyuğunun derinliği)
          Align(
            alignment: left ? Alignment.centerRight : Alignment.centerLeft,
            child: SizedBox(
              width: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: left ? Alignment.centerRight : Alignment.centerLeft,
                    end: left ? Alignment.centerLeft : Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: .5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kitaplığın taban tahtası (plinth).
class _CabinetBase extends StatelessWidget {
  const _CabinetBase({required this.wood});

  final _WoodTones wood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _baseH,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(wood.boardLight, Colors.white, .08)!,
                    wood.board,
                    wood.frameDark,
                  ],
                  stops: const [0, .4, 1],
                ),
              ),
            ),
          ),
          // Üst kenar parlaması
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1.5,
            child: ColoredBox(color: Colors.white.withValues(alpha: .18)),
          ),
          // Hemen üstüne (raflara) düşen koyu seam
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookshelfSection extends StatelessWidget {
  const _BookshelfSection({
    required this.collection,
    required this.books,
    required this.wood,
    required this.onOpen,
    required this.onDelete,
    required this.onAddBooks,
    required this.onEditShelf,
    required this.onOpenBook,
    required this.editMode,
    required this.selected,
    required this.onEnterEdit,
    required this.onToggleSelect,
    required this.onReorder,
  });

  final BookCollection collection;
  final List<Book> books;
  final _WoodTones wood;
  final Future<void> Function(BookCollection collection, List<Book> books)
  onOpen;
  final Future<void> Function(BookCollection collection) onDelete;
  final Future<void> Function(BookCollection collection) onAddBooks;
  final void Function(BookCollection collection) onEditShelf;
  final void Function(BookCollection collection, Book book) onOpenBook;
  final bool editMode;
  final Set<(int, int)> selected;
  final void Function(BookCollection collection, Book book) onEnterEdit;
  final void Function(BookCollection collection, Book book) onToggleSelect;
  final Future<void> Function(BookCollection collection, List<int> orderedIds)
  onReorder;

  void _showShelfActions(BuildContext context, Color color) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ShelfActionsSheet(
        name: collection.name,
        color: color,
        onOpen: () {
          Navigator.pop(sheetCtx);
          onOpen(collection, List<Book>.of(books));
        },
        onAdd: () {
          Navigator.pop(sheetCtx);
          onAddBooks(collection);
        },
        onEdit: () {
          Navigator.pop(sheetCtx);
          onEditShelf(collection);
        },
        onDelete: () {
          Navigator.pop(sheetCtx);
          onDelete(collection);
        },
      ),
    );
  }

  Widget _displayRow(Color color) {
    // Görünüm biçimine göre ayır: yatay yığın hariç hepsi sırayla, yığın sona.
    final inline = <Book>[];
    final stacked = <Book>[];
    for (final book in books) {
      if (collection.displayModeFor(book.id) == ShelfDisplayMode.stack) {
        stacked.add(book);
      } else {
        inline.add(book);
      }
    }

    final rowChildren = <Widget>[];
    for (final book in inline) {
      final tag = 'shelf-${collection.id}-${book.id}';
      final base = spineBaseColor(book, color);
      final isFace =
          collection.displayModeFor(book.id) == ShelfDisplayMode.face;
      rowChildren.add(
        Align(
          alignment: Alignment.bottomCenter,
          child: isFace
              ? _BookFaceOut(
                  book: book,
                  spineColor: base,
                  tag: tag,
                  onTap: () => onOpenBook(collection, book),
                  onLongPress: () => onEnterEdit(collection, book),
                )
              : BookSpine(
                  book: book,
                  base: base,
                  index: book.id,
                  tag: tag,
                  onTap: () => onOpenBook(collection, book),
                  onLongPress: () => onEnterEdit(collection, book),
                ),
        ),
      );
    }
    if (stacked.isNotEmpty) {
      rowChildren.add(
        Align(
          alignment: Alignment.bottomCenter,
          child: _BookStack(
            collection: collection,
            books: stacked,
            shelfColor: color,
            onOpenBook: onOpenBook,
            onEnterEdit: onEnterEdit,
          ),
        ),
      );
    }
    rowChildren.add(
      Align(
        alignment: Alignment.bottomCenter,
        child: _AddBookToShelfButton(
          color: color,
          onTap: () => onAddBooks(collection),
        ),
      ),
    );

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(15, 16, 20, 0),
      itemCount: rowChildren.length,
      separatorBuilder: (_, __) => const SizedBox(width: 4),
      itemBuilder: (_, i) => rowChildren[i],
    );
  }

  Widget _editRow(Color color) {
    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 6),
      itemCount: books.length,
      // Sürüklenen öğenin arkasındaki beyaz Material'i kaldır — temiz görünüm.
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final lift = Curves.easeOut.transform(animation.value);
            return Material(
              type: MaterialType.transparency,
              child: Transform.scale(scale: 1 + 0.1 * lift, child: child),
            );
          },
          child: child,
        );
      },
      // onReorderItem, taşınan öğe listeden çıkarıldıktan sonraki hedef
      // sırayı veriyor; eski onReorder'da elle yapılan -1 düzeltmesine
      // artık gerek yok.
      onReorderItem: (oldI, newI) {
        final ids = books.map((b) => b.id).toList();
        final moved = ids.removeAt(oldI);
        ids.insert(newI, moved);
        onReorder(collection, ids);
      },
      itemBuilder: (context, i) {
        final book = books[i];
        return Padding(
          key: ValueKey('edit-${book.id}'),
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: _EditTile(
              book: book,
              color: color,
              selected: selected.contains((collection.id, book.id)),
              onTap: () => onToggleSelect(collection, book),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hex(collection.color);
    return Column(
      children: [
        SizedBox(
          height: 226,
          child: Stack(
            children: [
              // Rafa özel renk astarı (arkalık keçesi) — renk seçimi burada anlam kazanır
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: .26),
                          color.withValues(alpha: .08),
                          Colors.transparent,
                        ],
                        stops: const [0, .5, 1],
                      ),
                    ),
                  ),
                ),
              ),
              // Üstten yumuşak raf ışığı (sürekli arkalık üstünde)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 78,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          wood.light.withValues(alpha: .16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: _ShelfLabel(
                  name: collection.name,
                  count: books.length,
                  color: color,
                  onTap: () => _showShelfActions(context, color),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 42,
                bottom: 0,
                child: books.isEmpty
                    ? _EmptyShelfRow(
                        color: color,
                        onTap: () => onAddBooks(collection),
                      )
                    : editMode
                    ? _editRow(color)
                    : _displayRow(color),
              ),
            ],
          ),
        ),
        _ShelfBoard(wood: wood),
      ],
    );
  }
}

/// Yatay yığın — "stack" biçimli kitaplar üst üste yatay olarak dizilir.
class _BookStack extends StatelessWidget {
  const _BookStack({
    required this.collection,
    required this.books,
    required this.shelfColor,
    required this.onOpenBook,
    required this.onEnterEdit,
  });

  final BookCollection collection;
  final List<Book> books;
  final Color shelfColor;
  final void Function(BookCollection collection, Book book) onOpenBook;
  final void Function(BookCollection collection, Book book) onEnterEdit;

  @override
  Widget build(BuildContext context) {
    const maxVisible = 7;
    final visible = books.length <= maxVisible
        ? books
        : books.sublist(books.length - maxVisible);
    final extra = books.length - visible.length;

    final slabs = <Widget>[
      for (final book in visible)
        _StackSlab(
          book: book,
          base: spineBaseColor(book, shelfColor),
          tag: 'shelf-${collection.id}-${book.id}',
          onTap: () => onOpenBook(collection, book),
          onLongPress: () => onEnterEdit(collection, book),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '+$extra',
                style: TextStyle(
                  color: const Color(0xFFFFE9C7).withValues(alpha: .8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          for (var i = 0; i < slabs.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i.isOdd ? 7 : 0, top: 2),
              child: slabs[i],
            ),
        ],
      ),
    );
  }
}

/// Yatay yığındaki tek kitap dilimi (yandan, yatay duruş).
class _StackSlab extends StatelessWidget {
  const _StackSlab({
    required this.book,
    required this.base,
    required this.tag,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final Color base;
  final String tag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final thick = book.totalPages <= 0
        ? 0.3
        : (book.totalPages.clamp(60, 900) - 60) / 840;
    final height = 15.0 + thick * 16; // 15–31
    final width = 98.0 + thick * 22; // 98–120
    final gold = Color.lerp(base, const Color(0xFFF2D79A), .72)!;
    final inset = Color.lerp(base, Colors.black, .34)!;
    return BookOpenHero(
      bookId: book.id,
      tag: tag,
      coverUrl: book.coverUrl,
      spineColor: base,
      finished: book.isFinished,
      child: Semantics(
        button: true,
        label: book.title,
        child: Tooltip(
          message: book.title,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(base, Colors.black, .38)!,
                    Color.lerp(base, Colors.black, .08)!,
                    Color.lerp(base, Colors.white, .20)!,
                    Color.lerp(base, Colors.black, .10)!,
                    Color.lerp(base, Colors.black, .42)!,
                  ],
                  stops: const [0, .22, .5, .78, 1],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .34),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 13,
                    top: 0,
                    bottom: 0,
                    width: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: .32),
                            Colors.white.withValues(alpha: .18),
                            Colors.black.withValues(alpha: .30),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 13,
                    top: 0,
                    bottom: 0,
                    width: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: .32),
                            Colors.white.withValues(alpha: .18),
                            Colors.black.withValues(alpha: .30),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 23,
                    right: 23,
                    top: 3,
                    bottom: 3,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: inset.withValues(alpha: .56),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: gold.withValues(alpha: .85),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: gold,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 1.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBookToShelfButton extends StatelessWidget {
  const _AddBookToShelfButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Bu rafa kitap ekle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 48,
          height: 132,
          margin: const EdgeInsets.only(left: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            border: Border.all(color: color.withValues(alpha: .55), width: 1.3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: color, size: 24),
              const SizedBox(height: 5),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'KİTAP',
                  style: TextStyle(
                    color: Color.lerp(color, Colors.white, .45),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sıcak ahşap kütüphane için renk paleti.
class _WoodTones {
  const _WoodTones({
    required this.frame,
    required this.frameDark,
    required this.board,
    required this.boardLight,
    required this.boardDark,
    required this.back,
    required this.backDark,
    required this.light,
  });

  final Color frame;
  final Color frameDark;
  final Color board;
  final Color boardLight;
  final Color boardDark;
  final Color back;
  final Color backDark;
  final Color light;

  factory _WoodTones.of(bool dark) {
    if (dark) {
      return const _WoodTones(
        frame: Color(0xFF4A3322),
        frameDark: Color(0xFF271912),
        board: Color(0xFF5A3D28),
        boardLight: Color(0xFF7C5739),
        boardDark: Color(0xFF2E1D12),
        back: Color(0xFF2C1D13),
        backDark: Color(0xFF180F0A),
        light: Color(0xFFFFC97A),
      );
    }
    return const _WoodTones(
      frame: Color(0xFF8A5A34),
      frameDark: Color(0xFF4A2A16),
      board: Color(0xFF8A5A34),
      boardLight: Color(0xFFB78551),
      boardDark: Color(0xFF5A3A20),
      back: Color(0xFF6E4528),
      backDark: Color(0xFF3E2515),
      light: Color(0xFFFFD89A),
    );
  }
}

/// Kitap sırtı/kapağı için kitaba özgü, sabit taban rengi.

/// Rafın üst etiketi — geniş renkli kurdele: tam ad + kitap sayısı.
/// Dokununca raf işlemleri (aç / kitap ekle / düzenle / kaldır) modalı açılır.
class _ShelfLabel extends StatelessWidget {
  const _ShelfLabel({
    required this.name,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final String name;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Renkli kurdele içeriğe (ada) göre boyutlanır — satır boyu değil.
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 5, 12, 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.black, .3)!],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .42),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bookmark_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Kitap sayısı kartın dışında — minik, soluk.
        const SizedBox(width: 9),
        Text(
          '$count kitap',
          style: TextStyle(
            color: const Color(0xFFFFE9C7).withValues(alpha: .5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Rafa dokununca açılan işlem modalı.
class _ShelfActionsSheet extends StatelessWidget {
  const _ShelfActionsSheet({
    required this.name,
    required this.color,
    required this.onOpen,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _action(context, Icons.open_in_new_rounded, 'Rafı aç', onOpen),
              _action(
                context,
                Icons.add_circle_outline_rounded,
                'Kitap ekle',
                onAdd,
              ),
              _action(
                context,
                Icons.edit_rounded,
                'Adı ve rengi düzenle',
                onEdit,
              ),
              _action(
                context,
                Icons.delete_outline_rounded,
                'Rafı kaldır',
                onDelete,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final fg = danger ? cs.error : cs.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: danger ? cs.error : cs.primary, size: 22),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ahşap raf tahtası — kitapların üstünde durduğu kalın ön kenar.
/// Boş bir raf — "Yeni raf ekle" daveti, kitaplığın kendi gövdesinde.
class _NewShelfSlot extends StatelessWidget {
  const _NewShelfSlot({required this.onCreate, required this.wood});

  final VoidCallback onCreate;
  final _WoodTones wood;

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFFFE9C7);
    const gold = Color(0xFFE7C27A);
    return Column(
      children: [
        SizedBox(
          height: 86,
          child: InkWell(
            onTap: onCreate,
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: gold.withValues(alpha: .5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: gold, width: 1.6),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: gold,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Yeni raf ekle',
                          style: TextStyle(
                            color: cream,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Koleksiyonunu büyüt',
                          style: TextStyle(
                            color: cream.withValues(alpha: .6),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _ShelfBoard(wood: wood),
      ],
    );
  }
}

class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard({required this.wood});

  final _WoodTones wood;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [wood.boardLight, wood.board, wood.boardDark],
          stops: const [0, .35, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .42),
            blurRadius: 9,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          color: Colors.white.withValues(alpha: .18),
        ),
      ),
    );
  }
}

/// Kitaplığın sürekli ahşap arkalığı — dikey lambri tahtaları, damar ve
/// derinlik gölgeleri. Tüm raf yüksekliği boyunca tek parça çizilir.
class _CabinetBackPainter extends CustomPainter {
  _CabinetBackPainter(this.wood);

  final _WoodTones wood;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = wood.back;
    final deeper = Color.lerp(wood.backDark, Colors.black, .15)!;
    final lighter = Color.lerp(base, Colors.white, .10)!;

    // Zemin
    canvas.drawRect(rect, Paint()..color = base);

    // Dikey lambri tahtaları (dikiş gölgesi + ince highlight)
    const planks = 7;
    final pw = size.width / planks;
    final seam = Paint()..color = deeper.withValues(alpha: .6);
    final hi = Paint()..color = lighter.withValues(alpha: .35);
    for (var i = 1; i < planks; i++) {
      final x = i * pw;
      canvas.drawRect(Rect.fromLTWH(x - 1, 0, 2, size.height), seam);
      canvas.drawRect(Rect.fromLTWH(x + 1, 0, 1, size.height), hi);
    }

    // Tahta içi dikey damar
    final rnd = math.Random(11);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < planks; i++) {
      final cx = i * pw + pw * 0.5;
      for (var k = 0; k < 2; k++) {
        grain.color = (k.isEven ? deeper : lighter).withValues(alpha: .10);
        final px = cx + (rnd.nextDouble() - .5) * pw * 0.5;
        final path = Path()..moveTo(px, 0);
        for (double y = 0; y <= size.height; y += 20) {
          path.lineTo(px + math.sin(y / 42 + i + k) * 1.6, y);
        }
        canvas.drawPath(path, grain);
      }
    }

    // Genel derinlik: üstte (kornişin altı) ve dipte karartma + kenarlar
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: .14),
            Colors.transparent,
            Colors.black.withValues(alpha: .22),
          ],
          stops: const [0, .3, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: .26),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: .26),
          ],
          stops: const [0, .1, .9, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CabinetBackPainter oldDelegate) => false;
}

/// Öne dönük sergilenen kitap (favori / okunmakta) — kapağı görünür durur.
class _BookFaceOut extends StatelessWidget {
  const _BookFaceOut({
    required this.book,
    required this.spineColor,
    required this.tag,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final Color spineColor;
  final String tag;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    const w = 104.0;
    const h = 156.0;
    final progress = book.totalPages <= 0
        ? 0.0
        : (book.currentPage / book.totalPages).clamp(0.0, 1.0);
    return BookOpenHero(
      bookId: book.id,
      tag: tag,
      coverUrl: book.coverUrl,
      spineColor: spineColor,
      finished: book.isFinished,
      child: Semantics(
        button: true,
        label: book.title,
        child: Tooltip(
          message: book.title,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .50),
                    blurRadius: 11,
                    offset: const Offset(3, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: spineColor,
                      child: CachedCover(
                        url: book.coverUrl,
                        iconColor: Colors.white70,
                      ),
                    ),
                    // Sırt vurgusu (sol)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: .26),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (book.favorite)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFD66B),
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 3),
                          ],
                        ),
                      ),
                    if (!book.isFinished && progress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 4,
                          alignment: Alignment.centerLeft,
                          color: Colors.black.withValues(alpha: .28),
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(color: const Color(0xFF9EF0C5)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyShelfRow extends StatelessWidget {
  const _EmptyShelfRow({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_add_outlined,
              color: const Color(0xFFFFE9C7).withValues(alpha: .85),
              size: 30,
            ),
            const SizedBox(height: 6),
            Text(
              'Bu raf yeni hikâyelerini bekliyor',
              style: TextStyle(
                color: const Color(0xFFFFE9C7).withValues(alpha: .7),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfBookPicker extends StatefulWidget {
  const _ShelfBookPicker({required this.collection, required this.books});

  final BookCollection collection;
  final List<Book> books;

  @override
  State<_ShelfBookPicker> createState() => _ShelfBookPickerState();
}

class _ShelfBookPickerState extends State<_ShelfBookPicker> {
  final _search = TextEditingController();
  final Set<int> _selected = {};
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _hex(widget.collection.color);
    final normalized = _query.trim().toLowerCase();
    final visible = normalized.isEmpty
        ? widget.books
        : widget.books.where((book) {
            return book.title.toLowerCase().contains(normalized) ||
                (book.author ?? '').toLowerCase().contains(normalized);
          }).toList();

    return FractionallySizedBox(
      heightFactor: .88,
      child: Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: .20),
                      color.withValues(alpha: .05),
                    ],
                  ),
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.shelves, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.collection.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Kütüphanenden kitap seç',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Kitap veya yazar ara',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          'Aramana uygun kitap bulunamadı.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (context, index) {
                          final book = visible[index];
                          final selected = _selected.contains(book.id);
                          return Material(
                            color: selected
                                ? color.withValues(alpha: .11)
                                : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(17),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(17),
                              onTap: () => setState(() {
                                selected
                                    ? _selected.remove(book.id)
                                    : _selected.add(book.id);
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(9),
                                child: Row(
                                  children: [
                                    _BookCover(url: book.coverUrl),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            (book.author ?? '').trim().isEmpty
                                                ? 'Yazar bilgisi yok'
                                                : book.author!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      width: 27,
                                      height: 27,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? color
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selected ? color : cs.outline,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: Text(
                    _selected.isEmpty
                        ? 'Kitap seç'
                        : '${_selected.length} kitabı rafa yerleştir',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: color,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCollectionSheet extends StatefulWidget {
  const _CreateCollectionSheet({
    required this.colors,
    required this.onSubmit,
    this.initialName,
    this.initialColor,
    this.title = 'Yeni raf',
    this.submitLabel = 'Rafı oluştur',
    this.busyLabel = 'Oluşturuluyor',
  });

  final List<String> colors;
  final Future<void> Function(String name, String color) onSubmit;
  final String? initialName;
  final String? initialColor;
  final String title;
  final String submitLabel;
  final String busyLabel;

  @override
  State<_CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends State<_CreateCollectionSheet> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late String _color =
      (widget.initialColor != null &&
          widget.colors.contains(widget.initialColor))
      ? widget.initialColor!
      : widget.colors.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_name.text.trim(), _color);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'İşlem tamamlanamadı.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Raf adı',
                    prefixIcon: Icon(Icons.collections_bookmark_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: widget.colors.map((item) {
                    final selected = _color == item;
                    return InkWell(
                      onTap: () => setState(() => _color = item),
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: selected ? 46 : 40,
                        height: selected ? 46 : 40,
                        decoration: BoxDecoration(
                          color: _hex(item),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? cs.onSurface : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_busy ? widget.busyLabel : widget.submitLabel),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
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

class _BookCover extends StatelessWidget {
  const _BookCover({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: 42,
        height: 58,
        child: ColoredBox(
          color: cs.surfaceContainerHighest,
          child: CachedCover(url: url, iconSize: 20),
        ),
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_add_outlined, size: 54, color: cs.primary),
            const SizedBox(height: 10),
            const Text(
              'Bu raf henüz boş',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 5),
            Text(
              'Kitap ayrıntısındaki menüden bu koleksiyona kitap ekleyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 46),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçili kitaplar için toplu işlem alt sayfası. Seçilen aksiyonu string
/// döndürür: 'mode:spine' | 'mode:face' | 'mode:stack' | 'remove'.
class _BulkEditSheet extends StatelessWidget {
  const _BulkEditSheet({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$count kitap seçili',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Görünüm biçimini değiştir ya da raftan çıkar',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              _action(
                context,
                'mode:spine',
                Icons.view_week_rounded,
                'Yandan (sırt)',
                'Sırtları görünür, dik dursun',
              ),
              _action(
                context,
                'mode:face',
                Icons.image_rounded,
                'Kapağı önde',
                'Kapaklar öne dönük sergilensin',
              ),
              _action(
                context,
                'mode:stack',
                Icons.layers_rounded,
                'Yatay yığın',
                'Yatay, üst üste yığılsın',
              ),
              const SizedBox(height: 6),
              _action(
                context,
                'remove',
                Icons.remove_circle_outline_rounded,
                'Raftan çıkar',
                'Kitaplar silinmez, sadece bu raftan kaldırılır',
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String value,
    IconData icon,
    String title,
    String sub, {
    bool danger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: danger
            ? cs.errorContainer.withValues(alpha: .4)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, value),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: danger ? cs.error : cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: danger ? cs.error : cs.onSurface,
                        ),
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
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

/// Düzenleme modunda raftaki kitap döşemesi — dokun: seç, basılı tut: sürükle.
class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.book,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Book book;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 88,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : Colors.white.withValues(alpha: .25),
                      width: selected ? 3 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .4),
                        blurRadius: 6,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ColoredBox(
                    color: spineBaseColor(book, color),
                    child: CachedCover(
                      url: book.coverUrl,
                      iconColor: Colors.white70,
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 22,
                    color: selected ? cs.primary : Colors.white70,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFE9C7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _hex(String value) {
  final raw = value.replaceFirst('#', '');
  return Color(int.parse('FF$raw', radix: 16));
}
