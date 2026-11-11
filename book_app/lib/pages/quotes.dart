import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quote.dart';
import '../services/api_exception.dart';
import '../services/quote_service.dart';
import '../theme/app_scale.dart';
import '../utils/turkish.dart';
import '../widgets/app_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/appbar.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/empty_state.dart';
import '../widgets/navigation.dart';
import 'quote_share_page.dart';
import 'routes.dart';

/// Alıntı defteri — kitaplığın tamamından toplanan alıntılar.
///
/// Alıntılar şimdiye dek yalnızca ait oldukları kitabın detay sayfasında
/// duruyordu. Oysa insanın aklında kalan cümle genelde kitapsız geliyor:
/// "şu hatırladığım söz nerede yazıyordu?" Defter o soruya cevap veriyor —
/// hepsini bir arada gösteriyor, metninde ve kitap adında arıyor.
class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  final _service = QuoteService();
  final _searchCtrl = TextEditingController();

  List<Quote> _all = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quotes = await _service.fetchQuotes();
      if (!mounted) return;
      setState(() => _all = quotes);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Alıntılar okunamadı.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Süzülmüş liste — mantığı [filterQuotes] tutuyor, test oradan.
  List<Quote> get _visible =>
      filterQuotes(_all, query: _query, onlyFavorites: _onlyFavorites);

  int get _favoriteCount => _all.where((q) => q.favorite).length;

  Future<void> _toggleFavorite(Quote quote) async {
    HapticFeedback.selectionClick();
    final next = !quote.favorite;
    // İyimser güncelleme: dokunma anında dönsün, sonra kaydedilsin.
    setState(() {
      _all = _all
          .map(
            (q) => q.id == quote.id
                ? Quote(
                    id: q.id,
                    bookId: q.bookId,
                    text: q.text,
                    page: q.page,
                    favorite: next,
                    createdAt: q.createdAt,
                    bookTitle: q.bookTitle,
                    bookAuthor: q.bookAuthor,
                    coverUrl: q.coverUrl,
                  )
                : q,
          )
          .toList();
    });
    try {
      await _service.setFavorite(quote.id, next);
    } catch (_) {
      if (!mounted) return;
      // Kaydedilemediyse eski hâle dön; yanlış bilgi göstermeyelim.
      await _load();
      if (mounted) AppToast.info(context, 'Değişiklik kaydedilemedi.');
    }
  }

  Future<void> _delete(Quote quote) async {
    final ok = await _confirmDelete(context);
    if (ok != true) return;
    try {
      await _service.deleteQuote(quote.id);
      if (!mounted) return;
      setState(() => _all = _all.where((q) => q.id != quote.id).toList());
    } catch (_) {
      if (mounted) AppToast.info(context, 'Alıntı silinemedi.');
    }
  }

  void _share(Quote quote) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QuoteSharePage(
          text: quote.text,
          bookTitle: quote.bookTitle ?? 'Kitap',
          author: quote.bookAuthor,
          coverUrl: quote.coverUrl,
          page: quote.page,
        ),
      ),
    );
  }

  void _openBook(Quote quote) {
    Navigator.pushNamed(context, AppRoutes.diary, arguments: quote.bookId);
  }

  void _goTab(HeaderTab tab) {
    final dest = (tab == HeaderTab.home) ? AppRoutes.home : AppRoutes.books;
    Navigator.pushReplacementNamed(context, dest);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: MainAppBar(
        activeTab: HeaderTab.home,
        showAddButton: false,
        onNavSelected: _goTab,
        onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
        onFavorites: () => Navigator.pushNamed(context, AppRoutes.favorites),
        onCollections: () =>
            Navigator.pushNamed(context, AppRoutes.collections),
      ),
      bottomNavigationBar: MainNavigation(
        current: null,
        allowCurrentSelection: true,
        onTabSelected: _goTab,
        onAddPressed: () => showBookAddLauncher(context),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _QuotesError(message: _error!, onRetry: _load);
    }
    if (_all.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: Gap.screen,
          child: EmptyState(
            title: 'Defterin henüz boş',
            message:
                'Okurken altını çizdiğin cümleleri kitabın sayfasından '
                'ekle; hepsi burada toplanır, aradığında bulursun.',
            actionLabel: 'Kitaplığa git',
            actionIcon: Icons.menu_book_rounded,
            onAction: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.books),
          ),
        ),
      );
    }

    final visible = _visible;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          Gap.lg,
          Gap.lg,
          Gap.lg,
          bottomNavInset(context),
        ),
        itemCount: visible.length + 1,
        separatorBuilder: (_, _) => Gap.vMd,
        itemBuilder: (context, index) {
          if (index == 0) return _header();
          final quote = visible[index - 1];
          return _QuoteCard(
            quote: quote,
            query: _query,
            onFavorite: () => _toggleFavorite(quote),
            onShare: () => _share(quote),
            onDelete: () => _delete(quote),
            onOpenBook: () => _openBook(quote),
          );
        },
      ),
    );
  }

  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;
    final bookCount = _all.map((q) => q.bookId).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alıntı defteri',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_all.length} alıntı · $bookCount kitap',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        Gap.vMd,
        TextField(
          controller: _searchCtrl,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Cümle, kitap ya da yazar ara',
            prefixIcon: const Icon(Icons.search_rounded),
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
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: Radii.brLg,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_favoriteCount > 0) ...[
          Gap.vSm,
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              selected: _onlyFavorites,
              onSelected: (value) => setState(() => _onlyFavorites = value),
              avatar: Icon(
                _onlyFavorites
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                size: 18,
                color: _onlyFavorites ? cs.onSecondaryContainer : null,
              ),
              label: Text('Başucu alıntıları ($_favoriteCount)'),
            ),
          ),
        ],
        if (visible.isEmpty) ...[
          Gap.vXl,
          EmptyState(
            compact: true,
            title: 'Bu aramada alıntı yok',
            message: _onlyFavorites
                ? 'Başucu seçkisinde aradığın cümle görünmüyor. Süzgeci '
                      'kaldırıp tüm deftere bakabilirsin.'
                : 'Başka bir kelime deneyebilirsin; arama cümlede, kitap '
                      'adında ve yazarda birlikte bakıyor.',
          ),
        ] else
          Gap.vXs,
      ],
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context) => showAppConfirm(
  context,
  title: 'Alıntı silinsin mi?',
  message: 'Bu cümle defterinden kaldırılır. Kitabına dokunulmaz.',
  confirmLabel: 'Sil',
  destructive: true,
);

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.query,
    required this.onFavorite,
    required this.onShare,
    required this.onDelete,
    required this.onOpenBook,
  });

  final Quote quote;
  final String query;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onOpenBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.brLg,
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tırnak işareti: kartın alıntı olduğunu bir bakışta söyler.
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: Gap.sm),
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 22,
                    color: cs.primary.withValues(alpha: .55),
                  ),
                ),
                Expanded(
                  child: _Highlighted(
                    text: quote.text,
                    query: query,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onOpenBook,
            child: Container(
              width: double.infinity,
              color: cs.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.sm,
                Gap.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.bookTitle ?? 'Kitap',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          [
                            if ((quote.bookAuthor ?? '').isNotEmpty)
                              quote.bookAuthor!,
                            if (quote.page != null) 's. ${quote.page}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: quote.favorite
                        ? 'Başucundan çıkar'
                        : 'Başucuna ekle',
                    onPressed: onFavorite,
                    icon: Icon(
                      quote.favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      color: quote.favorite ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Paylaş',
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
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

/// Arama sonucunda eşleşen parçayı vurgular.
///
/// Uzun bir alıntıda aradığın kelimenin nerede geçtiğini görmek, listeyi
/// taramaktan hızlı. Türkçe katlama kullanıyor: "İ" ile "i" eşleşiyor.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query, this.style});

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final needle = foldTurkish(query.trim());
    if (needle.isEmpty) return Text(text, style: style);

    final haystack = foldTurkish(text);
    // Katlama harf sayısını korur, o yüzden konumlar birebir örtüşüyor.
    if (haystack.length != text.length) return Text(text, style: style);

    final cs = Theme.of(context).colorScheme;
    final spans = <TextSpan>[];
    var cursor = 0;
    while (true) {
      final hit = haystack.indexOf(needle, cursor);
      if (hit < 0) break;
      if (hit > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, hit)));
      }
      spans.add(
        TextSpan(
          text: text.substring(hit, hit + needle.length),
          style: TextStyle(
            backgroundColor: cs.primary.withValues(alpha: .18),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      cursor = hit + needle.length;
    }
    if (spans.isEmpty) return Text(text, style: style);
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _QuotesError extends StatelessWidget {
  const _QuotesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Gap.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            Gap.vMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Gap.vLg,
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
