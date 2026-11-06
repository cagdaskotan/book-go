import 'package:sqflite/sqflite.dart';

import '../models/book_collection.dart';
import '../data/app_database.dart';
import 'api_exception.dart';

/// Raflar (koleksiyonlar) için cihaz-içi depo.
class CollectionService {
  CollectionService();

  Future<Database> get _db => AppDatabase.instance.db;

  /// Tüm raflar; her rafın kitapları manuel sıraya (position), sıralanmamışsa
  /// eklenme tarihine göre gelir.
  Future<List<BookCollection>> fetchCollections() async {
    final db = await _db;
    final shelves = await db.query('collections', orderBy: 'id DESC');
    if (shelves.isEmpty) return const [];

    final links = await db.query(
      'collection_books',
      orderBy: 'position ASC, added_at DESC',
    );

    final bookIds = <int, List<int>>{};
    final modes = <int, Map<int, ShelfDisplayMode>>{};
    for (final link in links) {
      final collectionId = link['collection_id'] as int;
      final bookId = link['book_id'] as int;
      bookIds.putIfAbsent(collectionId, () => []).add(bookId);
      modes.putIfAbsent(collectionId, () => {})[bookId] =
          shelfDisplayModeFromString(link['display_mode'] as String?);
    }

    return shelves.map((row) {
      final id = row['id'] as int;
      return BookCollection(
        id: id,
        name: row['name'] as String? ?? '',
        color: row['color'] as String? ?? '#6750E8',
        bookIds: bookIds[id] ?? const [],
        displayModes: modes[id] ?? const {},
      );
    }).toList();
  }

  Future<BookCollection> createCollection(String name, String color) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ApiException(400, 'Raf adı gerekli.');
    }
    final db = await _db;
    final id = await db.insert('collections', {
      'name': cleanName,
      'color': _normalizeColor(color),
      'created_at': DateTime.now().toIso8601String(),
    });
    return BookCollection(
      id: id,
      name: cleanName,
      color: _normalizeColor(color),
      bookIds: const [],
    );
  }

  Future<void> updateCollection(
    int collectionId,
    String name,
    String color,
  ) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const ApiException(400, 'Raf adı gerekli.');
    }
    final db = await _db;
    final affected = await db.update(
      'collections',
      {'name': cleanName, 'color': _normalizeColor(color)},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
    if (affected == 0) throw const ApiException(404, 'Raf bulunamadı.');
  }

  Future<void> deleteCollection(int collectionId) async {
    final db = await _db;
    final affected = await db.delete(
      'collections',
      where: 'id = ?',
      whereArgs: [collectionId],
    );
    if (affected == 0) throw const ApiException(404, 'Raf bulunamadı.');
  }

  Future<void> addBook(int collectionId, int bookId) async {
    final db = await _db;
    await db.insert('collection_books', {
      'collection_id': collectionId,
      'book_id': bookId,
      'display_mode': 'spine',
      'position': 0,
      'added_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeBook(int collectionId, int bookId) async {
    final db = await _db;
    await db.delete(
      'collection_books',
      where: 'collection_id = ? AND book_id = ?',
      whereArgs: [collectionId, bookId],
    );
  }

  /// Kitabın bu raftaki görünüm biçimini günceller (spine/face/stack).
  Future<void> setDisplayMode(
    int collectionId,
    int bookId,
    ShelfDisplayMode mode,
  ) async {
    final db = await _db;
    await db.update(
      'collection_books',
      {'display_mode': shelfDisplayModeToString(mode)},
      where: 'collection_id = ? AND book_id = ?',
      whereArgs: [collectionId, bookId],
    );
  }

  /// Raftaki kitapların sırasını kaydeder (verilen kimlik sırasına göre).
  Future<void> reorder(int collectionId, List<int> bookIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < bookIds.length; i++) {
        await txn.update(
          'collection_books',
          {'position': i + 1},
          where: 'collection_id = ? AND book_id = ?',
          whereArgs: [collectionId, bookIds[i]],
        );
      }
    });
  }

  static String _normalizeColor(String raw) {
    final value = raw.trim();
    return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value) ? value : '#6750E8';
  }
}
