import 'package:flutter/material.dart';
import 'book_cover.dart';
import '../models/reading_status.dart';
import 'star_rating.dart';

/// Kitap ekleme/düzenleme sayfalarının paylaştığı tasarım yapı taşları.
/// Tek bir görsel dil: başlık, bölüm kartı, kapak önizleme, tarih alanı, footer.

// ----------------------------- Header -----------------------------
class BookFormHeader extends StatelessWidget {
  const BookFormHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.6,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------- Section -----------------------------
class BookFormSection extends StatefulWidget {
  const BookFormSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.collapsible = false,
    this.initiallyOpen = true,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool collapsible;
  final bool initiallyOpen;

  @override
  State<BookFormSection> createState() => _BookFormSectionState();
}

class _BookFormSectionState extends State<BookFormSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.collapsible
                ? () => setState(() => _open = !_open)
                : null,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 17, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (widget.collapsible)
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 14),
            ...widget.children,
          ],
        ],
      ),
    );
  }
}

// ----------------------------- Cover preview -----------------------------
class BookCoverPreview extends StatelessWidget {
  const BookCoverPreview({
    super.key,
    required this.url,
    required this.title,
    this.author,
  });

  final String url;
  final String title;
  final String? author;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    final displayTitle = title.trim().isEmpty ? 'Kitap adı' : title.trim();
    final displayAuthor = (author ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF28205F), Color(0xFF6750E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6750E8).withValues(alpha: .22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 62,
              height: 88,
              color: Colors.white.withValues(alpha: .12),
              child: CachedCover(
                url: url,
                iconColor: Colors.white70,
                iconSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: title.trim().isEmpty
                        ? Colors.white.withValues(alpha: .5)
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayAuthor.isEmpty ? 'Yazar' : displayAuthor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: displayAuthor.isEmpty ? .4 : .75,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      hasUrl
                          ? Icons.image_rounded
                          : Icons.image_not_supported_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: .6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasUrl ? 'Kapak önizleme' : 'Kapak eklenmedi',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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
}

// ----------------------------- Date field -----------------------------
/// Depolama YYYY-MM-DD; ekranda gün.ay.yıl gösterir.
class BookDateField extends StatelessWidget {
  const BookDateField({
    super.key,
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Future<void> pick() async {
      final now = DateTime.now();
      final initial = _parse(controller.text) ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1970),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) controller.text = _format(picked);
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final display = _toDisplay(value.text);
        return InkWell(
          onTap: enabled ? pick : null,
          borderRadius: BorderRadius.circular(18),
          child: InputDecorator(
            isEmpty: display.isEmpty,
            decoration: InputDecoration(
              labelText: label,
              enabled: enabled,
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              hintText: 'gg.aa.yyyy',
            ),
            child: Text(
              display,
              style: TextStyle(
                color: enabled ? cs.onSurface : cs.onSurface.withValues(alpha: .4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  static String _toDisplay(String storage) {
    final d = _parse(storage);
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  static String _format(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static DateTime? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final parts = t.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}

// ----------------------------- Error banner -----------------------------
class BookFormError extends StatelessWidget {
  const BookFormError({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------- Status selector -----------------------------
/// Okuma durumu seçici (3 segment). 'paused' da desteklenir.
/// Okuma durumu seçici.
///
/// Beş durum (listemde / okuyorum / ara verdim / bıraktım / bitti) bir
/// SegmentedButton'a sığmıyordu: dar ekranda etiketler eziliyordu. Sarmalayan
/// çipler hem taşmıyor hem de seçili olanı daha net gösteriyor.
class BookStatusSelector extends StatelessWidget {
  const BookStatusSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.includePaused = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  /// "Ara verdim" ve "Bıraktım" yalnızca düzenlemede anlamlı; yeni kitap
  /// eklerken kullanıcı bunları seçmiyor.
  final bool includePaused;

  @override
  Widget build(BuildContext context) {
    final selected = ReadingStatus.parse(value);
    final options = ReadingStatus.values
        .where((s) => includePaused || !s.isDormant)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in options)
          ChoiceChip(
            label: Text(status.label),
            avatar: Icon(
              status.icon,
              size: 16,
              color: status == selected
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selected: status == selected,
            showCheckmark: false,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
            onSelected: onChanged == null
                ? null
                : (_) => onChanged!(status.value),
          ),
      ],
    );
  }
}

// ----------------------------- Rating picker -----------------------------
/// 5 yıldızlı puan seçici (her yıldız = 20 puan). 0..100 arası int döner.
/// Puanlama alanı — yarım yıldızlı [StarRatingInput]'a devrediyor.
class BookRatingPicker extends StatelessWidget {
  const BookRatingPicker({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final int? rating;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Puanın',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: cs.onSurfaceVariant,
          ),
        ),
        StarRatingInput(
          rating: rating,
          onChanged: onChanged,
          enabled: enabled,
        ),
      ],
    );
  }
}

// ----------------------------- Footer -----------------------------
class BookFormFooter extends StatelessWidget {
  const BookFormFooter({
    super.key,
    required this.busy,
    required this.label,
    required this.icon,
    required this.onSubmit,
  });

  final bool busy;
  final String label;
  final IconData icon;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon),
            label: Text(busy ? 'Kaydediliyor…' : label),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}
