import 'package:flutter/material.dart';

import '../models/catalog_book.dart';
import '../pages/barcode_scanner.dart';
import '../pages/routes.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/catalog_service.dart';
import 'add_book_modal.dart';
import 'app_toast.dart';
import 'title_search_sheet.dart';
import '../services/cover_scan_service.dart';
import '../services/cover_photo_service.dart';

Future<int?> showBookAddLauncher(BuildContext context) async {
  final action = await showModalBottomSheet<_AddAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddChoiceSheet(),
  );
  if (action == null || !context.mounted) return null;
  if (action == _AddAction.manual) return showAddBookModal(context);

  if (action == _AddAction.cover) return _addFromCover(context);

  if (action == _AddAction.search) {
    final found = await showTitleSearch(context);
    if (found == null || !context.mounted) return null;
    return showAddBookModal(context, initial: found);
  }

  final isbn = await Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
  if (isbn == null || !context.mounted) return null;

  // Aynı kitabı ikinci kez okutmak sık oluyor; raf kalabalıklaşmasın.
  final existing = await BookService().findByIsbn(isbn);
  if (existing != null) {
    if (!context.mounted) return null;
    AppToast.info(
      context,
      '"${existing.title}" zaten kitaplığında.',
      title: 'Bu kitap var',
      action: SnackBarAction(
        label: 'Aç',
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.diary,
          arguments: existing.id,
        ),
      ),
    );
    return null;
  }
  if (!context.mounted) return null;

  CatalogBook? found;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LookupDialog(),
  );
  try {
    found = await CatalogService().lookupISBN(isbn);
  } on ApiException {
    // Künye bulunamadı — ama barkod elimizde. Kullanıcıyı boş bir forma
    // göndermek yerine ISBN'i taşıyıp devam ettiriyoruz; Türkçe baskıların
    // çoğu bu servislerde olmadığı için burası istisna değil, sık yol.
    found = null;
  }
  if (!context.mounted) return null;
  Navigator.pop(context);
  return showAddBookModal(context, initial: found, isbn: isbn);
}

/// Kapak fotoğrafından kitap ekleme.
///
/// Barkodu kataloglarda bulunmayan Türkçe baskılar için ikinci yol. Akış
/// şöyle: fotoğraf çek → kapaktaki yazıyı oku → künyeyi katalogda ara.
/// Bulunursa kullanıcı seçer; bulunmazsa form okunan başlık ve yazarla
/// dolu açılır. Her iki durumda da çekilen fotoğraf kapak olarak hazır —
/// kullanıcı tek karede hem veriyi hem görseli vermiş olur.
Future<int?> _addFromCover(BuildContext context) async {
  final imagePath = await CoverPhotoService.capture();
  if (imagePath == null || !context.mounted) return null;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LookupDialog(message: 'Kapak okunuyor'),
  );

  CoverScanResult scan;
  try {
    scan = await CoverScanService.scanImage(imagePath);
  } catch (_) {
    scan = CoverScanResult(
      title: null,
      author: null,
      lines: const [],
      imagePath: imagePath,
    );
  }
  if (!context.mounted) return null;
  Navigator.pop(context);

  // Okunan künyeyi ve fotoğrafı forma taşıyan yedek plan.
  CatalogBook fallback() => CatalogBook(
    isbn: '',
    title: scan.title ?? '',
    totalPages: 0,
    source: 'cover_scan',
    author: scan.author,
    coverUrl: imagePath,
  );

  if (scan.query.isEmpty) {
    AppToast.info(
      context,
      'Kapaktaki yazı okunamadı. Bilgileri sen girebilirsin.',
      title: 'Künye çıkmadı',
    );
    return showAddBookModal(context, initial: fallback());
  }

  final picked = await showTitleSearch(context, initialQuery: scan.query);
  if (!context.mounted) return null;

  if (picked == null) {
    // Kullanıcı listeden seçmedi: okunan künyeyle forma geç, boşa çıkmasın.
    return showAddBookModal(context, initial: fallback());
  }

  // Katalogda kapak yoksa çektiğimiz fotoğrafı kullan — raf kapaksız
  // kitaplarla dolmasın.
  final chosen = (picked.coverUrl ?? '').trim().isEmpty
      ? CatalogBook(
          isbn: picked.isbn,
          title: picked.title,
          totalPages: picked.totalPages,
          source: picked.source,
          author: picked.author,
          coverUrl: imagePath,
          category: picked.category,
          publisher: picked.publisher,
        )
      : picked;

  return showAddBookModal(context, initial: chosen);
}

enum _AddAction { scan, cover, search, manual }

class _AddChoiceSheet extends StatelessWidget {
  const _AddChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Kitap ekle',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.6,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Kitabını nasıl eklemek istersin?',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _AddOptionRow(
                icon: Icons.search_rounded,
                title: 'Ada göre ara',
                subtitle: 'Kapak, yazar ve sayfa otomatik dolsun',
                colors: const [Color(0xFF6750E8), Color(0xFF9B6AF4)],
                onTap: () => Navigator.pop(context, _AddAction.search),
              ),
              const SizedBox(height: 10),
              _AddOptionRow(
                icon: Icons.document_scanner_rounded,
                title: 'Barkodu tara',
                subtitle: 'Arka kapaktaki ISBN barkodunu okut',
                colors: const [Color(0xFF2BAE8A), Color(0xFF34D399)],
                onTap: () => Navigator.pop(context, _AddAction.scan),
              ),
              const SizedBox(height: 10),
              _AddOptionRow(
                icon: Icons.photo_camera_rounded,
                title: 'Kapağı okut',
                subtitle: 'Barkodu yoksa kapağın fotoğrafını çek',
                colors: const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                onTap: () => Navigator.pop(context, _AddAction.cover),
              ),
              const SizedBox(height: 10),
              _AddOptionRow(
                icon: Icons.edit_note_rounded,
                title: 'Elle ekle',
                subtitle: 'Tüm bilgileri kendin gir',
                colors: const [Color(0xFFFFA55B), Color(0xFFF06473)],
                onTap: () => Navigator.pop(context, _AddAction.manual),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOptionRow extends StatelessWidget {
  const _AddOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: .26),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LookupDialog extends StatelessWidget {
  const _LookupDialog({this.message = 'Kitap aranıyor'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
