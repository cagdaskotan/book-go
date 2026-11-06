import 'dart:async';

import 'package:flutter/material.dart';

import '../models/catalog_book.dart';
import '../services/api_exception.dart';
import '../services/catalog_service.dart';
import 'book_cover.dart';

/// Başlığa göre kitap arama sayfası. Seçilen kitabı [CatalogBook] olarak döndürür.
Future<CatalogBook?> showTitleSearch(BuildContext context) {
  return showModalBottomSheet<CatalogBook>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TitleSearchSheet(),
  );
}

class _TitleSearchSheet extends StatefulWidget {
  const _TitleSearchSheet();

  @override
  State<_TitleSearchSheet> createState() => _TitleSearchSheetState();
}

class _TitleSearchSheetState extends State<_TitleSearchSheet> {
  final _catalog = CatalogService();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<CatalogBook> _results = const [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';
  String? _authorFilter;
  String? _publisherFilter;

  /// Sonuçlardaki yazarları sıklığa göre (en çok görüneni önce) döndürür.
  List<String> get _authors => _topValues((b) => b.author);

  /// Sonuçlardaki yayınevlerini sıklığa göre döndürür.
  List<String> get _publishers => _topValues((b) => b.publisher);

  List<String> _topValues(String? Function(CatalogBook) pick) {
    final counts = <String, int>{};
    for (final b in _results) {
      final v = pick(b)?.trim();
      if (v == null || v.isEmpty) continue;
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).map((e) => e.key).toList();
  }

  List<CatalogBook> get _filtered => _results.where((b) {
    if (_authorFilter != null && (b.author?.trim()) != _authorFilter) {
      return false;
    }
    if (_publisherFilter != null && (b.publisher?.trim()) != _publisherFilter) {
      return false;
    }
    return true;
  }).toList();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String query) async {
    _lastQuery = query;
    try {
      final results = await _catalog.searchByTitle(query);
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = null;
        _authorFilter = null;
        _publisherFilter = null;
      });
    } on ApiException catch (e) {
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _loading = false;
        _error = 'Arama yapılamadı.';
      });
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
        height: MediaQuery.sizeOf(context).height * .88,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
              child: Row(
                children: [
                  Text(
                    'Kitap ara',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.6,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Kitap adını yaz…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Temizle',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Expanded(child: _buildBody(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CenterHint(
        icon: Icons.cloud_off_rounded,
        title: 'Arama yapılamadı',
        message: _error!,
      );
    }
    final q = _controller.text.trim();
    if (q.length < 2) {
      return const _CenterHint(
        icon: Icons.auto_stories_rounded,
        title: 'Aramaya başla',
        message:
            'Kitabın adını yazdığında kapak, yazar ve sayfa bilgisiyle birlikte listelenir.',
      );
    }
    if (_results.isEmpty) {
      return const _CenterHint(
        icon: Icons.search_off_rounded,
        title: 'Sonuç yok',
        message: 'Farklı bir başlık dene ya da elle ekle.',
      );
    }

    final authors = _authors;
    final publishers = _publishers;
    final filtered = _filtered;
    final hasAuthorFilter = authors.length > 1;
    final hasPublisherFilter = publishers.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAuthorFilter || hasPublisherFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(
              children: [
                if (hasAuthorFilter)
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Yazar',
                      icon: Icons.person_outline_rounded,
                      values: authors,
                      selected: _authorFilter,
                      onChanged: (v) => setState(() => _authorFilter = v),
                    ),
                  ),
                if (hasAuthorFilter && hasPublisherFilter)
                  const SizedBox(width: 10),
                if (hasPublisherFilter)
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Yayınevi',
                      icon: Icons.apartment_rounded,
                      values: publishers,
                      selected: _publisherFilter,
                      onChanged: (v) => setState(() => _publisherFilter = v),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? const _CenterHint(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'Bu filtreyle sonuç yok',
                  message: 'Filtreyi değiştir ya da kaldır.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ResultTile(
                    book: filtered[i],
                    onTap: () => Navigator.pop(context, filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Filtre dropdown'u (yazar / yayınevi). "Tümü" ile temizlenir.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Seçili değer listede yoksa (filtre sıfırlandıysa) null göster.
    final value = (selected != null && values.contains(selected))
        ? selected
        : null;
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      selectedItemBuilder: (context) => [
        Text('Tümü', maxLines: 1, overflow: TextOverflow.ellipsis),
        for (final v in values)
          Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Tümü',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final v in values)
          DropdownMenuItem<String?>(
            value: v,
            child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.book, required this.onTap});
  final CatalogBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 48,
                  height: 68,
                  color: cs.surfaceContainerHighest,
                  child: CachedCover(url: book.coverUrl, iconSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (book.author ?? '').trim().isEmpty
                          ? 'Yazar bilgisi yok'
                          : book.author!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (book.totalPages > 0)
                          _MiniTag(
                            text: '${book.totalPages} sayfa',
                            color: cs.primary,
                          ),
                        if ((book.publisher ?? '').trim().isNotEmpty)
                          _MiniTag(
                            text: book.publisher!.trim(),
                            color: cs.onSurfaceVariant,
                            icon: Icons.apartment_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_rounded, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterHint extends StatelessWidget {
  const _CenterHint({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: cs.primary.withValues(alpha: .7)),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
