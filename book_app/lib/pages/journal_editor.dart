import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/journal.dart';
import '../services/journal_store.dart';
import '../services/quote_service.dart';
import 'quote_share_page.dart';

/// Fosforlu kalem renkleri (yarı saydam vurgu).
const List<Color> kHighlightColors = [
  Color(0xFFFFE066), // sarı
  Color(0xFFFF93B3), // pembe
  Color(0xFF8CE99A), // yeşil
  Color(0xFF74C0FC), // mavi
  Color(0xFFFFB066), // turuncu
];

/// Kitap sayfası okuyucu — OCR metnini gerçek bir sayfa gibi gösterir;
/// fosforlu kalemle bölüm seçip işaretlersin, işaret alıntıya dönüşür.
class BookPageReader extends StatefulWidget {
  const BookPageReader({
    super.key,
    required this.page,
    required this.bookId,
    required this.bookTitle,
    this.author,
    this.coverUrl,
  });

  final JournalPage page;
  final int bookId;
  final String bookTitle;
  final String? author;
  final String? coverUrl;

  @override
  State<BookPageReader> createState() => _BookPageReaderState();
}

class _BookPageReaderState extends State<BookPageReader> {
  JournalPage get page => widget.page;
  final _quotes = QuoteService();

  TextSelection? _sel;
  bool _showHighlights = true;
  bool _dirty = false;
  int _textKey = 0; // SelectableText'i sıfırlamak için
  int _penColor = 0;

  @override
  void dispose() {
    if (_dirty) JournalStore.instance.savePage(page);
    super.dispose();
  }

  void _save() {
    JournalStore.instance.savePage(page);
    _dirty = false;
  }

  // ---------------- Fosforla ----------------
  Future<void> _highlightSelection() async {
    final sel = _sel;
    if (sel == null || sel.isCollapsed) return;
    final s = math.min(sel.start, sel.end).clamp(0, page.text.length);
    final e = math.max(sel.start, sel.end).clamp(0, page.text.length);
    if (e <= s) return;
    final snippet = page.text.substring(s, e).trim();
    if (snippet.isEmpty) return;

    final hl = Highlight(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      start: s,
      end: e,
      colorIndex: _penColor,
    );
    HapticFeedback.selectionClick();
    setState(() {
      page.highlights.add(hl);
      _sel = null;
      _textKey++; // seçimi temizle
      _dirty = true;
    });
    _save();

    // Kitabın alıntı sistemine de ekle (kitap detayındaki "Alıntılar"da görünür).
    try {
      await _quotes.createQuote(bookId: widget.bookId, text: snippet);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alıntı kaydedildi ✦'),
            duration: Duration(milliseconds: 1100),
          ),
        );
      }
    } catch (_) {
      // Alıntı sunucuya gitmese de yerel işaret durur.
    }
  }

  void _deleteHighlight(Highlight h) {
    setState(() {
      page.highlights.removeWhere((x) => x.id == h.id);
      _textKey++;
      _dirty = true;
    });
    _save();
  }

  Future<void> _editNote(Highlight h) async {
    final controller = TextEditingController(text: h.note);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NoteSheet(controller: controller),
    );
    controller.dispose();
    if (result != null) {
      setState(() {
        h.note = result.trim();
        _dirty = true;
      });
      _save();
    }
  }

  void _changeColor(Highlight h, int c) {
    setState(() {
      h.colorIndex = c;
      _textKey++;
      _dirty = true;
    });
    _save();
  }

  void _shareHighlight(Highlight h) {
    final snippet = page.text
        .substring(
          h.start.clamp(0, page.text.length),
          h.end.clamp(0, page.text.length),
        )
        .trim();
    if (snippet.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteSharePage(
          text: snippet,
          bookTitle: widget.bookTitle,
          author: widget.author,
          coverUrl: widget.coverUrl,
        ),
      ),
    );
  }

  // ---------------- Spanlar ----------------
  List<InlineSpan> _buildSpans(TextStyle base) {
    final text = page.text;
    if (text.isEmpty) return [const TextSpan(text: '')];
    if (!_showHighlights || page.highlights.isEmpty) {
      return [TextSpan(text: text)];
    }
    final sorted = [...page.highlights]..sort((a, b) => a.start.compareTo(b.start));
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final h in sorted) {
      final s = h.start.clamp(0, text.length);
      final e = h.end.clamp(0, text.length);
      if (e <= s || s < cursor) continue; // çakışmaları atla
      if (s > cursor) spans.add(TextSpan(text: text.substring(cursor, s)));
      spans.add(
        TextSpan(
          text: text.substring(s, e),
          style: base.copyWith(
            backgroundColor: kHighlightColors[h.colorIndex % kHighlightColors.length]
                .withValues(alpha: .62),
            color: const Color(0xFF2A2118),
          ),
        ),
      );
      cursor = e;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _sel != null && !_sel!.isCollapsed;
    final base = GoogleFonts.lora(
      fontSize: 17,
      height: 1.62,
      color: const Color(0xFF2E2620),
      fontWeight: FontWeight.w400,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF241B12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF241B12),
        foregroundColor: const Color(0xFFF1E6D2),
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.bookTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          if (page.highlights.isNotEmpty)
            IconButton(
              tooltip: _showHighlights ? 'İşaretleri gizle' : 'İşaretleri göster',
              onPressed: () => setState(() => _showHighlights = !_showHighlights),
              icon: Icon(
                _showHighlights
                    ? Icons.highlight_rounded
                    : Icons.highlight_off_rounded,
              ),
            ),
          IconButton(
            tooltip: 'Bu sayfanın alıntıları',
            onPressed: _openHighlightList,
            icon: Badge.count(
              isLabelVisible: page.highlights.isNotEmpty,
              count: page.highlights.length,
              child: const Icon(Icons.format_quote_rounded),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editText();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_note_rounded),
                  title: Text('Metni düzelt'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: _PaperSheet(
                child: page.text.trim().isEmpty
                    ? _EmptyText(onEdit: _editText)
                    : SelectableText.rich(
                        TextSpan(style: base, children: _buildSpans(base)),
                        key: ValueKey('t$_textKey'),
                        textAlign: TextAlign.justify,
                        selectionControls: MaterialTextSelectionControls(),
                        onSelectionChanged: (s, _) =>
                            setState(() => _sel = s),
                      ),
              ),
            ),
          ),
          _PenBar(
            active: hasSelection,
            selected: _penColor,
            onPick: (i) => setState(() => _penColor = i),
            onHighlight: _highlightSelection,
          ),
        ],
      ),
    );
  }

  // ---------------- Alıntı listesi ----------------
  void _openHighlightList() {
    if (page.highlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metinden bir bölüm seçip fosforla; alıntın burada toplansın.'),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final cs = Theme.of(ctx).colorScheme;
            final list = [...page.highlights]
              ..sort((a, b) => a.start.compareTo(b.start));
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * .8,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 12),
                    Text(
                      'Bu sayfanın alıntıları',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final h = list[i];
                          final color =
                              kHighlightColors[h.colorIndex % kHighlightColors.length];
                          final snippet = page.text.substring(
                            h.start.clamp(0, page.text.length),
                            h.end.clamp(0, page.text.length),
                          );
                          return _HighlightTile(
                            snippet: snippet,
                            color: color,
                            note: h.note,
                            onShare: () {
                              Navigator.pop(ctx);
                              _shareHighlight(h);
                            },
                            onNote: () async {
                              await _editNote(h);
                              setSheet(() {});
                            },
                            onColor: () async {
                              final c = await _pickColorDialog(ctx, h.colorIndex);
                              if (c != null) {
                                _changeColor(h, c);
                                setSheet(() {});
                              }
                            },
                            onDelete: () {
                              _deleteHighlight(h);
                              setSheet(() {});
                              if (page.highlights.isEmpty) Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<int?> _pickColorDialog(BuildContext ctx, int current) {
    return showModalBottomSheet<int>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: BoxDecoration(
          color: Theme.of(c).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < kHighlightColors.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(c, i),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: kHighlightColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == i ? Colors.black : Colors.black12,
                          width: current == i ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Metni düzelt ----------------
  Future<void> _editText() async {
    final controller = TextEditingController(text: page.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NoteSheet(
        controller: controller,
        title: 'Metni düzelt',
        hint: 'OCR çıktısını düzelt…',
        minLines: 6,
        maxLines: 18,
      ),
    );
    controller.dispose();
    if (result != null && result != page.text) {
      setState(() {
        page.text = result;
        page.highlights.clear(); // metin değişti, işaretler sıfırlanır
        _textKey++;
        _dirty = true;
      });
      _save();
    }
  }
}

/// Krem kâğıt, gölge, doku — gerçek bir sayfa hissi.
class _PaperSheet extends StatelessWidget {
  const _PaperSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _PaperPainter(),
          child: Container(
            width: double.infinity,
            // sol kenarda ince marj boşluğu — defter hissi
            padding: const EdgeInsets.fromLTRB(30, 30, 24, 30),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Kâğıt dokusu: sıcak degrade, köşe vinyet, sepya marj çizgisi ve lif tanesi.
class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Sıcak kâğıt degradesi
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8F1E2), Color(0xFFF1E7D0), Color(0xFFEADFC6)],
        stops: [0, .55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    // Üstte yumuşak ışık huzmesi
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.1, -.9),
          radius: 1.1,
          colors: [
            Colors.white.withValues(alpha: .35),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // Köşe vinyeti — kenarlara doğru hafif kararma
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: .95,
          colors: [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0x14000000),
          ],
          stops: const [0, .72, 1],
        ).createShader(rect),
    );

    // Sol marj çizgisi (soluk sepya)
    final marginX = 22.0;
    canvas.drawLine(
      Offset(marginX, 0),
      Offset(marginX, size.height),
      Paint()
        ..color = const Color(0x33C08A4B)
        ..strokeWidth = 1.1,
    );

    // İnce lif tanecikleri — sabit tohumlu, kararlı görünüm
    final rnd = math.Random(11);
    final grain = Paint();
    for (var i = 0; i < 140; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final dark = rnd.nextBool();
      grain.color = (dark ? Colors.brown : Colors.white)
          .withValues(alpha: rnd.nextDouble() * .05 + .015);
      canvas.drawCircle(Offset(dx, dy), rnd.nextDouble() * 1.1 + .3, grain);
    }

    // Sağ kenarda ciltten gelen ince gölge
    canvas.drawRect(
      Rect.fromLTWH(size.width - 10, 0, 10, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0x18000000),
            const Color(0x00000000),
          ],
        ).createShader(Rect.fromLTWH(size.width - 10, 0, 10, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) => false;
}

class _PenBar extends StatelessWidget {
  const _PenBar({
    required this.active,
    required this.selected,
    required this.onPick,
    required this.onHighlight,
  });

  final bool active;
  final int selected;
  final ValueChanged<int> onPick;
  final VoidCallback onHighlight;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF38291A), Color(0xFF241A10)],
          ),
          border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
          boxShadow: [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 16,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Durum ipucu — kullanım kolaylığı için
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: active
                  ? const SizedBox.shrink(key: ValueKey('on'))
                  : Padding(
                      key: const ValueKey('off'),
                      padding: const EdgeInsets.only(bottom: 8, top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: .55),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Metinden bir bölüm seç, fosforla',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .6),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Row(
              children: [
                for (var i = 0; i < kHighlightColors.length; i++)
                  GestureDetector(
                    onTap: () => onPick(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: selected == i ? 34 : 30,
                      height: selected == i ? 34 : 30,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: kHighlightColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected == i
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected == i
                            ? [
                                BoxShadow(
                                  color: kHighlightColors[i]
                                      .withValues(alpha: .6),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: active ? onHighlight : null,
                  icon: const Icon(Icons.brush_rounded, size: 18),
                  label: const Text('Fosforla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kHighlightColors[selected],
                    foregroundColor: const Color(0xFF2A2118),
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.snippet,
    required this.color,
    required this.note,
    required this.onShare,
    required this.onNote,
    required this.onColor,
    required this.onDelete,
  });

  final String snippet;
  final Color color;
  final String note;
  final VoidCallback onShare;
  final VoidCallback onNote;
  final VoidCallback onColor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snippet.trim(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
          if (note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '✎ ${note.trim()}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: onNote,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(note.trim().isEmpty ? 'Not ekle' : 'Notu düzenle'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              IconButton(
                tooltip: 'Renk',
                onPressed: onColor,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.palette_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Görsel olarak paylaş',
                onPressed: onShare,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.ios_share_rounded,
                  size: 19,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Sil',
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded, color: cs.error, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteSheet extends StatelessWidget {
  const _NoteSheet({
    required this.controller,
    this.title = 'Not',
    this.hint = 'Bu alıntıya bir not ekle…',
    this.minLines = 2,
    this.maxLines = 5,
  });

  final TextEditingController controller;
  final String title;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
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
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: minLines,
                  maxLines: maxLines,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.text_fields_rounded, size: 44, color: Colors.black26),
        const SizedBox(height: 10),
        const Text(
          'Bu sayfadan yazı okunamadı',
          style: TextStyle(
            color: Color(0xFF5A4B36),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Daha net bir fotoğraf dene ya da metni elle gir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8A795E)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Metni elle gir'),
        ),
      ],
    );
  }
}
