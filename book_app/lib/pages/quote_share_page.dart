
import 'package:flutter/material.dart';

import '../services/share_image.dart';
import '../widgets/quote_share_card.dart';

/// Bir alıntıyı zarif bir görsele dönüştürüp paylaşma önizlemesi.
class QuoteSharePage extends StatefulWidget {
  const QuoteSharePage({
    super.key,
    required this.text,
    required this.bookTitle,
    this.author,
    this.coverUrl,
    this.page,
  });

  final String text;
  final String bookTitle;
  final String? author;
  final String? coverUrl;
  final int? page;

  @override
  State<QuoteSharePage> createState() => _QuoteSharePageState();
}

class _QuoteSharePageState extends State<QuoteSharePage> {
  final _cardKey = GlobalKey();
  QuoteCardTheme _theme = QuoteCardTheme.paper;
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final caption = StringBuffer()
        ..writeln('“${widget.text.trim()}”')
        ..write('— ${widget.bookTitle}');
      if ((widget.author ?? '').trim().isNotEmpty) {
        caption.write(', ${widget.author!.trim()}');
      }
      await shareWidgetAsImage(
        boundaryKey: _cardKey,
        fileName: 'alinti',
        text: caption.toString(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Görsel oluşturulamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161222),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161222),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Alıntıyı paylaş',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: QuoteShareCard(
                          text: widget.text,
                          bookTitle: widget.bookTitle,
                          author: widget.author,
                          coverUrl: widget.coverUrl,
                          page: widget.page,
                          theme: _theme,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Tema seçici
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final t in QuoteCardTheme.values)
                    _ThemeSwatch(
                      theme: t,
                      selected: _theme == t,
                      onTap: () => setState(() => _theme = t),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(_busy ? 'Hazırlanıyor…' : 'Paylaş'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final QuoteCardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = QuoteCardThemeData.of(theme);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: t.bg),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}
