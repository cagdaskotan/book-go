import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/book.dart';
import '../models/gamification_summary.dart';
import '../services/api_exception.dart';
import '../services/book_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_progress_bar.dart';
import '../widgets/appbar.dart';
import '../services/stats_service.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/navigation.dart';
import '../widgets/reading_heatmap.dart';
import 'routes.dart';
import 'year_wrapped.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final _gamification = GamificationService();
  final _books = BookService();
  final _stats = StatsService();

  GamificationSummary? _summary;
  List<Book> _library = const [];
  Map<String, int> _daily = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        _gamification.fetchSummary(),
        _books.fetchBooks(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = result[0] as GamificationSummary;
        _library = result[1] as List<Book>;
      });
      // Isı haritası verisi (başarısız olursa sessizce boş kalır)
      try {
        final daily = await _stats.fetchDailyActivity();
        if (mounted) setState(() => _daily = daily);
      } catch (_) {}
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'İstatistiklerin şu anda yüklenemedi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTab(HeaderTab tab) {
    Navigator.pushReplacementNamed(
      context,
      tab == HeaderTab.home ? AppRoutes.home : AppRoutes.books,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: MainAppBar(
        activeTab: HeaderTab.home,
        userName: 'Kullanıcı',
        onNavSelected: _goTab,
        onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
        onFavorites: () => Navigator.pushNamed(context, AppRoutes.favorites),
        onCollections: () =>
            Navigator.pushNamed(context, AppRoutes.collections),
      ),
      bottomNavigationBar: MainNavigation(
        current: null,
        allowCurrentSelection: true,
        onTabSelected: _goTab,
        onAddPressed: () => showBookAddLauncher(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _summary == null
          ? _InsightsError(
              message: _error ?? 'İstatistikler bulunamadı.',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 18, 16, bottomNavInset(context)),
                children: [
                  _LevelHero(summary: _summary!),
                  const SizedBox(height: 14),
                  _YearWrappedBanner(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => YearWrappedPage(
                          books: _library,
                          summary: _summary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    title: 'Okuma istatistiklerin',
                    subtitle: 'Küçük adımlarının büyük resmi',
                  ),
                  const SizedBox(height: 10),
                  _StatsGrid(summary: _summary!, books: _library),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    title: 'Bu haftanın ritmi',
                    subtitle: 'Her dolu gün serinin bir parçası',
                  ),
                  const SizedBox(height: 10),
                  _WeeklyChart(summary: _summary!),
                  const SizedBox(height: 22),
                  _SectionTitle(
                    title: '${DateTime.now().year} ısı haritan',
                    subtitle: 'Yıl boyu hangi günler okudun',
                  ),
                  const SizedBox(height: 10),
                  ReadingHeatmap(year: DateTime.now().year, data: _daily),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    title: 'Başarımlar',
                    subtitle: 'Okudukça yeni rozetler açılır',
                  ),
                  const SizedBox(height: 10),
                  ..._achievements.map(
                    (achievement) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _AchievementTile(
                        achievement: achievement,
                        summary: _summary!,
                        books: _library,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _shareStats,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('İstatistiklerini paylaş'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _shareStats() async {
    final s = _summary;
    if (s == null) return;
    final unlocked = _achievements.where((a) => a.unlocked(s, _library)).length;
    final text =
        '''
📚 Bilge · okuma istatistiklerim
🏆 Seviye ${s.level} — ${levelTitle(s.level)}
✨ ${s.xp} XP biriktirdim
🔥 En uzun okuma serim: ${s.longestStreak} gün
📖 Toplam ${s.totalPages} sayfa okudum
✅ ${s.finishedBooks} kitap bitirdim
🎖️ $unlocked/${_achievements.length} başarım açıldı''';
    try {
      await Share.share(text, subject: 'Okuma istatistiklerim');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşım şu anda yapılamadı.')),
      );
    }
  }

  List<_Achievement> get _achievements => const [
    _Achievement(
      title: 'İlk sayfa',
      description: 'İlk okuma gününü kaydet',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF7C6CF2),
      test: 'active_days',
      target: 1,
    ),
    _Achievement(
      title: 'İlk zafer',
      description: 'İlk kitabını bitir',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFF59E0B),
      test: 'finished_books',
      target: 1,
    ),
    _Achievement(
      title: 'Isınıyoruz',
      description: '3 günlük okuma serisine ulaş',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFFB923C),
      test: 'streak',
      target: 3,
    ),
    _Achievement(
      title: 'Ritim ustası',
      description: '7 günlük okuma serisine ulaş',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFF97373),
      test: 'streak',
      target: 7,
    ),
    _Achievement(
      title: 'Durdurulamaz',
      description: '30 günlük okuma serisine ulaş',
      icon: Icons.bolt_rounded,
      color: Color(0xFFEF4444),
      test: 'streak',
      target: 30,
    ),
    _Achievement(
      title: 'Kitap kurdu',
      description: '5 kitabı tamamla',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFFFFA65B),
      test: 'finished_books',
      target: 5,
    ),
    _Achievement(
      title: 'Raf devirici',
      description: '10 kitabı tamamla',
      icon: Icons.military_tech_rounded,
      color: Color(0xFFA855F7),
      test: 'finished_books',
      target: 10,
    ),
    _Achievement(
      title: 'Bin sayfa kulübü',
      description: 'Toplam 1.000 sayfa oku',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF2BAE8A),
      test: 'total_pages',
      target: 1000,
    ),
    _Achievement(
      title: 'Sayfa maratoncusu',
      description: 'Toplam 5.000 sayfa oku',
      icon: Icons.directions_run_rounded,
      color: Color(0xFF0EA5E9),
      test: 'total_pages',
      target: 5000,
    ),
    _Achievement(
      title: 'Koleksiyoncu',
      description: 'Kütüphanene 10 kitap ekle',
      icon: Icons.collections_bookmark_rounded,
      color: Color(0xFF4D8DF7),
      test: 'library',
      target: 10,
    ),
    _Achievement(
      title: 'Yükselen yıldız',
      description: '5. seviyeye ulaş',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF8B5CF6),
      test: 'level',
      target: 5,
    ),
  ];
}

/// Seviyeye göre okur unvanı.
String levelTitle(int level) {
  if (level >= 20) return 'Efsane Okur';
  if (level >= 15) return 'Bilge Kitap Kurdu';
  if (level >= 10) return 'Usta Okur';
  if (level >= 7) return 'Kitap Kâşifi';
  if (level >= 5) return 'Sayfa Avcısı';
  if (level >= 3) return 'Hevesli Okur';
  return 'Çaylak Okur';
}

class _InsightsError extends StatelessWidget {
  const _InsightsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_rounded, size: 48),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelHero extends StatelessWidget {
  const _LevelHero({required this.summary});
  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4B3CB1), Color(0xFF8A5CF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 25,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seviye ${summary.level} • ${summary.xp} XP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      levelTitle(summary.level),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                        letterSpacing: -.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppProgressBar(
            value: summary.levelProgressRatio,
            height: 14,
            showLabel: false,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFBE69), Color(0xFFFF7B72)],
            ),
            trackColor: Colors.white24,
          ),
          const SizedBox(height: 7),
          Text(
            'Sonraki seviyeye ${500 - summary.levelProgress} XP',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary, required this.books});
  final GamificationSummary summary;
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final boxes = [
      _StatBox(
        value: '${summary.totalPages}',
        label: 'okunan sayfa',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF6750E8),
      ),
      _StatBox(
        value: '${summary.finishedBooks}',
        label: 'biten kitap',
        icon: Icons.flag_rounded,
        color: const Color(0xFFF97373),
      ),
      _StatBox(
        value: '${summary.activeDays}',
        label: 'aktif gün',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2BAE8A),
      ),
      _StatBox(
        value: '${books.length}',
        label: 'kütüphanede',
        icon: Icons.collections_bookmark_rounded,
        color: const Color(0xFFFFA65B),
      ),
    ];

    // İçeriğe göre boyutlanan 2x2 düzen (sabit oran yok → taşma/boşluk yok).
    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 9),
          Expanded(child: b),
        ],
      ),
    );

    return Column(
      children: [
        row(boxes[0], boxes[1]),
        const SizedBox(height: 9),
        row(boxes[2], boxes[3]),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 9),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.summary});
  final GamificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxPages = summary.week.fold<int>(
      summary.dailyPageGoal,
      (max, day) => day.pagesRead > max ? day.pagesRead : max,
    );
    const labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    return Container(
      height: 242,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.surface, cs.primary.withValues(alpha: .07)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.primary.withValues(alpha: .14)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF75E6C3), Color(0xFF6750E8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.equalizer_rounded, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Haftalık okuma ritmin',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Hedef: günde ${summary.dailyPageGoal} sayfa',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${summary.week.fold<int>(0, (sum, day) => sum + day.pagesRead)} sayfa',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(7, (index) {
                final day = index < summary.week.length
                    ? summary.week[index]
                    : null;
                final pages = day?.pagesRead ?? 0;
                final ratio = (pages / maxPages).clamp(0.0, 1.0);
                final goalMet = pages >= summary.dailyPageGoal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 18,
                          child: Text(
                            '$pages',
                            style: TextStyle(
                              color: goalMet ? cs.primary : cs.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  width: 24,
                                  height:
                                      8 + (constraints.maxHeight - 8) * ratio,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: goalMet
                                          ? const [
                                              Color(0xFF75E6C3),
                                              Color(0xFF2BAE8A),
                                            ]
                                          : const [
                                              Color(0xFFC7A5FF),
                                              Color(0xFF6750E8),
                                            ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (goalMet
                                                    ? const Color(0xFF75E6C3)
                                                    : const Color(0xFF8B5CF6))
                                                .withValues(alpha: .22),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 25,
                          height: 25,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: day?.isToday == true
                                ? cs.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: day?.isToday == true
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Achievement {
  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.test,
    required this.target,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String test;
  final int target;

  int current(GamificationSummary summary, List<Book> books) => switch (test) {
    'active_days' => summary.activeDays,
    'finished_books' => summary.finishedBooks,
    'streak' => summary.longestStreak,
    'total_pages' => summary.totalPages,
    'library' => books.length,
    'level' => summary.level,
    _ => 0,
  };

  bool unlocked(GamificationSummary summary, List<Book> books) =>
      current(summary, books) >= target;
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.summary,
    required this.books,
  });
  final _Achievement achievement;
  final GamificationSummary summary;
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = achievement.current(summary, books);
    final unlocked = current >= achievement.target;
    final ratio = (current / achievement.target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: unlocked
            ? achievement.color.withValues(alpha: .09)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: unlocked
              ? achievement.color.withValues(alpha: .28)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked ? achievement.color : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline_rounded,
              color: unlocked ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            color: achievement.color,
                            backgroundColor: cs.outlineVariant.withValues(
                              alpha: .4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$current / ${achievement.target}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (unlocked) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: achievement.color),
          ],
        ],
      ),
    );
  }
}

class _YearWrappedBanner extends StatelessWidget {
  const _YearWrappedBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEB5E8C), Color(0xFFA855F7), Color(0xFF6750E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA855F7).withValues(alpha: .3),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$year Okuma Karnem',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Yılını özetleyen renkli kartlarına göz at',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
