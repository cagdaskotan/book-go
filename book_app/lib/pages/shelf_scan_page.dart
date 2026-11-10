import 'package:flutter/material.dart';

import '../models/catalog_book.dart';
import '../services/book_service.dart';
import '../services/catalog_service.dart';
import '../services/shelf_scan_service.dart';
import '../theme/app_scale.dart';
import '../widgets/app_toast.dart';
import '../widgets/book_cover.dart';
import '../widgets/mascot.dart';

/// Raf fotoğrafından toplu kitap ekleme.
///
/// Gerçek rafın fotoğrafını çek, dijital rafın dolsun. Tek tek barkod
/// okutmak yerine bir kare — bu uygulamanın kimliği zaten raf olduğu için
/// en doğal ekleme yolu bu.
///
/// Tanıma mükemmel olmayabilir, o yüzden hiçbir şey sessizce eklenmiyor:
/// bulunanlar işaretli gelir, kullanıcı listeden çıkarabilir, tanınamayan
/// sırtlar da ham metniyle gösterilip elle düzeltilebilir.
class ShelfScanPage extends StatefulWidget {
  const ShelfScanPage({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ShelfScanPage> createState() => _ShelfScanPageState();
}

class _ShelfScanPageState extends State<ShelfScanPage> {
  /// Tek karede bu kadar sırttan fazlasını aramıyoruz: hem katalog
  /// servislerini yormamak hem kullanıcıyı uzun listede boğmamak için.
  static const int _maxCandidates = 12;

  final _catalog = CatalogService();
  final _books = BookService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_ShelfMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final spines = await ShelfScanService.scanImage(widget.imagePath);
      if (spines.isEmpty) {
        if (!mounted) return;
        setState(() {
          _matches = const [];
          _loading = false;
        });
        return;
      }

      final limited = spines.take(_maxCandidates).toList();
      final matches = <_ShelfMatch>[];
      for (final spine in limited) {
        CatalogBook? best;
        try {
          final results = await _catalog.searchByTitle(spine.text);
          if (results.isNotEmpty) best = results.first;
        } catch (_) {
          // Tek sırt bulunamadıysa tarama durmasın.
        }
        matches.add(
          _ShelfMatch(
            rawText: spine.text,
            book: best,
            // Katalogda karşılığı bulunanlar işaretli gelir; tanınamayanları
            // kullanıcı bilerek seçsin.
            selected: best != null,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Fotoğraf okunamadı. Daha aydınlık bir kare deneyebilirsin.';
        _loading = false;
      });
    }
  }

  int get _selectedCount => _matches.where((m) => m.selected).length;

  Future<void> _addSelected() async {
    final chosen = _matches.where((m) => m.selected && m.book != null);
    if (chosen.isEmpty) return;

    setState(() => _saving = true);
    var added = 0;
    var skipped = 0;

    for (final match in chosen) {
      final book = match.book!;
      try {
        // Zaten kitaplıkta olanı ikinci kez eklemeyelim.
        if (book.isbn.isNotEmpty) {
          final existing = await _books.findByIsbn(book.isbn);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        await _books.createBook(
          title: book.title,
          totalPages: book.totalPages > 0 ? book.totalPages : 1,
          author: book.author,
          publisher: book.publisher,
          isbn: book.isbn.isEmpty ? null : book.isbn,
          coverUrl: book.coverUrl,
          category: book.category,
        );
        added++;
      } catch (_) {
        skipped++;
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, added);
    AppToast.success(
      context,
      skipped > 0
          ? '$added kitap eklendi, $skipped tanesi atlandı.'
          : '$added kitap rafına eklendi.',
      title: 'Raf tarandı',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raftan ekle')),
      body: SafeArea(child: _body()),
      bottomNavigationBar: _matches.isEmpty || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: FilledButton.icon(
                  onPressed: _selectedCount == 0 || _saving
                      ? null
                      : _addSelected,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.library_add_rounded),
                  label: Text(
                    _selectedCount == 0
                        ? 'Kitap seç'
                        : '$_selectedCount kitabı ekle',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _body() {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.reading, size: 110),
            Gap.vLg,
            Text(
              'Rafın okunuyor',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: cs.onSurface,
              ),
            ),
            Gap.vSm,
            Text(
              'Kitap sırtlarındaki yazılar çözülüyor…',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap.vXl,
            const SizedBox(
              width: 180,
              child: LinearProgressIndicator(),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _Message(
        title: 'Okunamadı',
        message: _error!,
        actionLabel: 'Tekrar dene',
        onAction: _scan,
      );
    }

    if (_matches.isEmpty) {
      return const _Message(
        title: 'Sırt okunamadı',
        message:
            'Kitap sırtlarındaki yazılar seçilemedi. Rafa daha yakından, '
            'yazılar yatay olmayacak şekilde ve iyi ışıkta çekmeyi dene.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
      itemCount: _matches.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Text(
              '${_matches.length} sırt okundu. Eklemek istemediklerinin '
              'işaretini kaldır.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          );
        }
        final match = _matches[i - 1];
        return _MatchTile(
          match: match,
          onToggle: () => setState(() => match.selected = !match.selected),
        );
      },
    );
  }
}

/// Okunan bir sırt ve katalogdaki karşılığı.
class _ShelfMatch {
  _ShelfMatch({
    required this.rawText,
    required this.book,
    required this.selected,
  });

  final String rawText;
  final CatalogBook? book;
  bool selected;
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onToggle});

  final _ShelfMatch match;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final book = match.book;
    final found = book != null;

    return Material(
      color: match.selected
          ? cs.primaryContainer.withValues(alpha: .35)
          : cs.surfaceContainerHigh,
      borderRadius: Radii.brLg,
      child: InkWell(
        onTap: found ? onToggle : null,
        borderRadius: Radii.brLg,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: Radii.brSm,
                child: SizedBox(
                  width: 44,
                  height: 62,
                  child: ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: CachedCover(url: book?.coverUrl, iconSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      found ? book.title : match.rawText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      found
                          ? ((book.author ?? '').trim().isEmpty
                                ? 'Yazar bilinmiyor'
                                : book.author!.trim())
                          : 'Katalogda bulunamadı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: found ? cs.onSurfaceVariant : cs.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    if (found) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Rafta okunan: ${match.rawText}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: .7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (found)
                Checkbox(value: match.selected, onChanged: (_) => onToggle())
              else
                Icon(Icons.help_outline_rounded, color: cs.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.encourage, size: 104),
            Gap.vMd,
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: cs.onSurface,
              ),
            ),
            Gap.vXs,
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              Gap.vLg,
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
