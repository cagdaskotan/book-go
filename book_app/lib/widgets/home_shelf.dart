import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_scale.dart';
import 'book_spine.dart';
import 'mascot.dart';

/// Ana ekranın üstündeki raf şeridi.
///
/// Bu uygulamanın tek gerçek görsel farkı raf: rakiplerin hepsi kitapları
/// ızgara listesinde gösteriyor. O fark üçüncü sekmede saklı duruyordu;
/// burası onu ürünün yüzü yapıyor — uygulamayı açan ilk gördüğü şey kendi
/// kitaplığı oluyor.
///
/// Tam dolap (dekoratif korniş, ayaklar, etiketler) raf ekranında kalıyor;
/// burada tek bir ahşap raf tahtası ve üstündeki kitaplar var.
class HomeShelf extends StatelessWidget {
  const HomeShelf({
    super.key,
    required this.books,
    required this.onOpenBook,
    this.onSeeAll,
    this.maxBooks = 14,
  });

  final List<Book> books;
  final void Function(int bookId) onOpenBook;
  final VoidCallback? onSeeAll;

  /// Şeritte en çok kaç kitap gösterilsin. Raf ekranı tamamını gösteriyor;
  /// burada amaç özet ve hız.
  final int maxBooks;

  static const Color _shelfWood = Color(0xFF4A3426);
  static const Color _shelfWoodLight = Color(0xFF6B4B35);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = books.take(maxBooks).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.sm, Gap.sm),
          child: Row(
            children: [
              Icon(Icons.shelves, size: 18, color: cs.primary),
              const SizedBox(width: Gap.sm),
              Text(
                'Rafın',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (books.isNotEmpty)
                Text(
                  '${books.length} kitap',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              const Spacer(),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Tümü'),
                ),
            ],
          ),
        ),
        if (shown.isEmpty)
          _EmptyShelf(onOpenBook: onSeeAll)
        else
          _ShelfBoard(books: shown, onOpenBook: onOpenBook),
      ],
    );
  }
}

/// Kitapların üstünde durduğu ahşap tahta ve yatay kaydırma.
class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard({required this.books, required this.onOpenBook});

  final List<Book> books;
  final void Function(int bookId) onOpenBook;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Stack(
        children: [
          // Kitaplar tahtanın üstünde durur: alt kenarları hizalı.
          Positioned.fill(
            bottom: 14,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 3),
              itemBuilder: (context, i) {
                final book = books[i];
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: BookSpine(
                    book: book,
                    base: spineBaseColor(book, HomeShelf._shelfWoodLight),
                    index: i,
                    tag: 'home-shelf-${book.id}',
                    onTap: () => onOpenBook(book.id),
                    onLongPress: () => onOpenBook(book.id),
                  ),
                );
              },
            ),
          ),
          // Raf tahtası
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 14,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [HomeShelf._shelfWoodLight, HomeShelf._shelfWood],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raf boşken: ızgara yerine çizilmiş boş bir raf ve davet.
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({this.onOpenBook});

  final VoidCallback? onOpenBook;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: .4),
          borderRadius: Radii.brLg,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 12,
                decoration: const BoxDecoration(
                  color: HomeShelf._shelfWood,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(Radii.lg),
                  ),
                ),
              ),
            ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Mascot(mood: MascotMood.encourage, size: 74),
                  const SizedBox(width: Gap.md),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Raf boş duruyor',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'İlk kitabını koy, sırtı burada belirsin.',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
