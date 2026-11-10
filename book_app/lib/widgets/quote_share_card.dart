import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paylaşılabilir alıntı kartının görsel temaları.
enum QuoteCardTheme { paper, night, sunset, forest }

class QuoteCardThemeData {
  const QuoteCardThemeData({
    required this.bg,
    required this.ink,
    required this.soft,
    required this.accent,
  });

  final List<Color> bg; // arka plan degrade
  final Color ink; // ana metin
  final Color soft; // ikincil metin
  final Color accent; // tırnak / vurgu

  static QuoteCardThemeData of(QuoteCardTheme t) {
    switch (t) {
      case QuoteCardTheme.paper:
        return const QuoteCardThemeData(
          bg: [Color(0xFFF6EFDD), Color(0xFFEFE3C8)],
          ink: Color(0xFF3A2E1E),
          soft: Color(0xFF8A7656),
          accent: Color(0xFFC79A4B),
        );
      case QuoteCardTheme.night:
        return const QuoteCardThemeData(
          bg: [Color(0xFF1E1B36), Color(0xFF332A5C)],
          ink: Color(0xFFF3EEFF),
          soft: Color(0xFFB7AEE0),
          accent: Color(0xFFB28BFF),
        );
      case QuoteCardTheme.sunset:
        return const QuoteCardThemeData(
          bg: [Color(0xFF3A1C44), Color(0xFF8E3B6B), Color(0xFFD9714C)],
          ink: Color(0xFFFFF1E6),
          soft: Color(0xFFFFD7C2),
          accent: Color(0xFFFFC56B),
        );
      case QuoteCardTheme.forest:
        return const QuoteCardThemeData(
          bg: [Color(0xFF12281F), Color(0xFF1F4435)],
          ink: Color(0xFFEAF6EE),
          soft: Color(0xFFA9CDB7),
          accent: Color(0xFF7BE3B0),
        );
    }
  }
}

/// Instagram için zarif alıntı kartı (4:5). Ekran dışında çizilip görsele
/// dönüştürülür ya da önizlemede gösterilir.
class QuoteShareCard extends StatelessWidget {
  const QuoteShareCard({
    super.key,
    required this.text,
    required this.bookTitle,
    this.author,
    this.coverUrl,
    this.page,
    this.theme = QuoteCardTheme.paper,
  });

  final String text;
  final String bookTitle;
  final String? author;
  final String? coverUrl;
  final int? page;
  final QuoteCardTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = QuoteCardThemeData.of(theme);
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: t.bg,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Yumuşak köşe parıltısı
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      t.accent.withValues(alpha: .22),
                      t.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 30, 34, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 96,
                      height: .8,
                      fontWeight: FontWeight.w800,
                      color: t.accent.withValues(alpha: .85),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Text(
                            text.trim(),
                            style: GoogleFonts.lora(
                              fontSize: 30,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: t.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: t.soft.withValues(alpha: .35), thickness: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if ((coverUrl ?? '').isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 46,
                            height: 64,
                            child: CachedNetworkImage(
                              imageUrl: coverUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  ColoredBox(color: t.soft.withValues(alpha: .3)),
                            ),
                          ),
                        ),
                      if ((coverUrl ?? '').isNotEmpty) const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bookTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lora(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                                height: 1.15,
                              ),
                            ),
                            if ((author ?? '').trim().isNotEmpty)
                              Text(
                                author!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: t.soft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (page != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'sayfa $page',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.soft.withValues(alpha: .8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 14,
                        color: t.soft.withValues(alpha: .8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bilge · Mobil Kütüphanem',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          color: t.soft.withValues(alpha: .85),
                        ),
                      ),
                    ],
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
