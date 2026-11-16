import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../models/gamification_summary.dart';
import '../widgets/book_cover.dart';
import '../widgets/mascot.dart';
import 'year_wrapped_share_page.dart';

/// Yıl sonu "Okuma Karnem" — Spotify Wrapped tarzı, kaydırmalı özet.
class YearWrappedPage extends StatefulWidget {
  const YearWrappedPage({
    super.key,
    required this.books,
    required this.summary,
    this.year,
  });

  final List<Book> books;
  final GamificationSummary? summary;
  final int? year;

  @override
  State<YearWrappedPage> createState() => _YearWrappedPageState();
}

class _YearWrappedPageState extends State<YearWrappedPage> {
  final _controller = PageController();
  int _index = 0;
  late final _YearStats _stats = _YearStats.from(
    widget.books,
    widget.summary,
    widget.year ?? DateTime.now().year,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _cards.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Karneyi paylaşım önizlemesine götürür.
  ///
  /// Önce düz metin paylaşılıyordu; kimse metin paylaşmıyor. Artık hikâye
  /// boyutunda bir kare üretiliyor — sunucusuz bir uygulamanın tek organik
  /// dağıtım kolu bu.
  Future<void> _share() async {
    final s = _stats;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YearWrappedSharePage(
          year: s.year,
          booksFinished: s.booksFinished,
          pagesRead: s.pagesRead,
          topGenre: s.topGenre,
          topAuthor: s.topAuthor,
          longestStreak: s.longestStreak,
        ),
      ),
    );
  }

  late final List<Widget> _cards = _buildCards();

  List<Widget> _buildCards() {
    final s = _stats;
    if (s.booksFinished == 0) {
      return [
        _WrapCard(
          gradient: const [Color(0xFF28205F), Color(0xFF6750E8)],
          child: _EmptyYear(year: s.year),
        ),
      ];
    }
    return [
      _WrapCard(
        gradient: const [
          Color(0xFF28205F),
          Color(0xFF6750E8),
          Color(0xFFA063ED),
        ],
        child: _IntroCard(year: s.year),
      ),
      _WrapCard(
        gradient: const [Color(0xFF3A2C8C), Color(0xFF7A5BE6)],
        child: _BigStatCard(
          emoji: '📚',
          number: '${s.booksFinished}',
          label: 'kitap bitirdin',
          sub: 'Bu yıl ${s.booksFinished} hikâyeyi tamamladın.',
        ),
      ),
      _WrapCard(
        gradient: const [Color(0xFF154E47), Color(0xFF2BAE8A)],
        child: _BigStatCard(
          emoji: '📖',
          number: _fmt(s.pagesRead),
          label: 'sayfa okudun',
          sub: _pagesFun(s.pagesRead),
        ),
      ),
      if (s.topGenre != null)
        _WrapCard(
          gradient: const [Color(0xFF7A3E8C), Color(0xFFC264C0)],
          child: _LabelCard(
            emoji: '🏷️',
            title: 'En sevdiğin tür',
            value: s.topGenre!,
            sub: '${s.topGenreCount} kitabın bu türdendi.',
          ),
        ),
      if (s.topAuthor != null)
        _WrapCard(
          gradient: const [Color(0xFF8C5A2B), Color(0xFFF0A05B)],
          child: _LabelCard(
            emoji: '✍️',
            title: 'En çok okuduğun yazar',
            value: s.topAuthor!,
            sub: s.topAuthorCount > 1
                ? '${s.topAuthorCount} kitabıyla yılına eşlik etti.'
                : 'Bu yıl tanıştığın kalemlerden.',
          ),
        ),
      if (s.highestRated != null)
        _WrapCard(
          gradient: const [Color(0xFF8C2B4B), Color(0xFFF0617B)],
          child: _BookCard(title: 'Yılın favorisi', book: s.highestRated!),
        ),
      _WrapCard(
        gradient: const [
          Color(0xFF1C1646),
          Color(0xFF4B3CB1),
          Color(0xFF9B63E6),
        ],
        child: _FinaleCard(stats: s, onShare: _share),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B1A),
        body: Stack(
          children: [
            // Sayfalar + dokunma alanları
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final w = MediaQuery.sizeOf(context).width;
                if (d.localPosition.dx < w * .32) {
                  _prev();
                } else {
                  _next();
                }
              },
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: _cards,
              ),
            ),

            // Üst hikâye çubukları
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: List.generate(_cards.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Kapat
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, right: 4),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
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

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _pagesFun(int pages) {
    // ~1.8 dk/sayfa kabaca → saat
    final hours = (pages * 1.8 / 60).round();
    if (hours <= 0) return 'Her sayfa küçük bir yolculuktu.';
    return 'Yaklaşık $hours saatini hikâyelere ayırdın.';
  }
}

// ----------------------- İstatistik hesabı -----------------------
class _YearStats {
  _YearStats({
    required this.year,
    required this.booksFinished,
    required this.pagesRead,
    required this.topGenre,
    required this.topGenreCount,
    required this.topAuthor,
    required this.topAuthorCount,
    required this.highestRated,
    required this.longestStreak,
    required this.level,
  });

  final int year;
  final int booksFinished;
  final int pagesRead;
  final String? topGenre;
  final int topGenreCount;
  final String? topAuthor;
  final int topAuthorCount;
  final Book? highestRated;
  final int longestStreak;
  final int level;

  factory _YearStats.from(
    List<Book> books,
    GamificationSummary? summary,
    int year,
  ) {
    bool finishedThisYear(Book b) {
      if (!b.isFinished) return false;
      final f = (b.finishedAt ?? '').trim();
      if (f.isNotEmpty) {
        final y = int.tryParse(f.split('-').first);
        if (y != null) return y == year;
      }
      return b.createdAt.year == year;
    }

    final finished = books.where(finishedThisYear).toList();
    final pages = finished.fold<int>(0, (a, b) => a + b.totalPages);

    final genreCounts = <String, int>{};
    final authorCounts = <String, int>{};
    Book? topRated;
    for (final b in finished) {
      final g = (b.category ?? '').trim();
      if (g.isNotEmpty) genreCounts[g] = (genreCounts[g] ?? 0) + 1;
      final a = (b.author ?? '').trim();
      if (a.isNotEmpty) authorCounts[a] = (authorCounts[a] ?? 0) + 1;
      if (b.rating != null) {
        if (topRated == null || (b.rating ?? 0) > (topRated.rating ?? 0)) {
          topRated = b;
        }
      }
    }

    MapEntry<String, int>? topOf(Map<String, int> m) {
      if (m.isEmpty) return null;
      final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return e.first;
    }

    final tg = topOf(genreCounts);
    final ta = topOf(authorCounts);

    return _YearStats(
      year: year,
      booksFinished: finished.length,
      pagesRead: pages,
      topGenre: tg?.key,
      topGenreCount: tg?.value ?? 0,
      topAuthor: ta?.key,
      topAuthorCount: ta?.value ?? 0,
      highestRated: topRated,
      longestStreak: summary?.longestStreak ?? 0,
      level: summary?.level ?? 1,
    );
  }
}

// ----------------------- Kart kabuğu -----------------------
class _WrapCard extends StatelessWidget {
  const _WrapCard({required this.gradient, required this.child});
  final List<Color> gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
          child: child,
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const Mascot(mood: MascotMood.celebrate, size: 120),
        const SizedBox(height: 24),
        Text(
          '$year',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Okuma Karnen',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bu yıl neler yaptığına birlikte bakalım. Devam etmek için dokun →',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .8),
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.emoji,
    required this.number,
    required this.label,
    required this.sub,
  });
  final String emoji;
  final String number;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 76,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .8),
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({
    required this.emoji,
    required this.title,
    required this.value,
    required this.sub,
  });
  final String emoji;
  final String title;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text(emoji, style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 18),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: .7),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .8),
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.title, required this.book});
  final String title;
  final Book book;

  @override
  Widget build(BuildContext context) {
    final stars = ((book.rating ?? 0) / 20).round().clamp(0, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: .7),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 150,
              height: 214,
              color: Colors.white.withValues(alpha: .12),
              child: CachedCover(
                url: book.coverUrl,
                iconColor: Colors.white54,
                iconSize: 50,
                title: book.title,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if ((book.author ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            book.author!.trim(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFFFC65B),
                size: 24,
              ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _FinaleCard extends StatelessWidget {
  const _FinaleCard({required this.stats, required this.onShare});
  final _YearStats stats;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Mascot(mood: MascotMood.happy, size: 80),
        const SizedBox(height: 14),
        Text(
          '${stats.year} özetin',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        row(Icons.menu_book_rounded, '${stats.booksFinished} kitap bitirdin'),
        row(
          Icons.auto_stories_rounded,
          '${_YearWrappedPageState._fmt(stats.pagesRead)} sayfa okudun',
        ),
        if (stats.topGenre != null)
          row(Icons.label_rounded, 'En sevdiğin tür: ${stats.topGenre}'),
        if (stats.topAuthor != null)
          row(Icons.edit_rounded, 'Favori yazarın: ${stats.topAuthor}'),
        if (stats.longestStreak > 0)
          row(
            Icons.local_fire_department_rounded,
            'En uzun serin: ${stats.longestStreak} gün',
          ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Karnemi paylaş'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4B3CB1),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyYear extends StatelessWidget {
  const _EmptyYear({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Mascot(mood: MascotMood.encourage, size: 120),
        const SizedBox(height: 22),
        Text(
          '$year karnen',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Bu yıl henüz bitirdiğin bir kitap yok. İlk kitabını bitir, '
          'karnen rengârenk dolsun!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .85),
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
