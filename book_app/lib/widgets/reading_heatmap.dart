import 'package:flutter/material.dart';

/// GitHub tarzı yıllık okuma ısı haritası. [data] = "YYYY-MM-DD" -> sayfa.
class ReadingHeatmap extends StatelessWidget {
  const ReadingHeatmap({super.key, required this.year, required this.data});

  final int year;
  final Map<String, int> data;

  static const _months = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  static const _weekdays = ['Pzt', '', 'Çar', '', 'Cum', '', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final first = DateTime(year, 1, 1);
    // İçinde bulunulan yılda bugüne kadar göster (gelecek boş haftalar değil).
    final last = (year == now.year)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(year, 12, 31);
    final lead = (first.weekday - 1) % 7; // Pazartesi=0
    final totalDays = last.difference(first).inDays + 1;
    final columns = ((lead + totalDays) / 7).ceil();

    const cell = 13.0;
    const gap = 3.0;

    // Aralık dışı → null (çizilmez). Aralık içi veri yoksa → 0 (soluk hücre).
    int? pagesFor(int col, int row) {
      final offset = col * 7 + row - lead;
      if (offset < 0 || offset >= totalDays) return null;
      final date = first.add(Duration(days: offset));
      final key = '${date.year}-${_two(date.month)}-${_two(date.day)}';
      return data[key] ?? 0;
    }

    Color colorFor(int? pages) {
      if (pages == null) return Colors.transparent;
      if (pages <= 0) return cs.outlineVariant.withValues(alpha: .35);
      if (pages < 10) return cs.primary.withValues(alpha: .30);
      if (pages < 30) return cs.primary.withValues(alpha: .55);
      if (pages < 60) return cs.primary.withValues(alpha: .78);
      return cs.primary;
    }

    // Ay etiketleri: her ayın ilk gününün düştüğü sütun
    final monthLabels = <int, String>{};
    for (var m = 1; m <= 12; m++) {
      final d = DateTime(year, m, 1);
      final off = d.difference(first).inDays + lead;
      monthLabels[off ~/ 7] = _months[m - 1];
    }

    final totalPages = data.values.fold<int>(0, (a, b) => a + b);
    final activeDays = data.values.where((v) => v > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$activeDays aktif gün',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '$totalPages sayfa',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ay etiketleri
                Padding(
                  padding: const EdgeInsets.only(left: 30, bottom: 4),
                  child: Row(
                    children: List.generate(columns, (col) {
                      return Container(
                        width: cell + gap,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          monthLabels[col] ?? '',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Haftagünü etiketleri
                    Column(
                      children: List.generate(7, (row) {
                        return Container(
                          width: 30,
                          height: cell + gap,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _weekdays[row],
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }),
                    ),
                    // Hücreler
                    Row(
                      children: List.generate(columns, (col) {
                        return Padding(
                          padding: const EdgeInsets.only(right: gap),
                          child: Column(
                            children: List.generate(7, (row) {
                              final pages = pagesFor(col, row);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: gap),
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  decoration: BoxDecoration(
                                    color: colorFor(pages),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'az',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              for (final a in [.30, .55, .78, 1.0])
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: a),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 3),
              Text(
                'çok',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
