import 'package:flutter/material.dart';

import '../models/catalog_book.dart';
import '../models/recommendation.dart';
import '../services/plus_manager.dart';
import '../services/recommendation_service.dart';
import '../utils/web_search.dart';
import '../widgets/add_book_modal.dart';
import '../widgets/book_cover.dart';
import 'plus_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/mascot.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  final _service = RecommendationService();
  List<Recommendation> _recs = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _filter; // seçili "reason" filtresi

  @override
  void initState() {
    super.initState();
    if (hasPlusAccess) _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) setState(() => _refreshing = true);
    try {
      final recs = await _service.fetch(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _recs = recs;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _add(Recommendation r) async {
    final created = await showAddBookModal(
      context,
      initial: CatalogBook(
        isbn: '',
        title: r.title,
        totalPages: r.totalPages,
        source: 'recommendation',
        author: r.author,
        coverUrl: r.coverUrl,
      ),
    );
    if (created != null && mounted) {
      setState(() => _recs = _recs.where((x) => x != r).toList());
    }
  }

  List<String> get _reasons {
    final set = <String>{};
    for (final r in _recs) {
      if (r.reason.isNotEmpty) set.add(r.reason);
    }
    return set.toList();
  }

  List<Recommendation> get _filtered =>
      _filter == null ? _recs : _recs.where((r) => r.reason == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: plusManager,
      builder: (context, _) {
        final isPlus = hasPlusAccess;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sana Özel Öneriler '),
            actions: [
              if (isPlus)
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _refreshing ? null : () => _load(refresh: true),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          body: isPlus ? _plusBody(cs) : _lockedBody(cs),
        );
      },
    );
  }

  // ----------------- Plus üyeye içerik -----------------
  Widget _plusBody(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.zero,
          child: const EmptyState(
            title: 'Zevkini henüz tanımıyorum',
            message:
                'Birkaç kitap bitir ve puanla; sevdiğin yazar ve türlerden '
                'öneriler burada belirir.',
            mood: MascotMood.reading,
          ),
        ),
      );
    }

    final reasons = _reasons;
    final filtered = _filtered;

    return Column(
      children: [
        // Filtreler
        if (reasons.length > 1)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _filterChip(cs, label: 'Tümü', value: null),
                for (final reason in reasons)
                  _filterChip(cs, label: _shortReason(reason), value: reason),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            // Son satır sistem gezinme çubuğunun altında kalmasın.
            padding: EdgeInsets.fromLTRB(
              14,
              8,
              14,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .60,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _GridRecCard(
              rec: filtered[i],
              onAdd: () => _add(filtered[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(ColorScheme cs, {required String label, String? value}) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
        selectedColor: cs.primaryContainer,
      ),
    );
  }

  String _shortReason(String reason) {
    // "Stefan Zweig okuduğun için" -> "Stefan Zweig"
    return reason
        .replaceAll(' okuduğun için', '')
        .replaceAll(' sevdiğin için', '');
  }

  // ----------------- Plus değilse kilit -----------------
  Widget _lockedBody(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD166), Color(0xFFF7A072)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sana özel öneriler Plus’ta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Okuduğun ve sevdiğin kitaplara göre, sana özel kürelenmiş kitap önerileri.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => const PlusScreen(),
                  ),
                ),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Plus’a geç'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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

class _GridRecCard extends StatelessWidget {
  const _GridRecCard({required this.rec, required this.onAdd});
  final Recommendation rec;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDark ? cs.surfaceContainer : const Color(0xFFEFFAF4),
                child: CachedCover(url: rec.coverUrl, iconSize: 34),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    (rec.author ?? '').isEmpty ? ' ' : rec.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.recommend_rounded, size: 12, color: cs.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Çünkü ${rec.reason}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      InkResponse(
                        radius: 18,
                        onTap: () => searchBookOnline(
                          context,
                          rec.title,
                          author: rec.author,
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: cs.onSurfaceVariant,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.add_circle_rounded, color: cs.primary, size: 22),
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
