import 'package:flutter/material.dart';

import '../models/catalog_book.dart';
import '../pages/barcode_scanner.dart';
import '../services/api_exception.dart';
import '../services/catalog_service.dart';
import 'add_book_modal.dart';
import 'app_toast.dart';
import 'title_search_sheet.dart';

Future<int?> showBookAddLauncher(BuildContext context) async {
  final action = await showModalBottomSheet<_AddAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddChoiceSheet(),
  );
  if (action == null || !context.mounted) return null;
  if (action == _AddAction.manual) return showAddBookModal(context);

  if (action == _AddAction.search) {
    final found = await showTitleSearch(context);
    if (found == null || !context.mounted) return null;
    return showAddBookModal(context, initial: found);
  }

  final isbn = await Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScannerPage()));
  if (isbn == null || !context.mounted) return null;

  CatalogBook? found;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LookupDialog(),
  );
  try {
    found = await CatalogService().lookupISBN(isbn);
  } on ApiException catch (e) {
    if (!context.mounted) return null;
    Navigator.pop(context);
    AppToast.error(
      context,
      e.message,
      title: 'Kitap bulunamadı',
      action: SnackBarAction(
        label: 'Elle ekle',
        onPressed: () => showAddBookModal(context),
      ),
    );
    return null;
  }
  if (!context.mounted) return null;
  Navigator.pop(context);
  return showAddBookModal(context, initial: found);
}

enum _AddAction { scan, search, manual }

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
  const _LookupDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 18),
          Text('Kitap aranıyor', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
