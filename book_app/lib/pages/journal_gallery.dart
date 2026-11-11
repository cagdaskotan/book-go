import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/journal.dart';
import '../widgets/app_sheet.dart';
import '../services/journal_store.dart';
import '../services/ocr_service.dart';
import 'journal_editor.dart' show BookPageReader, kHighlightColors;
import '../widgets/mascot.dart';

/// Anı-defteri galerisi. [bookId] verilirse o kitabın sayfaları + ekleme;
/// null ise tüm sayfalar (gezinme).
class JournalGalleryPage extends StatefulWidget {
  const JournalGalleryPage({
    super.key,
    this.bookId,
    this.bookTitle,
    this.author,
    this.coverUrl,
  });

  final int? bookId;
  final String? bookTitle;
  final String? author;
  final String? coverUrl;

  @override
  State<JournalGalleryPage> createState() => _JournalGalleryPageState();
}

class _JournalGalleryPageState extends State<JournalGalleryPage> {
  final _store = JournalStore.instance;
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
  }

  List<JournalPage> get _pages => widget.bookId != null
      ? _store.pagesForBook(widget.bookId!)
      : _store.allPagesNewestFirst;

  Future<void> _addPage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Sayfa ekle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SourceTile(
                    icon: Icons.photo_camera_rounded,
                    title: 'Sayfayı fotoğrafla',
                    subtitle: 'Kitabın sayfasını kameraya tut',
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  _SourceTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Galeriden seç',
                    subtitle: 'Daha önce çektiğin bir fotoğraf',
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (source == null || widget.bookId == null) return;

    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 90,
      );
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // Cihaz-içi OCR — sayfadaki yazıyı çıkar.
      String text = '';
      try {
        text = await OcrService.recognize(picked.path);
      } catch (_) {}
      final page = await _store.addPage(widget.bookId!, picked.path, text);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookPageReader(
            page: page,
            bookId: widget.bookId!,
            bookTitle: widget.bookTitle ?? 'Defter sayfası',
            author: widget.author,
            coverUrl: widget.coverUrl,
          ),
        ),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fotoğraf alınamadı.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bookId != null ? 'Sayfa defteri' : 'Sayfa Defterim',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButton: widget.bookId != null
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _addPage,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_rounded),
              label: const Text('Sayfa ekle'),
            )
          : null,
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          final pages = _pages;
          if (pages.isEmpty) {
            return _EmptyJournal(
              canAdd: widget.bookId != null,
              onAdd: _addPage,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .70,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: pages.length,
            itemBuilder: (_, i) {
              final p = pages[i];
              return _JournalCard(
                page: p,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookPageReader(
                        page: p,
                        bookId: p.bookId,
                        bookTitle: widget.bookTitle ?? 'Defter sayfası',
                        author: widget.author,
                        coverUrl: widget.coverUrl,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                onDelete: () => _confirmDelete(p),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(JournalPage p) async {
    final ok = await showAppConfirm(
      context,
      title: 'Sayfa silinsin mi?',
      message: 'Bu sayfa ve üzerindeki post-it’ler kaldırılır.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (ok == true) await _store.deletePage(p.id);
  }
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.page,
    required this.onTap,
    required this.onDelete,
  });

  final JournalPage page;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = page.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    // Sayfadaki fosfor renklerini topla (tekil), küçük noktalar olarak göster.
    final usedColors = <int>{
      for (final h in page.highlights) h.colorIndex,
    }.take(5).toList();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: CustomPaint(
          painter: _CardPaperPainter(),
          foregroundPainter: _DogEarPainter(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 22, 4),
                  child: Text(
                    preview.isEmpty ? 'Boş sayfa' : preview,
                    maxLines: 8,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      color: Color(0xFF4B3E2C),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                color: const Color(0x14000000),
                child: Row(
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 16,
                      color: Color(0xFF7A6A4E),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${page.highlights.length}',
                      style: const TextStyle(
                        color: Color(0xFF7A6A4E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    for (final c in usedColors)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: kHighlightColors[c % kHighlightColors.length],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: .5),
                        ),
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

/// Kart için sıcak kâğıt zemini + soluk yatay defter çizgisi.
class _CardPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F1E0), Color(0xFFEFE4CB)],
        ).createShader(rect),
    );
    // Üst köşeden yumuşak ışık
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.8, -.9),
          radius: 1.2,
          colors: [
            Colors.white.withValues(alpha: .4),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sağ üst köşede kıvrık sayfa (dog-ear) efekti.
class _DogEarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const ear = 22.0;
    final p = Path()
      ..moveTo(size.width - ear, 0)
      ..lineTo(size.width, ear)
      ..lineTo(size.width - ear, ear)
      ..close();
    // Kıvrık kısmın gölgeli alt yüzü
    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFD8C8A4), Color(0xFFC4B189)],
        ).createShader(Rect.fromLTWH(size.width - ear, 0, ear, ear)),
    );
    // Kıvrım çizgisi
    canvas.drawLine(
      Offset(size.width - ear, 0),
      Offset(size.width - ear, ear),
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(size.width - ear, ear),
      Offset(size.width, ear),
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: cs.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.reading, size: 104),
            const SizedBox(height: 14),
            Text(
              'Defterin henüz boş',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              canAdd
                  ? 'Kitabın bir sayfasını fotoğrafla; yazı otomatik okunur, sayfa gibi açılır, fosforlu kalemle alıntılarını işaretlersin.'
                  : 'Bir kitabın detayından sayfa fotoğraflayarak defterini oluşturmaya başla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            if (canAdd) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('İlk sayfanı ekle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
