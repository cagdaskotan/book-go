// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../models/gamification_summary.dart';
import '../models/quote.dart';
import '../services/quote_service.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/gamification_service.dart';
import '../services/profile_service.dart';
import '../services/reading_goal_service.dart';
import '../services/reading_pace.dart';
import '../theme/app_theme.dart';
import 'routes.dart';

// Ortak header/nav
import '../widgets/appbar.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/app_toast.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/book_cover.dart';
import '../widgets/mascot.dart';
import '../widgets/recommendations_section.dart';
import '../widgets/navigation.dart';
import '../widgets/yearly_challenge_card.dart';
import '../widgets/home_shelf.dart';
import '../services/notification_service.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _DailyGoalSheet extends StatefulWidget {
  const _DailyGoalSheet({required this.currentGoal});

  final int currentGoal;

  @override
  State<_DailyGoalSheet> createState() => _DailyGoalSheetState();
}

class _DailyGoalSheetState extends State<_DailyGoalSheet> {
  static const _options = [5, 10, 15, 20, 25, 30, 40, 50, 75, 100];
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = _options.contains(widget.currentGoal)
        ? widget.currentGoal
        : _options.reduce(
            (a, b) =>
                (a - widget.currentGoal).abs() < (b - widget.currentGoal).abs()
                ? a
                : b,
          );
  }

  String get _pace {
    if (_selected <= 10) return 'Sakin bir başlangıç';
    if (_selected <= 25) return 'Dengeli bir okuma ritmi';
    if (_selected <= 50) return 'Güçlü bir günlük tempo';
    return 'İddialı bir okuma serisi';
  }

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6750E8), Color(0xFFA06AF5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Günlük okuma hedefin',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Ritmine uyacak bir hedef seç.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF28205F), Color(0xFF6750E8)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Text(
                      '$_selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'sayfa / gün',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _pace,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.military_tech_rounded,
                      color: Color(0xFFFFD98A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Günlük hedef',
                  prefixIcon: Icon(Icons.auto_stories_rounded),
                ),
                items: _options
                    .map(
                      (pages) => DropdownMenuItem(
                        value: pages,
                        child: Text('$pages sayfa'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selected = value);
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Hedefimi kaydet'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yıllık kitap hedefi seçimi (bottom sheet).
class _YearlyGoalSheet extends StatefulWidget {
  const _YearlyGoalSheet({required this.currentGoal});
  final int currentGoal;

  @override
  State<_YearlyGoalSheet> createState() => _YearlyGoalSheetState();
}

class _YearlyGoalSheetState extends State<_YearlyGoalSheet> {
  static const _options = [6, 12, 18, 24, 30, 40, 52, 75, 100];
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = _options.contains(widget.currentGoal)
        ? widget.currentGoal
        : _options.reduce(
            (a, b) =>
                (a - widget.currentGoal).abs() < (b - widget.currentGoal).abs()
                ? a
                : b,
          );
  }

  String get _pace {
    if (_selected <= 12) return 'Ayda bir kitap — keyifli tempo';
    if (_selected <= 24) return 'İki haftada bir kitap';
    if (_selected <= 52) return 'Haftada bir kitap — güçlü ritim';
    return 'İddialı bir okuma yılı';
  }

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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6750E8), Color(0xFFA06AF5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateTime.now().year} okuma hedefin',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          _pace,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Yıllık hedef',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                ),
                items: _options
                    .map(
                      (count) => DropdownMenuItem(
                        value: count,
                        child: Text('$count kitap'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selected = value);
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Hedefimi kaydet'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePageState extends State<HomePage> {
  final _bookService = BookService();
  final _gamificationService = GamificationService();

  List<Book> _books = const [];
  GamificationSummary? _gamification;
  bool _isLoading = false;
  bool _savingGoal = false;
  String? _errorMessage;
  int _yearlyGoal = ReadingGoalService.defaultGoal;

  /// Kahraman kitap için "bu gidişle ... bitiyor" satırı; tempo bilinmiyorsa
  /// null kalır ve satır hiç görünmez.
  String? _heroPaceNote;

  int get _yearlyFinished => ReadingGoalService.finishedInYear(_books);

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait<Object>([
        _bookService.fetchBooks(),
        _gamificationService.fetchSummary(),
        ReadingGoalService.getYearlyGoal(),
      ]);
      final books = results[0] as List<Book>;
      final gamification = results[1] as GamificationSummary;
      final yearlyGoal = results[2] as int;
      if (!mounted) return;
      setState(() {
        _books = books;
        _gamification = gamification;
        _yearlyGoal = yearlyGoal;
      });
      await _refreshHeroPace();
      // Akşamki hatırlatma güncel seriyi bilsin. Arka planda çalışan bir
      // servisimiz yok; metni uygulama her açıldığında tazeliyoruz.
      unawaited(
        NotificationService.instance.refreshStreakReminder(
          currentStreak: gamification.currentStreak,
          readToday: gamification.todayPages > 0,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kahraman kitabın günlük kayıtlarından bitirme tahminini çıkarır.
  ///
  /// Kitap listesi ana ekranda zaten var; tek ek sorgu o kitabın günlüğü.
  /// Tahmin burada temkinli tabanla (takvim günü) hesaplanıyor: ana ekranda
  /// iddialı bir tarih vermek, tutmadığında güveni zedeliyor.
  Future<void> _refreshHeroPace() async {
    final book = _heroBook;
    if (book == null || book.isFinished) {
      if (mounted) setState(() => _heroPaceNote = null);
      return;
    }
    try {
      final logs = await _bookService.fetchLogs(book.id);
      final estimate = estimateFinish(
        book: book,
        pace: computeReadingPace(logs),
      );
      if (!mounted) return;
      final date = estimate?.date;
      setState(() {
        _heroPaceNote = date == null
            ? null
            : 'Bu gidişle ${formatFinishDate(date)} bitiyor';
      });
    } catch (_) {
      if (mounted) setState(() => _heroPaceNote = null);
    }
  }

  void _goTab(HeaderTab tab) {
    final dest = (tab == HeaderTab.home) ? AppRoutes.home : AppRoutes.books;
    if (!mounted) return;
    if (ModalRoute.of(context)?.settings.name != dest) {
      Navigator.pushReplacementNamed(context, dest);
    }
  }

  Future<void> _editDailyGoal() async {
    final current = _gamification;
    if (current == null || _savingGoal) return;

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DailyGoalSheet(currentGoal: current.dailyPageGoal),
    );
    if (result == null || result == current.dailyPageGoal) return;

    setState(() => _savingGoal = true);
    try {
      final updated = await _gamificationService.updateDailyGoal(result);
      if (!mounted) return;
      setState(() => _gamification = updated);
      AppToast.success(
        context,
        'Her gün $result sayfa okumayı hedefliyorsun.',
        title: 'Yeni hedefin hazır',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message, title: 'Hedef güncellenemedi');
    } finally {
      if (mounted) setState(() => _savingGoal = false);
    }
  }

  Future<void> _editYearlyGoal() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _YearlyGoalSheet(currentGoal: _yearlyGoal),
    );
    if (result == null || result == _yearlyGoal) return;
    await ReadingGoalService.setYearlyGoal(result);
    if (!mounted) return;
    setState(() => _yearlyGoal = result);
    AppToast.success(
      context,
      'Bu yıl $result kitap okumayı hedefliyorsun.',
      title: 'Yıllık hedefin güncellendi',
    );
  }

  Future<void> _openDiary(int bookId) async {
    await Navigator.pushNamed(context, AppRoutes.diary, arguments: bookId);
    if (mounted) await _fetchAll();
  }

  Future<void> _openAdd() async {
    final createdId = await showBookAddLauncher(context);
    if (createdId != null && mounted) await _fetchAll();
  }

  Future<void> _openStreakCenter() async {
    final summary = _gamification;
    if (summary == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StreakCenterSheet(summary: summary),
    );
    if (!mounted) return;
    if (action == 'goal') {
      await _editDailyGoal();
    } else if (action == 'insights') {
      await Navigator.pushNamed(context, AppRoutes.insights);
    }
  }

  // ---- türetilmiş veriler (timestamps YOK, id DESC kullan)
  List<Book> get _inProgress =>
      _books
          .where(
            (b) =>
                b.readingStatus == 'reading' &&
                !b.isFinished &&
                b.totalPages > 0,
          )
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
  List<Book> get _recent => [..._books]..sort((a, b) => b.id.compareTo(a.id));

  /// Hero'da gösterilecek kitap: önce okumaya devam edilen en güncel,
  /// yoksa en son eklenen kitap.
  Book? get _heroBook =>
      _inProgress.isNotEmpty ? _inProgress.first : _recent.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        appBar: MainAppBar(
          activeTab: HeaderTab.home,
          showAddButton: false,
          onAddPressed: null,
          onNavSelected: _goTab,
          onToggleTheme: null,
          onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
          onFavorites: () => Navigator.pushNamed(context, AppRoutes.favorites),
          onInsights: () => Navigator.pushNamed(context, AppRoutes.insights),
          onCollections: () =>
              Navigator.pushNamed(context, AppRoutes.collections),
          userName: profileService.visibleName,
          brandColor: const Color(0xFF4F46E5),
          currentStreak: _gamification?.currentStreak,
          dailyGoalMet: _gamification?.dailyGoalMet ?? false,
          onStreakTap: _openStreakCenter,
        ),
        bottomNavigationBar: MainNavigation(
          current: HeaderTab.home,
          onTabSelected: _goTab,
          onAddPressed: _openAdd,
        ),
        body: RefreshIndicator(
          color: cs.primary,
          onRefresh: _fetchAll,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              if (_isLoading && _books.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList.list(
                    children: const [
                      _LoadingSkeleton(),
                      SizedBox(height: 12),
                      _LoadingSkeleton(),
                    ],
                  ),
                )
              else if (_errorMessage != null && _books.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bir sorun oluştu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$_errorMessage',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: .7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchAll,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _WelcomePanel(
                    displayName: profileService.displayName.isEmpty
                        ? null
                        : profileService.displayName,
                    summary: _gamification,
                    heroBook: _heroBook,
                    heroPaceNote: _heroPaceNote,
                    onOpenHero: _heroBook == null
                        ? null
                        : () => _openDiary(_heroBook!.id),
                  ),
                ),

                // Günün alıntısı (welcome panelinin hemen altında)
                const SliverToBoxAdapter(child: _MascotQuoteCard()),

                SliverToBoxAdapter(
                  child: _HomeQuickActions(
                    onCollections: () =>
                        Navigator.pushNamed(context, AppRoutes.collections),
                    onInsights: () =>
                        Navigator.pushNamed(context, AppRoutes.insights),
                    onFavorites: () =>
                        Navigator.pushNamed(context, AppRoutes.favorites),
                  ),
                ),

                // Yıllık okuma hedefi
                SliverToBoxAdapter(
                  child: YearlyChallengeCard(
                    finished: _yearlyFinished,
                    goal: _yearlyGoal,
                    onEditGoal: _editYearlyGoal,
                  ),
                ),

                // Sana özel öneriler
                SliverToBoxAdapter(
                  child: RecommendationsSection(onBookAdded: _fetchAll),
                ),

                // Devam ettiğin kitaplar (yatay kaydırma)
                if (_inProgress.isNotEmpty) ...[
                  _sectionHeader(
                    context,
                    'Kaldığın yerden devam et',
                    icon: Icons.play_circle_fill_rounded,
                  ),
                  if (_inProgress.length == 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: _ContinueCard(
                          book: _inProgress.first,
                          onOpen: () => _openDiary(_inProgress.first.id),
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 148,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _inProgress.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final b = _inProgress[i];
                            return _MiniContinueCard(
                              book: b,
                              onOpen: () => _openDiary(b.id),
                            );
                          },
                        ),
                      ),
                    ),
                ],

                // Son eklenenler
                // Rafı ana ekranın yüzü yap: uygulamayı açan ilk gördüğü
                // şey kendi kitaplığı olsun. Tek gerçek farkımız bu ve
                // üçüncü sekmede saklıydı.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 6),
                    child: HomeShelf(
                      books: _books,
                      onOpenBook: _openDiary,
                      onSeeAll: () =>
                          Navigator.pushNamed(context, AppRoutes.collections),
                    ),
                  ),
                ),

                _sectionHeader(
                  context,
                  'Son eklenenler',
                  icon: Icons.new_releases_rounded,
                ),
                if (_books.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: _SurfaceCard(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const Mascot(mood: MascotMood.encourage, size: 96),
                            const SizedBox(height: 12),
                            Text(
                              'Rafın boş duruyor',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Barkodu okut, künye kendiliğinden dolsun. '
                              'İlk kitabını koyduğunda okuma serin başlar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: .7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openAdd,
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                label: const Text('İlk kitabını ekle'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      bottomNavInset(context),
                    ),
                    sliver: SliverList.separated(
                      itemCount: _recent.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final b = _recent[i];
                        return _BookRowCard(
                          book: b,
                          onTap: () => _openDiary(b.id),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({
    required this.onCollections,
    required this.onInsights,
    required this.onFavorites,
  });

  final VoidCallback onCollections;
  final VoidCallback onInsights;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.auto_stories_rounded,
              label: 'Kitaplığım',
              color: const Color(0xFF7C5CFF),
              onTap: onCollections,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.insights_rounded,
              label: 'İlerlemem',
              color: const Color(0xFF2BAE8A),
              onTap: onInsights,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickAction(
              icon: Icons.favorite_rounded,
              label: 'Favoriler',
              color: const Color(0xFFF06473),
              onTap: onFavorites,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: .18),
                color.withValues(alpha: .05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, Color.lerp(color, Colors.black, .26)!],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .45),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 9),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCenterSheet extends StatelessWidget {
  const _StreakCenterSheet({required this.summary});
  final GamificationSummary summary;

  static const _dayLabels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              const SizedBox(height: 20),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB65D), Color(0xFFF06473)],
                  ),
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF06473).withValues(alpha: .28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                summary.currentStreak == 0
                    ? 'Serini bugün başlat'
                    : '${summary.currentStreak} günlük okuma serisi',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                summary.dailyGoalMet
                    ? 'Bugünün hedefini tamamladın. Ritmin çok iyi.'
                    : '${summary.remainingPages} sayfa daha okuyunca bugün de serin korunacak.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final day = index < summary.week.length
                        ? summary.week[index]
                        : null;
                    final active = (day?.pagesRead ?? 0) > 0;
                    return Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: active
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFFB65D),
                                      Color(0xFFF06473),
                                    ],
                                  )
                                : null,
                            color: active ? null : cs.surface,
                            shape: BoxShape.circle,
                            border: day?.isToday == true
                                ? Border.all(color: cs.primary, width: 2)
                                : Border.all(color: cs.outlineVariant),
                          ),
                          child: Icon(
                            active
                                ? Icons.local_fire_department_rounded
                                : Icons.circle_outlined,
                            color: active ? Colors.white : cs.outline,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _dayLabels[index],
                          style: TextStyle(
                            color: day?.isToday == true
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StreakMetric(
                      value: '${summary.longestStreak}',
                      label: 'en uzun seri',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StreakMetric(
                      value: '${summary.xp}',
                      label: 'toplam XP',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StreakMetric(
                      value: '${summary.totalPages}',
                      label: 'okunan sayfa',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'insights'),
                      icon: const Icon(Icons.insights_rounded),
                      label: const Text('İstatistikler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, 'goal'),
                      icon: const Icon(Icons.track_changes_rounded),
                      label: const Text('Hedefi düzenle'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakMetric extends StatelessWidget {
  const _StreakMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    this.displayName,
    this.summary,
    this.heroBook,
    this.heroPaceNote,
    this.onOpenHero,
  });

  final String? displayName;
  final GamificationSummary? summary;
  final Book? heroBook;
  final String? heroPaceNote;
  final VoidCallback? onOpenHero;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF241C55), Color(0xFF5947C8), Color(0xFF9B63E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6750E8).withValues(alpha: .28),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // İnce, zarif derinlik — yumuşak ışık ve hafif renk geçişi
          Positioned(
            top: -65,
            right: -55,
            child: _glow(200, Colors.white.withValues(alpha: .10)),
          ),
          Positioned(
            bottom: -75,
            left: -65,
            child: _glow(210, const Color(0xFF8C70FF).withValues(alpha: .26)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                      child: Icon(
                        _timeIcon,
                        color: const Color(0xFFFFD98A),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _personalGreeting,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (summary case final value?)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.military_tech_rounded,
                              color: Color(0xFFFFD98A),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Seviye ${value.level}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bugün hangi hikâyede kayboluyoruz?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.9,
                  ),
                ),
                if (heroBook case final book?) ...[
                  const SizedBox(height: 18),
                  _HeroBookCard(
                    book: book,
                    paceNote: heroPaceNote,
                    onOpen: onOpenHero,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }

  IconData get _timeIcon {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_sunny_rounded;
    if (h < 18) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  String get _personalGreeting {
    final name = displayName?.trim().split(RegExp(r'\s+')).firstOrNull;
    return (name == null || name.isEmpty) ? _greeting : '$_greeting, $name';
  }
}

/// Hero içinde kompakt "kaldığın yerden / son eklenen kitap" kartı.
class _HeroBookCard extends StatelessWidget {
  const _HeroBookCard({required this.book, this.paceNote, this.onOpen});
  final Book book;
  final String? paceNote;
  final VoidCallback? onOpen;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).round();
    final label = book.isFinished
        ? 'TAMAMLADIN'
        : (book.readingStatus == 'reading' ? 'KALDIĞIN YERDEN' : 'SON EKLENEN');

    return Material(
      color: Colors.white.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  width: 46,
                  height: 64,
                  color: Colors.white.withValues(alpha: .14),
                  child: CachedCover(
                    url: book.coverUrl,
                    iconColor: Colors.white70,
                    iconSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .65),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '%$pct',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (paceNote case final note?) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: .7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                book.isFinished
                    ? Icons.check_circle_rounded
                    : Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Bölüm başlığı ----------
SliverToBoxAdapter _sectionHeader(
  BuildContext context,
  String title, {
  required IconData icon,
}) {
  final cs = Theme.of(context).colorScheme;
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: cs.primary, size: 19),
          ),
          const SizedBox(width: 11),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              fontSize: 17.5,
              letterSpacing: -.3,
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------- Mini kartlar / listeler ----------
class _BookRowCard extends StatelessWidget {
  const _BookRowCard({required this.book, required this.onTap});
  final Book book;
  final VoidCallback onTap;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: _SurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const SizedBox(width: 2),
            _CoverThumb(url: book.coverUrl, finished: book.isFinished),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (book.author == null || book.author!.trim().isEmpty)
                          ? 'Yazar bilgisi yok'
                          : book.author!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: .7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GradientProgressBar.adaptive(
                      value: _progress,
                      height: 12,
                      bgColor: cs.outlineVariant.withValues(alpha: .35),
                      showCenterPercent: true,
                      centerStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              book.isFinished ? Icons.flag : Icons.chevron_right_rounded,
              color: book.isFinished
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: .5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.book, required this.onOpen});
  final Book book;
  final VoidCallback onOpen;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: _SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CoverThumb.large(url: book.coverUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GradientProgressBar.adaptive(
                    value: _progress,
                    height: 20,
                    bgColor: cs.outlineVariant.withValues(alpha: .35),
                    showCenterPercent: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${book.currentPage}/${book.totalPages} sayfa',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.play_arrow_rounded, size: 17),
                        label: const Text('Devam'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }
}

// ---------- Mini "devam et" kartı (yatay liste için) ----------
class _MiniContinueCard extends StatelessWidget {
  const _MiniContinueCard({required this.book, required this.onOpen});
  final Book book;
  final VoidCallback onOpen;

  double get _progress => book.totalPages == 0
      ? 0
      : (book.currentPage / book.totalPages).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 280,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: _SurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CoverThumb(url: book.coverUrl, finished: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GradientProgressBar.adaptive(
                      value: _progress,
                      height: 10,
                      bgColor: cs.outlineVariant.withValues(alpha: .35),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${book.currentPage}/${book.totalPages} sayfa',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.play_circle_fill_rounded,
                          color: cs.primary,
                          size: 26,
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
    );
  }
}

/// Günün alıntısı.
///
/// Önce kullanıcının kendi defterine bakıyor: insanın kendi altını çizdiği
/// cümleyi görmesi, hazır bir ünlü sözden çok daha kıymetli. Defter boşsa
/// aşağıdaki seçkiye düşüyor ve karta dokunmak defteri açıyor.
class _MascotQuoteCard extends StatefulWidget {
  const _MascotQuoteCard();

  @override
  State<_MascotQuoteCard> createState() => _MascotQuoteCardState();
}

class _MascotQuoteCardState extends State<_MascotQuoteCard> {
  Quote? _mine;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final quotes = await QuoteService().fetchQuotes();
      if (!mounted) return;
      setState(() => _mine = pickDailyQuote(quotes, DateTime.now()));
    } catch (_) {
      // Defter okunamazsa hazır seçkiyle devam; kart boş kalmasın.
    }
  }

  static const _quotes = <(String, String)>[
    (
      'Bir kitap, içimizdeki donmuş denize indirilmiş bir baltadır.',
      'Franz Kafka',
    ),
    (
      'Cennetin bir tür kütüphane olacağını hep düşlemişimdir.',
      'Jorge Luis Borges',
    ),
    ('Okumak, zihnin egzersizidir.', 'Joseph Addison'),
    (
      'Bizi uzak diyarlara götüren, kitap kadar güçlü bir gemi yoktur.',
      'Emily Dickinson',
    ),
    ('Kitaplar, eşsiz ve taşınabilir bir sihirdir.', 'Stephen King'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final fallback = _quotes[dayOfYear % _quotes.length];

    final mine = _mine;
    final quote = mine?.text ?? fallback.$1;
    final author = mine == null
        ? fallback.$2
        : [
            mine.bookTitle ?? 'Defterimden',
            if (mine.page != null) 's. ${mine.page}',
          ].join(' · ');
    // Kendi alıntısı varsa başlık da onu söylesin.
    final label = mine == null ? 'GÜNÜN ALINTISI' : 'DEFTERİNDEN';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.quotes),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF20243A), Color(0xFF29213E)]
                  : const [Color(0xFFF2EEFF), Color(0xFFFFF4EA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary.withValues(alpha: .14)),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: .08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(
                width: 106,
                child: Mascot(mood: MascotMood.reading, size: 106),
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -7,
                      bottom: 22,
                      child: Transform.rotate(
                        angle: .78,
                        child: Container(
                          width: 15,
                          height: 15,
                          color: isDark
                              ? const Color(0xFF27223D)
                              : const Color(0xFFFCF3EF),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? .06 : .6,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '“$quote”',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '— $author',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
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
      ),
    );
  }
}

// ---------- Ortak yapı taşları ----------
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

class _GradientProgressBar extends StatelessWidget {
  /*const _GradientProgressBar({
    required this.value,
    this.height = 12,
    this.gradient,
    this.bgColor,
    this.showCenterPercent = false,
    this.centerStyle,
  });*/

  /// Light/Dark’a göre otomatik renk seçen kurucu
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

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bar({double h = 14, double w = double.infinity}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 86,
            decoration: BoxDecoration(
              color: cs.outlineVariant.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                bar(h: 16),
                const SizedBox(height: 8),
                bar(w: 160),
                const SizedBox(height: 14),
                bar(h: 10),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: bar(w: 100, h: 10)),
                    const SizedBox(width: 8),
                    bar(w: 80, h: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Kapak görseli
class _CoverThumb extends StatelessWidget {
  // İki boy var ve ölçüler çağrı yerinden verilmiyor; o yüzden her boyut
  // kendi kurucusunda sabit.
  const _CoverThumb({required this.url, required this.finished})
    : showBadge = true,
      w = 62,
      h = 86;

  const _CoverThumb.large({required this.url})
    : finished = false,
      showBadge = false,
      w = 80,
      h = 112;

  final String? url;
  final bool finished;
  final bool showBadge;
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: w,
        height: h,
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
