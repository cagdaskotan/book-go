import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../models/journal.dart';

/// Anı-defteri sayfalarının yerel deposu.
///
/// Sayfa verisi (OCR metni ve fosforlu işaretler) veritabanında `journal_pages`
/// tablosunda, sayfa görselleri ise uygulamanın belge klasöründeki `journal/`
/// dizininde durur. Böylece yedek alırken metinler JSON'a, görseller arşivin
/// içine girer.
class JournalStore extends ChangeNotifier {
  JournalStore._();
  static final JournalStore instance = JournalStore._();

  List<JournalPage> _pages = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<JournalPage> get pages => _pages;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  /// Veritabanından yeniden okur (yedek geri yüklendikten sonra da kullanılır).
  Future<void> reload() async {
    final db = await AppDatabase.instance.db;
    final rows = await db.query('journal_pages', orderBy: 'created_at DESC');
    _pages = rows.map(_fromRow).toList();
    _loaded = true;
    notifyListeners();
  }

  List<JournalPage> pagesForBook(int bookId) =>
      _pages.where((p) => p.bookId == bookId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<JournalPage> get allPagesNewestFirst =>
      [..._pages]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  JournalPage? pageById(String id) {
    for (final p in _pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Kaynak görseli kalıcı klasöre kopyalar ve OCR metniyle yeni sayfa oluşturur.
  Future<JournalPage> addPage(
    int bookId,
    String sourcePath,
    String text,
  ) async {
    await ensureLoaded();
    final dir = await journalDirectory();
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final dest = '${dir.path}/$id.$ext';
    await File(sourcePath).copy(dest);

    final page = JournalPage(
      id: id,
      bookId: bookId,
      imagePath: dest,
      text: text,
      createdAt: int.parse(id),
    );

    final db = await AppDatabase.instance.db;
    await db.insert('journal_pages', _toRow(page));
    _pages.add(page);
    notifyListeners();
    return page;
  }

  /// Sayfadaki değişiklikleri (işaret ekleme/taşıma/silme) kaydeder.
  Future<void> savePage(JournalPage page) async {
    final db = await AppDatabase.instance.db;
    await db.update(
      'journal_pages',
      _toRow(page),
      where: 'id = ?',
      whereArgs: [page.id],
    );
    notifyListeners();
  }

  Future<void> deletePage(String id) async {
    final page = pageById(id);
    if (page != null) {
      try {
        final file = File(page.imagePath);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // görsel silinemese de kayıt gitsin
      }
    }
    final db = await AppDatabase.instance.db;
    await db.delete('journal_pages', where: 'id = ?', whereArgs: [id]);
    _pages.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  /// Sayfa görsellerinin tutulduğu klasör (yoksa oluşturur).
  static Future<Directory> journalDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final journalDir = Directory('${dir.path}/journal');
    if (!await journalDir.exists()) {
      await journalDir.create(recursive: true);
    }
    return journalDir;
  }

  static JournalPage _fromRow(Map<String, Object?> row) {
    final rawHighlights = row['highlights'] as String? ?? '[]';
    List<Highlight> highlights;
    try {
      final decoded = jsonDecode(rawHighlights);
      highlights = decoded is List
          ? decoded
                .whereType<Map<String, dynamic>>()
                .map(Highlight.fromJson)
                .toList()
          : <Highlight>[];
    } catch (_) {
      highlights = <Highlight>[];
    }

    return JournalPage(
      id: row['id'] as String,
      bookId: row['book_id'] as int,
      imagePath: row['image_path'] as String? ?? '',
      text: row['text'] as String? ?? '',
      createdAt: row['created_at'] as int? ?? 0,
      highlights: highlights,
    );
  }

  static Map<String, Object?> _toRow(JournalPage page) => {
    'id': page.id,
    'book_id': page.bookId,
    'image_path': page.imagePath,
    'text': page.text,
    'highlights': jsonEncode(page.highlights.map((h) => h.toJson()).toList()),
    'created_at': page.createdAt,
  };
}
