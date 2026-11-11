import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/share_image.dart';
import '../theme/app_scale.dart';
import '../widgets/year_wrapped_share_card.dart';

/// Yıl karnesinin paylaşım önizlemesi.
///
/// Kullanıcı tam olarak ne paylaşacağını görür, sonra paylaşır. Alıntı
/// paylaşımı da aynı deseni kullanıyor; sürpriz yok.
class YearWrappedSharePage extends StatefulWidget {
  const YearWrappedSharePage({
    super.key,
    required this.year,
    required this.booksFinished,
    required this.pagesRead,
    this.topGenre,
    this.topAuthor,
    this.longestStreak = 0,
  });

  final int year;
  final int booksFinished;
  final int pagesRead;
  final String? topGenre;
  final String? topAuthor;
  final int longestStreak;

  @override
  State<YearWrappedSharePage> createState() => _YearWrappedSharePageState();
}

class _YearWrappedSharePageState extends State<YearWrappedSharePage> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await shareWidgetAsImage(
        boundaryKey: _cardKey,
        fileName: 'okuma-karnesi-${widget.year}',
        subject: '${widget.year} Okuma Karnem',
        text: _caption(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Görsel oluşturulamadı.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _caption() {
    final parts = <String>[
      '${widget.year} yılında ${widget.booksFinished} kitap bitirdim.',
    ];
    if (widget.longestStreak > 1) {
      parts.add('En uzun okuma serim ${widget.longestStreak} gün.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Karneyi paylaş')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Gap.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Kart hikâye oranında; ekrana sığacak genişlik seç.
                      final available = constraints.maxWidth;
                      final byHeight =
                          MediaQuery.sizeOf(context).height * .58 * 9 / 16;
                      final cardWidth = available < byHeight
                          ? available
                          : byHeight;
                      return RepaintBoundary(
                        key: _cardKey,
                        child: YearWrappedShareCard(
                          year: widget.year,
                          booksFinished: widget.booksFinished,
                          pagesRead: widget.pagesRead,
                          topGenre: widget.topGenre,
                          topAuthor: widget.topAuthor,
                          longestStreak: widget.longestStreak,
                          displayName: profileService.displayName.isEmpty
                              ? null
                              : profileService.displayName,
                          width: cardWidth,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Column(
                children: [
                  Text(
                    'Hikâye boyutunda hazırlandı; kırpılmadan paylaşılır.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  Gap.vMd,
                  SizedBox(
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
                      label: Text(_busy ? 'Hazırlanıyor' : 'Paylaş'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      ),
                    ),
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
