import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalog_book.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/cover_photo_service.dart';
import 'app_toast.dart';
import 'book_form.dart';
import '../utils/turkish.dart';

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

Future<int?> showAddBookModal(
  BuildContext context, {
  CatalogBook? initial,
  String? isbn,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddBookSheet(
      initial: initial,
      isbn: isbn,
      toastContext: context,
    ),
  );
}

class _AddBookSheet extends StatefulWidget {
  const _AddBookSheet({this.initial, this.isbn, required this.toastContext});
  final CatalogBook? initial;

  /// Okutulan barkod. Künye bulunamasa da elimizde kalır; kaydedilir ve
  /// kullanıcıya "barkodu aldık" diye gösterilir.
  final String? isbn;

  final BuildContext toastContext;

  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _service = BookService();
  final _form = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _author = TextEditingController();
  final _publisher = TextEditingController();
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
  List<String> _knownAuthors = const [];
  List<String> _knownPublishers = const [];

  @override
  void initState() {
    super.initState();
    final book = widget.initial;
    if (book != null) {
      _title.text = book.title;
      _author.text = book.author ?? '';
      _publisher.text = book.publisher ?? '';
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
    _loadKnownAuthors();
  }

  Future<void> _loadKnownAuthors() async {
    try {
      final authors = await _service.knownAuthors();
      final publishers = await _service.knownPublishers();
      if (!mounted) return;
      setState(() {
        _knownAuthors = authors;
        _knownPublishers = publishers;
      });
    } catch (_) {
      // Öneri gelmezse form yine çalışır.
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
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

  /// Kapak alanındaki değer kullanıcının çektiği bir fotoğraf mı?
  bool get _coverIsPhoto => CoverPhotoService.isLocalPath(_cover.text);

  Future<void> _captureCover() => _setCoverFrom(CoverPhotoService.capture);

  Future<void> _pickCover() =>
      _setCoverFrom(CoverPhotoService.pickFromGallery);

  Future<void> _setCoverFrom(Future<String?> Function() source) async {
    try {
      final path = await source();
      if (path == null || !mounted) return;
      _cover.text = path;
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Kapak alınamadı. Kamera/galeri izni verilmemiş olabilir.',
      );
    }
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

                      // Barkod okundu ama künye bulunamadıysa: kullanıcı
                      // boşuna uğraştığını sanmasın, barkodun saklandığını
                      // ve kapağı kendi çekebileceğini söyleyelim.
                      if (widget.initial == null && widget.isbn != null) ...[
                        _ScannedHint(isbn: widget.isbn!),
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
                          // Kitaplıkta geçen yazarlar öneri olarak çıkar:
                          // aynı yazarın ikinci kitabında adı tekrar
                          // yazmaya (üstelik Türkçe harflerle) gerek kalmaz.
                          _SuggestField(
                            controller: _author,
                            suggestions: _knownAuthors,
                            onChanged: () => setState(() {}),
                            label: 'Yazar',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                          // Türkçe okurda kitap yayıneviyle anılır: aynı
                          // eserin farklı yayınevi farklı çeviri demek.
                          _SuggestField(
                            controller: _publisher,
                            suggestions: _knownPublishers,
                            onChanged: () => setState(() {}),
                            label: 'Yayınevi',
                            icon: Icons.apartment_rounded,
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
                            decoration: InputDecoration(
                              labelText: _coverIsPhoto
                                  ? 'Kapak (çektiğin fotoğraf)'
                                  : 'Kapak görseli (URL)',
                              prefixIcon: const Icon(Icons.image_outlined),
                              suffixIcon: _cover.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Kapağı kaldır',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => _cover.clear(),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Türkçe baskıların çoğunda çevrimiçi kapak yok;
                          // kapaksız kitap rafın görünüşünü bozuyor.
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _captureCover,
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Kapağı çek'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _pickCover,
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Galeriden'),
                                ),
                              ),
                            ],
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
        publisher: _nullIfEmpty(_publisher.text),
        isbn: widget.isbn ?? widget.initial?.isbn,
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

/// Barkod okundu ama çevrimiçi künye bulunamadı: kullanıcıyı bilgilendirir.
///
/// Türkçe baskıların çoğu Google Books ve Open Library'de yok. Bu durumda
/// kullanıcıya "bulunamadı" deyip boş bir form açmak, onu kaybetmenin en
/// hızlı yolu. Bunun yerine barkodu sakladığımızı ve kapağı kendisinin
/// çekebileceğini söylüyoruz.
class _ScannedHint extends StatelessWidget {
  const _ScannedHint({required this.isbn});

  final String isbn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: .28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.qr_code_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barkodu okuduk, künyeyi bulamadık',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Türkçe baskıların çoğu çevrimiçi kataloglarda yok. '
                  'Bilgileri sen gir; kapağı aşağıdan çekebilirsin.',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ISBN $isbn kaydedildi',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Yazar alanı — kitaplıkta geçen adları önerir.
///
/// Autocomplete kullanılıyor ama alan serbest: öneri listesinde olmayan bir
/// yazar da yazılabilir. Öneriler Türkçe harf duyarsız eşleşir ("sabahattin"
/// yazınca "Sabahattin Ali" çıkar).
class _SuggestField extends StatefulWidget {
  const _SuggestField({
    required this.controller,
    required this.suggestions,
    required this.onChanged,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final VoidCallback onChanged;
  final String label;
  final IconData icon;

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  // RawAutocomplete'e verilen odak düğümü kalıcı olmalı; build içinde
  // üretilirse her çizimde yenilenir, odak kaçar ve düğüm sızar.
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final query = foldTurkish(value.text.trim());
        if (query.isEmpty) return const Iterable<String>.empty();
        return widget.suggestions
            .where((author) => foldTurkish(author).contains(query))
            .take(5);
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          onChanged: (_) => widget.onChanged(),
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final cs = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(14),
            color: cs.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_rounded, size: 18),
                    title: Text(
                      option,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
