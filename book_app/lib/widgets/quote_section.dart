import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/book.dart';
import '../models/quote.dart';
import '../pages/journal_gallery.dart';
import '../pages/quote_share_page.dart';
import '../services/api_exception.dart';
import '../services/quote_service.dart';
import 'app_toast.dart';

/// Alıntı kartlarının dönüşümlü vurgu renkleri.
const List<Color> _quoteAccents = [
  Color(0xFFE0A93B),
  Color(0xFF7C5CFF),
  Color(0xFF2BAE8A),
  Color(0xFFF06473),
  Color(0xFF4D8DF7),
];

/// Kitap detayında "Alıntılar" bölümü. Kendi verisini yükler.
class QuoteSection extends StatefulWidget {
  const QuoteSection({super.key, required this.book});
  final Book book;

  @override
  State<QuoteSection> createState() => _QuoteSectionState();
}

class _QuoteSectionState extends State<QuoteSection> {
  final _service = QuoteService();
  List<Quote> _quotes = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final quotes = await _service.fetchQuotes(bookId: widget.book.id);
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// "Ekle" → kitabın alıntı defterine yönlendir (sayfa fotoğrafla, OCR, fosforla).
  Future<void> _openJournal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalGalleryPage(
          bookId: widget.book.id,
          bookTitle: widget.book.title,
          author: widget.book.author,
          coverUrl: widget.book.coverUrl,
        ),
      ),
    );
    if (!mounted) return;
    // Defterde fosforlanan alıntılar buraya yansısın.
    await _load();
  }

  Future<void> _addManual() async {
    final result = await showModalBottomSheet<({String text, int? page})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddQuoteSheet(maxPage: widget.book.totalPages),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await _service.createQuote(
        bookId: widget.book.id,
        text: result.text,
        page: result.page,
      );
      await _load();
      if (!mounted) return;
      AppToast.success(
        context,
        'Alıntın deftere işlendi.',
        title: 'Güzel bir satır',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message, title: 'Alıntı eklenemedi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Quote q) async {
    setState(() => _quotes = _quotes.where((x) => x.id != q.id).toList());
    try {
      await _service.deleteQuote(q.id);
    } catch (_) {
      await _load(); // başarısızsa geri yükle
    }
  }

  void _share(Quote q) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteSharePage(
          text: q.text,
          bookTitle: widget.book.title,
          author: widget.book.author,
          coverUrl: widget.book.coverUrl,
          page: q.page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Alıntılar',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                if (_quotes.isNotEmpty)
                  Text(
                    '${_quotes.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Elle yaz',
                  visualDensity: VisualDensity.compact,
                  onPressed: _busy ? null : _addManual,
                  icon: const Icon(Icons.keyboard_rounded, size: 20),
                ),
                const SizedBox(width: 2),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _openJournal,
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: const Text('Ekle'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_quotes.isEmpty)
            _EmptyQuotes(
              onAdd: _busy ? null : _openJournal,
              onManual: _busy ? null : _addManual,
            )
          else
            ..._quotes.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _QuoteCard(
                  quote: q,
                  onShare: () => _share(q),
                  onDelete: () => _delete(q),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quote,
    required this.onShare,
    required this.onDelete,
  });
  final Quote quote;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _quoteAccents[quote.id.abs() % _quoteAccents.length];
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sol renkli kurdele (vurgu)
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Positioned(
                          left: -4,
                          top: -16,
                          child: Text(
                            '“',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 56,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: accent.withValues(alpha: .20),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14, top: 4),
                          child: Text(
                            quote.text,
                            style: GoogleFonts.lora(
                              color: cs.onSurface,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              height: 1.46,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (quote.page != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bookmark_rounded,
                                  size: 12,
                                  color: accent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'sayfa ${quote.page}',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Görsel olarak paylaş',
                          onPressed: onShare,
                          icon: Icon(
                            Icons.ios_share_rounded,
                            size: 19,
                            color: cs.primary,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Sil',
                          onPressed: onDelete,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: cs.onSurfaceVariant,
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
      ),
    );
  }
}

class _EmptyQuotes extends StatelessWidget {
  const _EmptyQuotes({required this.onAdd, required this.onManual});
  final VoidCallback? onAdd;
  final VoidCallback? onManual;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 38,
            color: cs.primary.withValues(alpha: .7),
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz alıntı yok',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sayfayı fotoğrafla, yazı kendiliğinden okunsun; fosforlu kalemle '
            'sevdiğin satırları işaretle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Alıntı defterini aç'),
          ),
          TextButton.icon(
            onPressed: onManual,
            icon: const Icon(Icons.keyboard_rounded, size: 18),
            label: const Text('Elle yaz'),
          ),
        ],
      ),
    );
  }
}

class _AddQuoteSheet extends StatefulWidget {
  const _AddQuoteSheet({required this.maxPage});
  final int maxPage;

  @override
  State<_AddQuoteSheet> createState() => _AddQuoteSheetState();
}

class _AddQuoteSheetState extends State<_AddQuoteSheet> {
  final _text = TextEditingController();
  final _page = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    _page.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Bir alıntı metni gir.');
      return;
    }
    final page = int.tryParse(_page.text.trim());
    Navigator.pop(context, (text: text, page: page));
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.format_quote_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Alıntı ekle',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  autofocus: true,
                  maxLines: 5,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Sevdiğin cümle…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _page,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Sayfa (opsiyonel)',
                    prefixIcon: const Icon(Icons.bookmark_outline_rounded),
                    helperText: widget.maxPage > 0
                        ? 'Toplam ${widget.maxPage} sayfa'
                        : null,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Deftere ekle'),
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
