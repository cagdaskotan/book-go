// lib/screens/diary.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/gamification_service.dart';
import '../models/gamification_summary.dart';
import '../services/reading_goal_service.dart';
import '../services/reading_pace.dart';
import '../theme/app_theme.dart';
import 'reading_session.dart';
import 'book_finish_celebration.dart';
import 'journal_gallery.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/app_progress_bar.dart';
import '../widgets/app_toast.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_open_hero.dart';
import '../widgets/book_form.dart';
import '../widgets/goal_celebration.dart';
import '../widgets/mascot.dart';
import '../widgets/quote_section.dart';
import '../widgets/collection_picker.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({
    super.key,
    required this.bookId,
    this.heroTag,
    this.initialCoverUrl,
    this.initialSpineColor,
    this.initialFinished = false,
  });
  final int bookId;

  /// Koleksiyon rafından gelirken benzersiz Hero etiketi ve kapağın hemen
  /// çizilebilmesi için ön bilgiler. Diğer girişlerde null kalır.
  final Object? heroTag;
  final String? initialCoverUrl;
  final Color? initialSpineColor;
  final bool initialFinished;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late final BookService _service = BookService();
  final _gam = GamificationService();

  int? _bookId;
  Book? _book;
  List<BookLog> _logs = const [];
  GamificationSummary? _summary;

  bool _loading = true;
  String? _error;
  bool _logBusy = false;

  Future<void> _refreshSummary() async {
    try {
      final s = await _gam.fetchSummary();
      if (mounted) setState(() => _summary = s);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final id = _bookId ?? widget.bookId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await _service.getBook(id);
      final logs = await _service.fetchLogs(id);
      if (!mounted) return;
      setState(() {
        _book = book;
        _logs = logs;
      });
      await _refreshSummary();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Geçersiz yanıt');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  // -------------------- Derived & helpers --------------------
  int get _totalPages => _book?.totalPages ?? 0;

  int get _pagesRead {
    final sum = _logs.fold<int>(0, (a, l) => a + (l.pagesRead ?? 0));
    if (sum > 0) return sum;
    if (_book?.isFinished == true) return _totalPages;
    return _book?.currentPage ?? 0;
  }

  String _fmtDateTr(String v) {
    final p = v.split('T').first.split('-');
    if (p.length == 3) {
      final y = p[0], m = p[1], d = p[2];
      return '$d.$m.$y';
    }
    return v;
  }

  String _dateSpan(String? first, String? last) {
    if ((first ?? '').isEmpty && (last ?? '').isEmpty) return '—';
    if ((first ?? '').isEmpty) return _fmtDateTr(last!);
    if ((last ?? '').isEmpty) return _fmtDateTr(first!);
    if (first == last) return _fmtDateTr(first!);
    return '${_fmtDateTr(first!)} → ${_fmtDateTr(last!)}';
  }

  // -------------------- Actions --------------------
  Future<void> _toggleFavorite() async {
    final b = _book;
    if (b == null) return;
    final prev = b.favorite;
    setState(() => _book = b.copyWith(favorite: !prev));
    try {
      await _service.updateFavorite(b.id, !prev);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _book = b.copyWith(favorite: prev));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _book = b.copyWith(favorite: prev));
    }
  }

  Future<void> _deleteBook() async {
    final ok = await _confirmSheet(
      context,
      title: 'Kitabı sil',
      message: 'Bu kitap ve günlük kayıtları silinsin mi?',
      confirmText: 'Sil',
      confirmColor: Colors.redAccent,
    );
    if (ok != true) return;

    try {
      final b = _book!;
      await _service.deleteBook(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kitap silindi')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silinemedi')));
    }
  }

  Future<void> _openEditBook() async {
    final b = _book;
    if (b == null) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookEditSheet(book: b),
    );

    final wasFinished = b.isFinished;
    if (ok != true) return;
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
    await _maybeCelebrate(wasFinished);
  }

  Future<void> _openLogModal({BookLog? edit}) async {
    final b = _book;
    if (b == null) return;
    final wasFinished = b.isFinished;
    final beforeGoalMet = _summary?.dailyGoalMet ?? false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogEditSheet(
        bookId: b.id,
        initial: edit,
        busy: _logBusy,
        remainingPages: (_totalPages - _pagesRead).clamp(0, _totalPages),
        onBusy: (v) => setState(() => _logBusy = v),
        onDone: () async {}, // kutlama akışı _loadAll'ı kendisi yapacak
      ),
    );
    if (ok != true) return;
    await _celebrateAfterLog(wasFinished, beforeGoalMet);
  }

  /// Kitap "bitti" durumuna yeni geçtiyse kutlama ekranını açar.
  /// Kutlama gösterdiyse true döner.
  Future<bool> _maybeCelebrate(bool wasFinished) async {
    final b = _book;
    if (!mounted || b == null || wasFinished || !b.isFinished) return false;
    HapticFeedback.heavyImpact();

    List<Book> all = const [];
    try {
      all = await _service.fetchBooks();
    } catch (_) {}
    final goal = await ReadingGoalService.getYearlyGoal();
    final finished = ReadingGoalService.finishedInYear(
      all.isEmpty ? [b] : all,
    );
    if (!mounted) return false;

    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => BookFinishCelebration(
          book: b,
          daysToFinish: _daysToFinish(b),
          yearlyFinished: finished,
          yearlyGoal: goal,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    return true;
  }

  /// Bir okuma kaydından sonra: önce kitap bitti mi, değilse günlük hedef
  /// yeni mi tamamlandı? — uygun kutlamayı gösterir.
  Future<void> _celebrateAfterLog(bool wasFinished, bool beforeGoalMet) async {
    await _loadAll(); // _book ve _summary güncellensin
    if (!mounted) return;
    final celebratedFinish = await _maybeCelebrate(wasFinished);
    if (celebratedFinish || !mounted) return;
    final s = _summary;
    if (!beforeGoalMet && s != null && s.dailyGoalMet) {
      await showGoalCelebration(context, s);
    }
  }

  int? _daysToFinish(Book b) {
    DateTime? parse(String? s) {
      final parts = (s ?? '').trim().split('-');
      if (parts.length != 3) return null;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) return null;
      return DateTime(y, m, d);
    }

    final start = parse(b.startedAt) ?? b.createdAt;
    final end = parse(b.finishedAt) ?? DateTime.now();
    final days = end.difference(start).inDays;
    return days >= 0 ? days + 1 : null;
  }

  Future<void> _openReadingSession() async {
    final b = _book;
    if (b == null) return;
    final minutes = await Navigator.of(context).push<int>(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => ReadingSessionPage(book: b),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
    if (minutes == null || minutes <= 0 || !mounted) return;
    await _openLogModal(
      edit: BookLog(
        id: 0,
        bookId: b.id,
        logDate: _todayDate(),
        durationMinutes: minutes,
      ),
    );
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Tek dokunuşla bugüne hızlı sayfa kaydı ekler.
  Future<void> _quickLog(int pages) async {
    final b = _book;
    if (b == null || _logBusy) return;
    final wasFinished = b.isFinished;
    final beforeGoalMet = _summary?.dailyGoalMet ?? false;
    HapticFeedback.lightImpact();
    setState(() => _logBusy = true);
    try {
      await _service.createLog(
        BookLog(id: 0, bookId: b.id, logDate: _todayDate(), pagesRead: pages),
      );
      if (!mounted) return;
      AppToast.success(
        context,
        '+$pages sayfa ilerleme günlüğüne işlendi.',
        title: 'Bugün harika gidiyorsun',
      );
      await _celebrateAfterLog(wasFinished, beforeGoalMet);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message, title: 'Kayıt eklenemedi');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Lütfen tekrar dene.', title: 'Kayıt eklenemedi');
    } finally {
      if (mounted) setState(() => _logBusy = false);
    }
  }

  Future<void> _deleteLog(BookLog log) async {
    final ok = await _confirmSheet(
      context,
      title: 'Kaydı sil',
      message: 'Bu günlük kaydı silinsin mi?',
      confirmText: 'Sil',
      confirmColor: Colors.redAccent,
    );
    if (ok != true) return;

    try {
      await _service.deleteLog(log.id);
      await _loadAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silinemedi')));
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = _book;

    if (_loading && widget.initialCoverUrl != null) {
      return _loadingHeroScaffold();
    }

    if (_loading || _error != null || b == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kitap Detayı')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadAll,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              )
            : const Center(child: Text('Kitap bulunamadı')),
      );
    }

    return Scaffold(body: _buildBody(b, cs));
  }

  Widget _buildBody(Book b, ColorScheme cs) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: cs.primary,
      edgeOffset: 130,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _heroAppBar(b),

          SliverToBoxAdapter(child: _actionBar(b, cs)),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            sliver: SliverToBoxAdapter(child: _progressCard(b, cs)),
          ),

          if (b.rating != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _ratingCard(b, cs)),
            ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            sliver: SliverToBoxAdapter(child: _compactMetrics(cs)),
          ),

          if (_buildPaceCard(b, cs) case final paceCard?)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              sliver: SliverToBoxAdapter(child: paceCard),
            ),

          // ------- Alıntılar -------
          SliverToBoxAdapter(child: QuoteSection(key: ValueKey(b.id), book: b)),

          // ------- "Okuma Günlüğü" başlığı -------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Okuma Günlüğü',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      fontSize: 18,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_logs.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: _logs.isEmpty
                ? SliverToBoxAdapter(
                    child: _SurfaceCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Mascot(mood: MascotMood.reading, size: 92),
                          const SizedBox(height: 6),
                          Text(
                            'Henüz günlük kaydı yok',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bir okuma oturumu başlat veya ilk kaydını ekle.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: () => _openLogModal(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('İlk kaydını ekle'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: _logs.length,
                    itemBuilder: (_, i) =>
                        _timelineEntry(_logs[i], i, _logs.length, cs),
                  ),
          ),
        ],
      ),
    );
  }

  // Kitap içeriği yüklenirken, kapağı gerçek başlıktaki konum ve ölçüde hemen
  // gösterir. Böylece raftan gelen Hero uçuşunun hedefi en baştan hazırdır ve
  // yükleme bitince kapak yerinden zıplamaz.
  Widget _loadingHeroScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFF171335),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 390,
            pinned: true,
            backgroundColor: const Color(0xFF171335),
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x99120E2C),
                          Color(0xDD171335),
                          Color(0xFF171335),
                        ],
                        stops: [0, .48, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 82, 20, 24),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: BookOpenHero(
                          bookId: widget.bookId,
                          tag: widget.heroTag,
                          coverUrl: widget.initialCoverUrl,
                          spineColor:
                              widget.initialSpineColor ??
                              const Color(0xFF5D3825),
                          finished: widget.initialFinished,
                          child: _CoverThumb(
                            url: widget.initialCoverUrl,
                            finished: widget.initialFinished,
                            size: const Size(126, 184),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroAppBar(Book b) {
    final progress = _totalPages == 0
        ? 0.0
        : (_pagesRead / _totalPages).clamp(0.0, 1.0);
    return SliverAppBar(
      expandedHeight: 390,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF171335),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: b.favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
          onPressed: _toggleFavorite,
          icon: Icon(
            b.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Kitap işlemleri',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) {
            if (value == 'collection') {
              showCollectionPicker(context, b.id);
            } else if (value == 'journal') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JournalGalleryPage(
                    bookId: b.id,
                    bookTitle: b.title,
                    author: b.author,
                    coverUrl: b.coverUrl,
                  ),
                ),
              );
            } else if (value == 'edit') {
              _openEditBook();
            } else if (value == 'delete') {
              _deleteBook();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'collection',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.collections_bookmark_rounded),
                title: Text('Rafa ekle'),
              ),
            ),
            PopupMenuItem(
              value: 'journal',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.menu_book_rounded),
                title: Text('Alıntı defteri'),
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_rounded),
                title: Text('Kitabı düzenle'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text('Kitabı sil'),
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if ((b.coverUrl ?? '').trim().isNotEmpty)
              CachedNetworkImage(
                imageUrl: b.coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                placeholder: (_, __) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99120E2C),
                    Color(0xDD171335),
                    Color(0xFF171335),
                  ],
                  stops: [0, .48, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 82, 20, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    BookOpenHero(
                      bookId: b.id,
                      tag: widget.heroTag,
                      coverUrl: b.coverUrl,
                      spineColor:
                          widget.initialSpineColor ?? const Color(0xFF5D3825),
                      finished: b.isFinished,
                      child: _CoverThumb(
                        url: b.coverUrl,
                        finished: b.isFinished,
                        size: const Size(126, 184),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Chip(
                            text: _statusLabel(b),
                            color: Colors.white.withValues(alpha: .13),
                            textColor: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            b.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              height: 1.04,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.8,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            (b.author ?? '').trim().isEmpty
                                ? 'Yazar bilgisi yok'
                                : b.author!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          // Yayınevi Türkçe baskılarda kitabın kimliğinin
                          // parçası; bilinmiyorsa satır hiç görünmesin.
                          if ((b.publisher ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.apartment_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: .55),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    b.publisher!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: .55,
                                      ),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Color(0xFFFFC879),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 7,
                                    backgroundColor: Colors.white12,
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFFFFC879),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(Book b, ColorScheme cs) {
    return Transform.translate(
      offset: const Offset(0, -1),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .07),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: b.isFinished ? null : _openReadingSession,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  b.isFinished ? 'Kitap tamamlandı' : 'Okumaya başla',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF6750E8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _RoundAction(
              icon: Icons.add_rounded,
              tooltip: 'Günlük kaydı ekle',
              onTap: () => _openLogModal(),
            ),
            const SizedBox(width: 8),
            _RoundAction(
              icon: Icons.edit_outlined,
              tooltip: 'Kitabı düzenle',
              onTap: _openEditBook,
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard(Book b, ColorScheme cs) {
    final progress = _totalPages == 0
        ? 0.0
        : (_pagesRead / _totalPages).clamp(0.0, 1.0);
    final remaining = (_totalPages - _pagesRead).clamp(0, _totalPages);
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_stories_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Okuma yolculuğun',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      b.isFinished
                          ? 'Bu hikâyeyi tamamladın.'
                          : '$remaining sayfa sonra yeni bir hikâye tamamlanacak.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppProgressBar(value: progress, height: 18, showLabel: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$_pagesRead / $_totalPages sayfa',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (!b.isFinished)
                for (final pages in const [5, 10, 25])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('+$pages'),
                      onPressed: _logBusy ? null : () => _quickLog(pages),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingCard(Book b, ColorScheme cs) {
    final rating = b.rating ?? 0;
    final stars = (rating / 20).round().clamp(0, 5);
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0CC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Senin puanın',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          for (var i = 0; i < 5; i++)
            Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFF59E0B),
              size: 20,
            ),
          const SizedBox(width: 8),
          Text(
            '$rating',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  String _statusLabel(Book b) => switch (b.readingStatus) {
    'reading' => 'Okuyorum',
    'paused' => 'Ara verdim',
    'finished' => 'Tamamlandı',
    _ => 'Okuma listemde',
  };

  // Kept temporarily while the new detail hero settles.
  // ignore: unused_element
  Widget _header(Book b, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: _SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: kapak + başlık/alt metin + aksiyonlar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverThumb(
                  url: b.coverUrl,
                  finished: b.isFinished,
                  size: const Size(92, 132),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (b.author == null || b.author!.trim().isEmpty)
                            ? 'Bilinmeyen Yazar'
                            : b.author!,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: .7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if ((b.category ?? '').trim().isNotEmpty)
                            _Chip(text: b.category!.trim()),
                          if ((b.startedAt ?? '').isNotEmpty ||
                              (b.finishedAt ?? '').isNotEmpty)
                            _Chip(text: _dateSpan(b.startedAt, b.finishedAt)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _FavButton(isFav: b.favorite, onTap: _toggleFavorite),
                    const SizedBox(height: 6),
                    PopupMenuButton<String>(
                      tooltip: 'Diğer işlemler',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'collection',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.collections_bookmark_rounded,
                              size: 20,
                            ),
                            title: Text('Koleksiyona ekle'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.edit, size: 20),
                            title: Text('Düzenle'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            title: Text('Sil'),
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'collection') {
                          showCollectionPicker(context, b.id);
                        } else if (value == 'edit') {
                          _openEditBook();
                        } else if (value == 'delete') {
                          _deleteBook();
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: cs.outlineVariant),
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: cs.onSurface.withValues(alpha: .6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress panel
            _SurfaceCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Okuma İlerlemesi',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: .7),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_pagesRead.toString()} / ${_totalPages.toString()} sayfa',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: b.isFinished
                              ? cs.tertiaryContainer
                              : cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Text(
                          b.isFinished ? 'Bitti' : 'Devam Ediyor',
                          style: TextStyle(
                            color: b.isFinished
                                ? cs.onTertiaryContainer
                                : cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _GradientProgressBar.adaptive(
                    value: (_totalPages == 0)
                        ? 0
                        : (_pagesRead / _totalPages).clamp(0.0, 1.0),
                    height: 18,
                    showCenterPercent: true,
                    bgColor: cs.outlineVariant.withValues(alpha: .35),
                    centerStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  if (!b.isFinished) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 17, color: cs.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Hızlı kayıt',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 7,
                            children: [
                              for (final pages in const [5, 10, 25])
                                ActionChip(
                                  label: Text('+$pages'),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: cs.primary,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(
                                    color: cs.primary.withValues(alpha: .35),
                                  ),
                                  onPressed: _logBusy
                                      ? null
                                      : () => _quickLog(pages),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (b.rating != null) ...[
              const SizedBox(height: 12),
              _SurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      'Puan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < ((b.rating! / 20).round().clamp(0, 5))
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                    const Spacer(),
                    Text(
                      '${b.rating}/100',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compactMetrics(ColorScheme cs) {
    final uniqueDays = _logs.map((e) => e.logDate).toSet().length;
    final noteCount = _logs
        .where((e) => (e.note ?? '').trim().isNotEmpty)
        .length;
    final avg = uniqueDays == 0 ? 0 : (_pagesRead / uniqueDays).round();
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              icon: Icons.calendar_today_rounded,
              value: '$uniqueDays',
              label: 'okuma günü',
              color: cs.primary,
            ),
          ),
          _MetricDivider(color: cs.outlineVariant),
          Expanded(
            child: _MetricItem(
              icon: Icons.sticky_note_2_rounded,
              value: '$noteCount',
              label: 'okuma notu',
              color: const Color(0xFFF59E0B),
            ),
          ),
          _MetricDivider(color: cs.outlineVariant),
          Expanded(
            child: _MetricItem(
              icon: Icons.bolt_rounded,
              value: '$avg',
              label: 'sayfa / gün',
              color: const Color(0xFF2BAE8A),
            ),
          ),
        ],
      ),
    );
  }

  /// Devam eden kitap için okuma temposu + tahmini bitiş kartı.
  /// Yeterli veri yoksa null döner.
  Widget? _buildPaceCard(Book b, ColorScheme cs) {
    // Hesabın tamamı [reading_pace] modülünde: testli, başka ekranlarda da
    // kullanılabilir. Burada yalnızca gösterim var.
    final pace = computeReadingPace(_logs);
    final estimate = estimateFinish(
      book: b,
      pace: pace,
      basis: PaceBasis.activeDays,
    );
    if (estimate == null || !estimate.hasDate) return null;

    final finishDate = estimate.date!;
    final daysLeft = estimate.daysLeft!;
    final remaining = estimate.remainingPages;
    final avgPerDay = pace.pagesPerActiveDay ?? 0;
    final pagesPerHour = pace.pagesPerMinute == null
        ? null
        : (pace.pagesPerMinute! * 60).round();

    String two(int v) => v.toString().padLeft(2, '0');
    final dateStr =
        '${two(finishDate.day)}.${two(finishDate.month)}.${finishDate.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B3CB1), Color(0xFF7A5BE6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6750E8).withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tahmini bitiş',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  daysLeft == 1 ? '1 gün' : '$daysLeft gün',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _paceChip(
                Icons.bolt_rounded,
                'günde ~${avgPerDay.round()} sayfa',
              ),
              _paceChip(
                Icons.menu_book_rounded,
                'kalan $remaining sayfa',
              ),
              if (pagesPerHour != null && pagesPerHour > 0)
                _paceChip(
                  Icons.speed_rounded,
                  '≈ $pagesPerHour sayfa/saat',
                ),
              if (estimate.minutesLeft case final minutes?)
                _paceChip(
                  Icons.timer_outlined,
                  '≈ ${formatMinutes(minutes)} okuma kaldı',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paceChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _metrics(Book b, ColorScheme cs) {
    final uniqueDays = _logs.map((e) => e.logDate).toSet().length;
    final noteCount = _logs
        .where((e) => (e.note ?? '').trim().isNotEmpty)
        .length;
    final first = _logs.isNotEmpty ? _logs.last.logDate : (b.startedAt ?? '');
    final last = _logs.isNotEmpty ? _logs.first.logDate : (b.finishedAt ?? '');
    final avg = uniqueDays == 0 ? 0 : (_pagesRead / uniqueDays).round();

    return Row(
      children: [
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricLabel('Okuma Günleri', cs),
                const SizedBox(height: 6),
                _metricValue('$uniqueDays', cs),
                _metricHint('Gün boyunca kayıt tutulmuş.', cs),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricLabel('Not Sayısı', cs),
                const SizedBox(height: 6),
                _metricValue('$noteCount', cs),
                _metricHint('Anlamlı not bulunan kayıtlar.', cs),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricLabel('Ortalama', cs),
                const SizedBox(height: 6),
                _metricValue('$avg sayfa/gün', cs),
                _metricHint(_dateSpan(first, last), cs),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricLabel(String s, ColorScheme cs) => Text(
    s,
    style: TextStyle(
      color: cs.onSurface.withValues(alpha: .7),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  );

  Widget _metricValue(String s, ColorScheme cs) => Text(
    s,
    style: TextStyle(
      color: cs.onSurface,
      fontWeight: FontWeight.w900,
      fontSize: 20,
    ),
  );

  Widget _metricHint(String s, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      s,
      style: TextStyle(color: cs.onSurface.withValues(alpha: .7), fontSize: 12),
    ),
  );

  // ---------------- Zaman çizelgesi (timeline) kaydı ----------------
  Widget _timelineEntry(BookLog log, int index, int total, ColorScheme cs) {
    final pages = log.pagesRead ?? 0;
    final isFirst = index == 0;
    final isLast = index == total - 1;
    final (badgeIcon, badgeColor) = _logBadge(log);
    final rel = _relativeDay(log.logDate);
    final hasNote = (log.note ?? '').trim().isNotEmpty;
    final lineColor = cs.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sol ray: bağlantı çizgisi + tip işareti
          SizedBox(
            width: 38,
            child: Column(
              children: [
                SizedBox(
                  height: 16,
                  child: Center(
                    child: Container(
                      width: 2.5,
                      color: isFirst ? Colors.transparent : lineColor,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: .35),
                        blurRadius: 9,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(badgeIcon, color: Colors.white, size: 17),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2.5,
                      color: isLast ? Colors.transparent : lineColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Kayıt kartı
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 14, top: 2),
              child: _SurfaceCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _fmtDateTr(log.logDate),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (rel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: .7,
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              rel,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        _logActions(log, cs),
                      ],
                    ),
                    if (pages > 0 || log.durationMinutes > 0 || log.finished) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (pages > 0)
                            _miniChip(
                              Icons.auto_stories_rounded,
                              '+$pages sayfa',
                              cs.primary,
                            ),
                          if (log.durationMinutes > 0)
                            _miniChip(
                              Icons.timer_rounded,
                              '${log.durationMinutes} dk',
                              cs.secondary,
                            ),
                          if (log.finished)
                            _miniChip(
                              Icons.flag_rounded,
                              'Bitirdim',
                              const Color(0xFF2BAE8A),
                            ),
                        ],
                      ),
                    ],
                    if (hasNote) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: .45,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(color: cs.primary, width: 3),
                          ),
                        ),
                        child: Text(
                          log.note!.trim(),
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: .9),
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _logBadge(BookLog log) {
    if (log.finished) return (Icons.flag_rounded, const Color(0xFF2BAE8A));
    if ((log.pagesRead ?? 0) > 0) {
      return (Icons.auto_stories_rounded, const Color(0xFF6750E8));
    }
    if (log.durationMinutes > 0) {
      return (Icons.timer_rounded, const Color(0xFF8B5CF6));
    }
    return (Icons.sticky_note_2_rounded, const Color(0xFFF59E0B));
  }

  Widget _miniChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logActions(BookLog log, ColorScheme cs) {
    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<String>(
        tooltip: 'İşlemler',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: cs.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onSelected: (v) {
          if (v == 'edit') {
            _openLogModal(edit: log);
          } else if (v == 'delete') {
            _deleteLog(log);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_rounded, size: 19),
              title: Text('Düzenle'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                size: 19,
                color: Colors.redAccent,
              ),
              title: Text('Sil'),
            ),
          ),
        ],
      ),
    );
  }

  /// "bugün / dün / 3 gün önce / 2 hafta önce" gibi göreli etiket.
  String _relativeDay(String dateStr) {
    final d = DateTime.tryParse(dateStr.split('T').first);
    if (d == null) return '';
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(d.year, d.month, d.day);
    final diff = t0.difference(d0).inDays;
    if (diff == 0) return 'bugün';
    if (diff == 1) return 'dün';
    if (diff > 1 && diff < 7) return '$diff gün önce';
    if (diff >= 7 && diff < 30) return '${(diff / 7).floor()} hafta önce';
    if (diff >= 30 && diff < 365) return '${(diff / 30).floor()} ay önce';
    if (diff < 0) return '';
    return '${(diff / 365).floor()} yıl önce';
  }
}

// ================== MODERN SHEETLer & KÜÇÜK PARÇALAR ==================

Future<bool?> _confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  Color? confirmColor,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _GlassSheet(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: cs.onSurface.withValues(alpha: .8)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor ?? cs.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BookEditSheet extends StatefulWidget {
  const _BookEditSheet({required this.book});
  final Book book;

  @override
  State<_BookEditSheet> createState() => _BookEditSheetState();
}

class _BookEditSheetState extends State<_BookEditSheet> {
  final _svc = BookService();
  final _form = GlobalKey<FormState>();

  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(text: widget.book.author ?? '');
  late final _publisher = TextEditingController(
    text: widget.book.publisher ?? '',
  );
  late final _total = TextEditingController(text: '${widget.book.totalPages}');
  late final _cover = TextEditingController(text: widget.book.coverUrl ?? '');
  late final _category = TextEditingController(
    text: widget.book.category ?? '',
  );
  late final _tags = TextEditingController(text: widget.book.tags ?? '');
  late final _started = TextEditingController(
    text: widget.book.startedAt ?? '',
  );
  late final _finished = TextEditingController(
    text: widget.book.finishedAt ?? '',
  );
  late final _current = TextEditingController(
    text: '${widget.book.currentPage}',
  );
  late final _notes = TextEditingController(text: widget.book.notes ?? '');
  bool _finishedFlag = false;
  late String _readingStatus;
  int? _rating;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _finishedFlag = widget.book.isFinished;
    _readingStatus = widget.book.readingStatus;
    _rating = widget.book.rating;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _total.dispose();
    _cover.dispose();
    _category.dispose();
    _tags.dispose();
    _started.dispose();
    _finished.dispose();
    _current.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onStatusChanged(String value) {
    setState(() {
      _readingStatus = value;
      _finishedFlag = value == 'finished';
      if (_finishedFlag && _finished.text.trim().isEmpty) {
        final d = DateTime.now();
        String two(int v) => v.toString().padLeft(2, '0');
        _finished.text = '${d.year}-${two(d.month)}-${two(d.day)}';
      }
      if (!_finishedFlag) _rating = null;
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
            const BookFormHeader(
              title: 'Kitabı düzenle',
              subtitle: 'Künyeyi güncel tut',
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_err != null) ...[
                        BookFormError(message: _err!),
                        const SizedBox(height: 14),
                      ],
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _cover,
                        builder: (_, coverVal, __) =>
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _title,
                              builder: (_, titleVal, __) =>
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _author,
                                    builder: (_, authorVal, __) =>
                                        BookCoverPreview(
                                          url: coverVal.text,
                                          title: titleVal.text,
                                          author: authorVal.text,
                                        ),
                                  ),
                            ),
                      ),
                      const SizedBox(height: 16),

                      BookFormSection(
                        icon: Icons.menu_book_rounded,
                        title: 'Kitap bilgileri',
                        children: [
                          TextFormField(
                            controller: _title,
                            decoration: const InputDecoration(
                              labelText: 'Kitap adı *',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Başlık gerekli'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _author,
                            decoration: const InputDecoration(
                              labelText: 'Yazar',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _publisher,
                            decoration: const InputDecoration(
                              labelText: 'Yayınevi',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _category,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      BookFormSection(
                        icon: Icons.auto_stories_rounded,
                        title: 'Okuma durumu',
                        children: [
                          BookStatusSelector(
                            value: _readingStatus,
                            includePaused: true,
                            onChanged: _busy ? null : _onStatusChanged,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _total,
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
                                        ? 'Pozitif sayı'
                                        : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _current,
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
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: BookDateField(
                                  label: 'Başlangıç',
                                  controller: _started,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: BookDateField(
                                  label: 'Bitiş',
                                  controller: _finished,
                                  enabled: _finishedFlag,
                                ),
                              ),
                            ],
                          ),
                          if (_finishedFlag) ...[
                            const SizedBox(height: 14),
                            BookRatingPicker(
                              rating: _rating,
                              onChanged: (v) => setState(() => _rating = v),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      BookFormSection(
                        icon: Icons.tune_rounded,
                        title: 'Ekstra',
                        collapsible: true,
                        initiallyOpen: false,
                        children: [
                          TextFormField(
                            controller: _cover,
                            decoration: const InputDecoration(
                              labelText: 'Kapak görseli (URL)',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tags,
                            decoration: const InputDecoration(
                              labelText: 'Etiketler (virgülle)',
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
              label: 'Değişiklikleri kaydet',
              icon: Icons.check_rounded,
              onSubmit: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final tp = int.tryParse(_total.text.trim()) ?? 0;
    final cp = int.tryParse(_current.text.trim()) ?? 0;
    if (cp > tp) {
      setState(() => _err = 'Şu anki sayfa toplamdan büyük olamaz');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await _svc.updateBook(
        widget.book.id,
        title: _title.text.trim(),
        // Boş metni null'a çevirmiyoruz: updateBook'ta null "dokunma"
        // demek, dolayısıyla alanı temizlemek imkânsız hale geliyordu.
        // Boş string gönderince alan gerçekten siliniyor.
        author: _author.text.trim(),
        publisher: _publisher.text.trim(),
        totalPages: tp,
        coverUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        tags: _tags.text.trim().isEmpty ? null : _tags.text.trim(),
        startedAt: _started.text.trim().isEmpty ? null : _started.text.trim(),
        finishedAt: _finishedFlag && _finished.text.trim().isNotEmpty
            ? _finished.text.trim()
            : null,
        isFinished: _finishedFlag,
        currentPage: cp,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        setRating: true,
        rating: _finishedFlag ? _rating : null,
        readingStatus: _readingStatus,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _err = e.message);
    } catch (e) {
      setState(() => _err = 'Beklenmeyen hata: $e');
    } finally {
      setState(() => _busy = false);
    }
  }
}

class _LogEditSheet extends StatefulWidget {
  const _LogEditSheet({
    required this.bookId,
    required this.initial,
    required this.busy,
    required this.remainingPages,
    required this.onBusy,
    required this.onDone,
  });

  final int bookId;
  final BookLog? initial;
  final bool busy;
  final int remainingPages;
  final ValueChanged<bool> onBusy;
  final Future<void> Function() onDone;

  @override
  State<_LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends State<_LogEditSheet> {
  final _svc = BookService();
  final _form = GlobalKey<FormState>();

  late final _date = TextEditingController(
    text: widget.initial?.logDate ?? _today(),
  );
  late final _pages = TextEditingController(
    text: (widget.initial?.pagesRead == null || widget.initial!.pagesRead == 0)
        ? ''
        : '${widget.initial!.pagesRead}',
  );
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late final _duration = TextEditingController(
    text: (widget.initial?.durationMinutes ?? 0) > 0
        ? widget.initial!.durationMinutes.toString()
        : '',
  );
  late bool _finished = widget.initial?.finished ?? false;
  bool _autoFilledPages = false;

  String? _err;

  String _today() {
    final d = DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  void dispose() {
    _date.dispose();
    _pages.dispose();
    _note.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isSession =
        widget.initial?.id == 0 && (widget.initial?.durationMinutes ?? 0) > 0;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSession
                                  ? const [Color(0xFF61D8B3), Color(0xFF2BAE8A)]
                                  : const [
                                      Color(0xFF6750E8),
                                      Color(0xFFA063ED),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSession
                                ? Icons.timer_rounded
                                : Icons.auto_stories_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isSession
                                ? 'Okuma oturumunu kaydet'
                                : widget.initial == null
                                ? 'Okuma kaydı ekle'
                                : 'Kaydı düzenle',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.4,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
                          onPressed: widget.busy
                              ? null
                              : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_err != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _err!,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: Form(
                    key: _form,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _Labeled(
                                'Tarih',
                                child: _DateField(controller: _date),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _Labeled(
                                'Okunan sayfa',
                                child: TextFormField(
                                  controller: _pages,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Opsiyonel',
                                  ),
                                  validator: (v) {
                                    if ((v ?? '').trim().isEmpty) return null;
                                    final n = int.tryParse(v!.trim());
                                    if (n == null || n <= 0) {
                                      return 'Pozitif sayı';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        _Labeled(
                          'Okuma süresi',
                          child: TextFormField(
                            controller: _duration,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Örn. 25',
                              suffixText: 'dakika',
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) return null;
                              final n = int.tryParse(v!.trim());
                              if (n == null || n <= 0) return 'Pozitif sayı';
                              return null;
                            },
                          ),
                        ),
                        _Labeled(
                          'Not',
                          child: _Multiline(
                            controller: _note,
                            hint: 'Opsiyonel',
                          ),
                        ),
                        Row(
                          children: [
                            Switch(
                              value: _finished,
                              onChanged: (v) => setState(() {
                                _finished = v;
                                if (v) {
                                  // Bitti seçilince okunan sayfayı kalan
                                  // (okunmamış) sayfa kadarıyla otomatik doldur.
                                  if (_pages.text.trim().isEmpty &&
                                      widget.remainingPages > 0) {
                                    _pages.text = '${widget.remainingPages}';
                                    _autoFilledPages = true;
                                  }
                                } else if (_autoFilledPages) {
                                  _pages.clear();
                                  _autoFilledPages = false;
                                }
                              }),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(child: Text('Kitabı bitirdim')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.busy ? null : _save,
                    icon: widget.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(widget.busy ? 'Kaydediliyor' : 'Kaydı tamamla'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final rawPages = _pages.text.trim();
    final nPages = int.tryParse(rawPages);
    final hasPages = rawPages.isNotEmpty && (nPages ?? 0) > 0;
    final hasNote = _note.text.trim().isNotEmpty;
    final duration = int.tryParse(_duration.text.trim()) ?? 0;

    if (!hasPages && !hasNote && duration == 0) {
      setState(() => _err = 'Sayfa, süre veya kısa bir not girin');
      return;
    }
    if (_finished && !hasPages && widget.initial == null) {
      setState(() => _err = 'Bitti işaretlediysen sayfa da gir');
      return;
    }

    widget.onBusy(true);
    setState(() => _err = null);
    try {
      if (widget.initial == null || widget.initial!.id == 0) {
        await _svc.createLog(
          BookLog(
            id: 0,
            bookId: widget.bookId,
            logDate: _date.text,
            pagesRead: hasPages ? nPages : 0,
            note: hasNote ? _note.text.trim() : null,
            finished: _finished,
            durationMinutes: duration,
          ),
        );
      } else {
        await _svc.updateLog(
          widget.initial!.copyWith(
            logDate: _date.text,
            pagesRead: hasPages ? nPages : 0,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            finished: _finished,
            durationMinutes: duration,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      await widget.onDone();
    } on ApiException catch (e) {
      setState(() => _err = e.message);
    } catch (e) {
      setState(() => _err = 'Beklenmeyen hata: $e');
    } finally {
      widget.onBusy(false);
    }
  }
}

class _ReadingTimerSheet extends StatefulWidget {
  const _ReadingTimerSheet({required this.book});
  final Book book;

  @override
  State<_ReadingTimerSheet> createState() => _ReadingTimerSheetState();
}

class _ReadingTimerSheetState extends State<_ReadingTimerSheet> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  bool get _running => _stopwatch.isRunning;
  int get _seconds => _stopwatch.elapsed.inSeconds;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _stopwatch.stop();
      _timer?.cancel();
      setState(() {});
      return;
    }
    _stopwatch.start();
    setState(() {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String get _time {
    final hours = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final minutes = (_seconds / 60).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6750E8), Color(0xFFA063ED)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white),
          ),
          const SizedBox(height: 13),
          Text(
            widget.book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            _running ? 'Şimdi sadece hikâyeye odaklan.' : 'Okuma oturumu',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _time,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _toggle,
                icon: Icon(
                  _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(_running ? 'Duraklat' : 'Başlat'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 15,
                  ),
                ),
              ),
              if (_seconds > 0) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    _stopwatch.stop();
                    _timer?.cancel();
                    Navigator.pop(context, minutes);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Bitir'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Shared sheet scaffolding ----------

class _GlassSheet extends StatelessWidget {
  // ignore: unused_element_parameter
  const _GlassSheet({required this.title, required this.child, this.error});
  final String title;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final clamped = mq.copyWith(
      textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2),
    );

    return MediaQuery(
      data: clamped,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: cs.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error!,
                                style: TextStyle(color: cs.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Labeled(this.label, {required this.child, this.requiredMark = false});
  final String label;
  final bool requiredMark;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: .8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              children: requiredMark
                  ? const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Multiline extends StatelessWidget {
  const _Multiline({required this.controller, this.hint});
  final TextEditingController controller;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(hintText: hint),
    );
  }
}

class _DateField extends StatelessWidget {
  // ignore: unused_element_parameter
  const _DateField({required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Future<void> pick() async {
      final now = DateTime.now();
      final initial = _parseYYYYMMDD(controller.text) ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1970),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) controller.text = _formatYYYYMMDD(picked);
    }

    // Depolama YYYY-MM-DD; ekranda gün.ay.yıl gösterilir.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final display = _toDisplay(value.text);
        return InkWell(
          onTap: enabled ? pick : null,
          borderRadius: BorderRadius.circular(18),
          child: InputDecorator(
            isEmpty: display.isEmpty,
            decoration: InputDecoration(
              hintText: 'gg.aa.yyyy',
              enabled: enabled,
              suffixIcon: IconButton(
                onPressed: enabled ? pick : null,
                icon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
            child: Text(
              display,
              style: TextStyle(
                color: enabled
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: .4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  static String _toDisplay(String storage) {
    final d = _parseYYYYMMDD(storage);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  static String _formatYYYYMMDD(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseYYYYMMDD(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    try {
      final parts = t.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}

// ================== SMALL WIDGETS & STYLES ==================

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.color, this.textColor});
  final String text;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? cs.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.url,
    required this.finished,
    this.size = const Size(62, 86),
  });
  final String? url;
  final bool finished;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainer : const Color(0xFFEFFAF4),
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: CachedCover(url: url),
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.isFav, required this.onTap});
  final bool isFav;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isFav ? Colors.redAccent : cs.onSurface.withValues(alpha: .5);
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 170),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFav),
          color: color,
          size: 22,
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: cs.primary),
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 54, color: color);
  }
}

class _GradientProgressBar extends StatelessWidget {
  /*const _GradientProgressBar({
    required this.value,
    this.height = 12,
    this.gradient,
    this.bgColor,
    this.showCenterPercent = false,
    this.centerStyle,
  });*/

  /// Tema duyarlı varsayılan gradyan
  const _GradientProgressBar.adaptive({
    required this.value,
    this.height = 12,
    this.bgColor,
    this.showCenterPercent = false,
    this.centerStyle,
  }) : gradient = null;

  final double value; // 0..1
  final double height;
  final Gradient? gradient;
  final Color? bgColor;
  final bool showCenterPercent;
  final TextStyle? centerStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultGradient = isDark
        ? const LinearGradient(
            colors: [AppTheme.brandPrimaryDark, AppTheme.brandSecondaryDark],
          )
        : const LinearGradient(
            colors: [AppTheme.brandPrimary, AppTheme.brandSecondary],
          );

    final track =
        bgColor ??
        Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: isDark ? .35 : .3);
    return AppProgressBar(
      value: value,
      height: height,
      showLabel: showCenterPercent,
      gradient: gradient ?? defaultGradient,
      trackColor: track,
      labelStyle: centerStyle,
    );
  }
}
