import 'package:flutter/material.dart';

import '../models/book_collection.dart';
import '../services/api_exception.dart';
import '../services/collection_service.dart';

Future<void> showCollectionPicker(BuildContext context, int bookId) async {
  final service = CollectionService();
  List<BookCollection> collections;
  try {
    collections = await service.fetchCollections();
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;

  final selected = await showModalBottomSheet<BookCollection>(
    context: context,
    // Raf sayısı arttıkça liste uzuyor; sabit yükseklikte kırpılmasın.
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Koleksiyona ekle',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (collections.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Önce Koleksiyonlar sayfasından bir raf oluştur.',
                  ),
                ),
              )
            else
              ...collections.map(
                (collection) => ListTile(
                  onTap: () => Navigator.pop(context, collection),
                  leading: CircleAvatar(
                    backgroundColor: _hex(collection.color),
                    child: const Icon(
                      Icons.collections_bookmark_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    collection.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${collection.bookIds.length} kitap'),
                  trailing: collection.bookIds.contains(bookId)
                      ? const Icon(Icons.check_circle_rounded)
                      : const Icon(Icons.add_rounded),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected == null) return;
  final alreadyAdded = selected.bookIds.contains(bookId);
  try {
    if (alreadyAdded) {
      await service.removeBook(selected.id, bookId);
    } else {
      await service.addBook(selected.id, bookId);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alreadyAdded ? 'Kitap raftan çıkarıldı.' : 'Koleksiyona eklendi.',
        ),
      ),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Color _hex(String value) {
  final raw = value.replaceFirst('#', '');
  return Color(int.parse('FF$raw', radix: 16));
}
