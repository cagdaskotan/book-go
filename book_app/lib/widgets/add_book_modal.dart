import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_book.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import 'app_toast.dart';
import 'book_form.dart';

const _bookCategories = [
  'Roman',
  'Öykü',
  'Şiir',
  'Polisiye',
  'Bilim Kurgu',
  'Fantastik',
  'Tarih',
  'Felsefe',
  'Psikoloji',
  'Bilim',
  'Kişisel Gelişim',
  'Biyografi',
  'Çocuk',
  'Çizgi Roman',
  'Deneme',
  'Diğer',
];

Future<int?> showAddBookModal(BuildContext context, {CatalogBook? initial}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddBookSheet(initial: initial, toastContext: context),
  );
}

class _AddBookSheet extends StatefulWidget {
  const _AddBookSheet({this.initial, required this.toastContext});
  final CatalogBook? initial;
  final BuildContext toastContext;

  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _service = BookService();
  final _form = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _author = TextEditingController();
  final _pages = TextEditingController();
  final _currentPage = TextEditingController();
  final _category = TextEditingController();
  final _cover = TextEditingController();
  final _tags = TextEditingController();
  final _notes = TextEditingController();
  final _started = TextEditingController();
  final _finished = TextEditingController();

  String _status = 'want_to_read';
  String? _selectedCategory;
  bool _customCategory = false;
  int? _rating;
  bool _favorite = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final book = widget.initial;
    if (book != null) {
      _title.text = book.title;
      _author.text = book.author ?? '';
      _pages.text = book.totalPages > 0 ? '${book.totalPages}' : '';
      _category.text = book.category ?? '';
      _cover.text = book.coverUrl ?? '';
      final category = book.category?.trim();
      if (category != null && category.isNotEmpty) {
        if (_bookCategories.contains(category) && category != 'Diğer') {
          _selectedCategory = category;
        } else {
          _selectedCategory = 'Diğer';
          _customCategory = true;
        }
      }
    }
    _cover.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _pages.dispose();
    _currentPage.dispose();
    _category.dispose();
    _cover.dispose();
    _tags.dispose();
    _notes.dispose();
    _started.dispose();
    _finished.dispose();
    super.dispose();
  }

  String _today() {
    final d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _onStatusChanged(String value) {
    setState(() {
      _status = value;
      if (value == 'reading' && _started.text.trim().isEmpty) {
        _started.text = _today();
      }
      if (value == 'finished') {
        if (_started.text.trim().isEmpty) _started.text = _today();
        if (_finished.text.trim().isEmpty) _finished.text = _today();
      } else {
        _rating = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookFormHeader(
              title: 'Yeni kitap',
              subtitle: widget.initial != null
                  ? 'Bilgileri kontrol et, dilediğini düzenle'
                  : 'Kitabının künyesini oluştur',
              busy: _busy,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        BookFormError(message: _error!),
                        const SizedBox(height: 14),
                      ],

                      // Kapak önizleme + URL
                      BookCoverPreview(
                        url: _cover.text,
                        title: _title.text,
                        author: _author.text,
                      ),
                      const SizedBox(height: 16),

                      // Kitap bilgileri
                      BookFormSection(
                        icon: Icons.menu_book_rounded,
                        title: 'Kitap bilgileri',
                        children: [
                          TextFormField(
                            controller: _title,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Kitap adı *',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Kitap adı gerekli'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _author,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Yazar',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            hint: const Text('Seç'),
                            items: _bookCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedCategory = value;
                                      _customCategory = value == 'Diğer';
                                      if (!_customCategory) {
                                        _category.text = value ?? '';
                                      } else {
                                        _category.clear();
                                      }
                                    });
                                  },
                          ),
                          if (_customCategory) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _category,
                              decoration: const InputDecoration(
                                labelText: 'Kendi kategorin',
                                prefixIcon: Icon(Icons.add_rounded),
                              ),
                              validator: (v) =>
                                  _customCategory && (v ?? '').trim().isEmpty
                                  ? 'Kategori adını yaz'
                                  : null,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Okuma durumu
                      BookFormSection(
                        icon: Icons.auto_stories_rounded,
                        title: 'Okuma durumu',
                        children: [
                          BookStatusSelector(
                            value: _status,
                            onChanged: _busy ? null : _onStatusChanged,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _pages,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Toplam sayfa *',
                                    prefixIcon: Icon(Icons.menu_book_rounded),
                                  ),
                                  validator: (v) {
                                    final n = int.tryParse((v ?? '').trim());
                                    return n == null || n <= 0
                                        ? 'Gerekli'
                                        : null;
                                  },
                                ),
                              ),
                              if (_status == 'reading') ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _currentPage,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Şu an',
                                      prefixIcon: Icon(Icons.bookmark_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_status != 'want_to_read') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: BookDateField(
                                    label: 'Başlangıç',
                                    controller: _started,
                                  ),
                                ),
                                if (_status == 'finished') ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: BookDateField(
                                      label: 'Bitiş',
                                      controller: _finished,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                          if (_status == 'finished') ...[
                            const SizedBox(height: 14),
                            BookRatingPicker(
                              rating: _rating,
                              onChanged: (v) => setState(() => _rating = v),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Ekstra
                      BookFormSection(
                        icon: Icons.tune_rounded,
                        title: 'Ekstra',
                        collapsible: true,
                        initiallyOpen: widget.initial == null,
                        children: [
                          TextFormField(
                            controller: _cover,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Kapak görseli (URL)',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tags,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Etiketler (virgülle)',
                              hintText: 'klasik, favori, yaz',
                              prefixIcon: Icon(Icons.label_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notlar',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.sticky_note_2_outlined),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _favorite,
                            onChanged: (v) => setState(() => _favorite = v),
                            secondary: Icon(
                              _favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _favorite ? Colors.redAccent : null,
                            ),
                            title: const Text(
                              'Favorilere ekle',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            BookFormFooter(
              busy: _busy,
              label: 'Kitabı ekle',
              icon: Icons.add_rounded,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final total = int.parse(_pages.text.trim());
    final finished = _status == 'finished';
    int? current;
    if (finished) {
      current = total;
    } else if (_status == 'reading') {
      current = int.tryParse(_currentPage.text.trim());
      if (current != null && current > total) {
        setState(() => _error = 'Şu anki sayfa toplamdan büyük olamaz.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await _service.createBook(
        title: _title.text.trim(),
        totalPages: total,
        author: _nullIfEmpty(_author.text),
        category: _nullIfEmpty(_category.text),
        coverUrl: _nullIfEmpty(_cover.text),
        tags: _nullIfEmpty(_tags.text),
        notes: _nullIfEmpty(_notes.text),
        startedAt: _nullIfEmpty(_started.text),
        finishedAt: finished ? _nullIfEmpty(_finished.text) : null,
        isFinished: finished ? true : null,
        currentPage: current,
        favorite: _favorite ? true : null,
        rating: finished ? _rating : null,
        readingStatus: _status,
      );
      if (!mounted) return;
      Navigator.pop(context, id);
      if (widget.toastContext.mounted) {
        AppToast.success(
          widget.toastContext,
          _title.text.trim(),
          title: 'Kitap kütüphanene eklendi',
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Kitap eklenemedi');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _nullIfEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();
}
