import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/quote.dart';
import 'api_exception.dart';

/// Alıntı defteri için cihaz-içi depo.
class QuoteService {
  QuoteService();

  Future<Database> get _db => AppDatabase.instance.db;

  /// [bookId] verilirse o kitabın, verilmezse tüm alıntılar (yeniden eskiye).
  Future<List<Quote>> fetchQuotes({int? bookId}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT q.id, q.book_id, q.page, q.text, q.favorite, q.created_at, '
      '       b.title AS book_title, b.author AS book_author, b.cover_url '
      'FROM quotes q '
      'JOIN books b ON b.id = q.book_id '
      '${bookId != null ? 'WHERE q.book_id = ? ' : ''}'
      'ORDER BY q.id DESC',
      bookId != null ? [bookId] : null,
    );

    return rows
        .map(
          (row) => Quote(
            id: row['id'] as int,
            bookId: row['book_id'] as int,
            text: (row['text'] as String? ?? '').trim(),
            page: row['page'] as int?,
            favorite: (row['favorite'] as int? ?? 0) == 1,
            createdAt: row['created_at'] as String?,
            bookTitle: row['book_title'] as String?,
            bookAuthor: row['book_author'] as String?,
            coverUrl: row['cover_url'] as String?,
          ),
        )
        .toList();
  }

  Future<void> createQuote({
    required int bookId,
    required String text,
    int? page,
    bool favorite = false,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const ApiException(400, 'Alıntı metni boş olamaz.');
    }

    final db = await _db;
    final book = await db.query(
      'books',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (book.isEmpty) throw const ApiException(404, 'Kitap bulunamadı.');

    await db.insert('quotes', {
      'book_id': bookId,
      'page': (page != null && page > 0) ? page : null,
      'text': cleanText,
      'favorite': favorite ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteQuote(int id) async {
    final db = await _db;
    final affected = await db.delete(
      'quotes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (affected == 0) throw const ApiException(404, 'Alıntı bulunamadı.');
  }

  /// Alıntının favori durumunu değiştirir.
  Future<void> setFavorite(int id, bool favorite) async {
    final db = await _db;
    await db.update(
      'quotes',
      {'favorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

/// Günün alıntısını seçer.
///
/// Ana sayfadaki kart kullanıcının kendi defterinden besleniyor; hazır ünlü
/// söz yerine insanın kendi altını çizdiği cümleyi görmesi çok daha
/// kıymetli. Seçim **gün bazında sabit**: aynı gün içinde ekran her
/// yenilendiğinde alıntı değişirse kart huzursuz oluyor, okunmadan kayıyor.
///
/// Başucuna alınmış alıntılar varsa yalnızca onların arasından seçiyor —
/// kullanıcı "bunlar benim için özel" demiş, günün cümlesi oradan gelsin.
Quote? pickDailyQuote(List<Quote> quotes, DateTime day) {
  if (quotes.isEmpty) return null;
  final favorites = quotes.where((q) => q.favorite).toList();
  final pool = favorites.isNotEmpty ? favorites : quotes;
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return pool[dayOfYear % pool.length];
}
