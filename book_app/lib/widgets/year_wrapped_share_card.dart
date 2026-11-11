import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import 'mascot.dart';

/// Yıl karnesinin paylaşılabilir karesi.
///
/// Hikâye oranında (9:16) tasarlandı: kullanıcı bunu Instagram hikâyesine
/// koyduğunda kırpılmıyor. Alt köşedeki imza kasıtlı — sunucusuz bir
/// uygulamanın tek organik dağıtım kolu bu kare.
///
/// Yılda bir kez, herkes aynı hafta paylaşır; yılın en büyük erişim fırsatı.
class YearWrappedShareCard extends StatelessWidget {
  const YearWrappedShareCard({
    super.key,
    required this.year,
    required this.booksFinished,
    required this.pagesRead,
    this.topGenre,
    this.topAuthor,
    this.longestStreak = 0,
    this.displayName,
    this.width = 360,
  });

  final int year;
  final int booksFinished;
  final int pagesRead;
  final String? topGenre;
  final String? topAuthor;
  final int longestStreak;
  final String? displayName;

  /// Kartın mantıksal genişliği; yükseklik 9:16 oranından türer.
  final double width;

  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final height = width * 16 / 9;
    final name = displayName?.trim();

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: Radii.brXl,
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1446), Color(0xFF4B3CB1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Arka plandaki yumuşak ışık lekeleri — düz gradyanı kırıyor.
          Positioned(
            top: -height * .08,
            right: -width * .25,
            child: _glow(width * .8, const Color(0xFFB794FF)),
          ),
          Positioned(
            bottom: -height * .05,
            left: -width * .3,
            child: _glow(width * .75, const Color(0xFF6750E8)),
          ),
          Padding(
            padding: EdgeInsets.all(width * .075),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Mascot(
                      mood: MascotMood.celebrate,
                      size: width * .17,
                      animate: false,
                    ),
                    SizedBox(width: width * .03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$year',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: width * .13,
                              height: 1,
                              letterSpacing: -1.5,
                            ),
                          ),
                          Text(
                            'OKUMA KARNESİ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontWeight: FontWeight.w900,
                              fontSize: width * .034,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Yılın iki büyük sayısı.
                _bigNumber(
                  value: '$booksFinished',
                  unit: booksFinished == 1 ? 'kitap' : 'kitap',
                  caption: 'bitirdim',
                  width: width,
                ),
                SizedBox(height: width * .055),
                _bigNumber(
                  value: _thousands(pagesRead),
                  unit: 'sayfa',
                  caption: 'okudum',
                  width: width,
                ),

                const Spacer(),

                // Ayrıntılar: yalnızca verisi olanlar görünür.
                if (topGenre != null)
                  _detail('En sevdiğim tür', topGenre!, width),
                if (topAuthor != null)
                  _detail('En çok okuduğum yazar', topAuthor!, width),
                if (longestStreak > 0)
                  _detail('En uzun serim', '$longestStreak gün', width),

                SizedBox(height: width * .06),
                Divider(color: Colors.white.withValues(alpha: .18), height: 1),
                SizedBox(height: width * .04),
                Row(
                  children: [
                    if (name != null && name.isNotEmpty) ...[
                      Text(
                        name,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .85),
                          fontWeight: FontWeight.w800,
                          fontSize: width * .038,
                        ),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white.withValues(alpha: .6),
                      size: width * .045,
                    ),
                    SizedBox(width: width * .018),
                    Text(
                      'Bilge · Mobil Kütüphanem',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
                        fontWeight: FontWeight.w800,
                        fontSize: width * .035,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigNumber({
    required String value,
    required String unit,
    required String caption,
    required double width,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: width * .2,
                height: .95,
                letterSpacing: -2,
              ),
            ),
            SizedBox(width: width * .025),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .8),
                fontWeight: FontWeight.w800,
                fontSize: width * .055,
              ),
            ),
          ],
        ),
        Text(
          caption,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .58),
            fontWeight: FontWeight.w700,
            fontSize: width * .042,
          ),
        ),
      ],
    );
  }

  Widget _detail(String label, String value, double width) {
    return Padding(
      padding: EdgeInsets.only(bottom: width * .028),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .6),
                fontWeight: FontWeight.w700,
                fontSize: width * .036,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: width * .042,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .38), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
