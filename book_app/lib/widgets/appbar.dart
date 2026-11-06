import 'package:flutter/material.dart';

import '../services/profile_service.dart';
import '../services/plus_manager.dart';
import '../theme/app_theme.dart';
import '../pages/routes.dart';

enum HeaderTab { home, books, favorites }

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({
    super.key,
    required this.activeTab,
    this.onNavSelected,
    this.onToggleTheme,
    this.onProfile,
    this.onFavorites,
    this.onInsights,
    this.onCollections,
    this.showAddButton = false,
    this.onAddPressed,
    this.userName,
    this.brandColor,
    this.currentStreak,
    this.dailyGoalMet = false,
    this.onStreakTap,
    this.titleOverride,
    this.subtitleOverride,
  });

  final HeaderTab activeTab;
  final String? titleOverride;
  final String? subtitleOverride;
  final void Function(HeaderTab tab)? onNavSelected;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onProfile;
  final VoidCallback? onFavorites;
  final VoidCallback? onInsights;
  final VoidCallback? onCollections;
  final bool showAddButton;
  final VoidCallback? onAddPressed;
  final String? userName;
  final Color? brandColor;
  final int? currentStreak;
  final bool dailyGoalMet;
  final VoidCallback? onStreakTap;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  String get _title =>
      titleOverride ??
      switch (activeTab) {
        HeaderTab.home => 'Mobil Kütüphanem',
        HeaderTab.books => 'Kütüphanem',
        HeaderTab.favorites => 'Favorilerim',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final suppliedName = userName?.trim();
    final hasRealSuppliedName =
        suppliedName != null &&
        suppliedName.isNotEmpty &&
        suppliedName != 'Kullanıcı' &&
        suppliedName != 'Okur';
    final resolvedName = hasRealSuppliedName
        ? suppliedName
        : profileService.visibleName;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 14,
      toolbarHeight: 66,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          if (activeTab == HeaderTab.home)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _HeaderStreak(
                  streak: currentStreak ?? 0,
                  goalMet: dailyGoalMet,
                  onTap: onStreakTap,
                ),
              ),
            )
          else ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.3,
                    ),
                  ),
                  Text(
                    subtitleOverride ??
                        (activeTab == HeaderTab.books
                            ? 'Tüm kitapların'
                            : 'Sevdiklerin'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showAddButton)
            _AppBarAction(
              tooltip: 'Kitap ekle',
              icon: Icons.add_rounded,
              onTap: onAddPressed,
            ),
          _AppBarAction(
            tooltip: 'Temayı değiştir',
            icon: theme.brightness == Brightness.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            onTap: onToggleTheme ?? themeController.toggle,
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: 'Hesap',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 12),
            elevation: 10,
            color: cs.surface,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black.withValues(alpha: .4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: .6)),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 6),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Text(
                _initials(resolvedName),
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: _AccountSummary(
                  name: resolvedName,
                  initials: _initials(resolvedName),
                ),
              ),
              const PopupMenuDivider(),
              if (kPlusEnabled)
                PopupMenuItem(
                  value: _MenuAction.plus,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Color(0xFFE0A93B),
                    ),
                    title: Text(
                      'Plus',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              const PopupMenuItem(
                value: _MenuAction.recommendations,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_awesome_rounded),
                  title: Text('Sana Özel'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.journal,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.menu_book_rounded),
                  title: Text('Alıntı Defterim'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _MenuAction.profile,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline_rounded),
                  title: Text('Profil'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.insights,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.insights_rounded),
                  title: Text('İstatistikler'),
                ),
              ),
              const PopupMenuItem(
                value: _MenuAction.favorites,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.favorite_outline_rounded),
                  title: Text('Favorilerim'),
                ),
              ),
            ],
            onSelected: (action) {
              switch (action) {
                case _MenuAction.plus:
                  Navigator.pushNamed(context, AppRoutes.plus);
                case _MenuAction.recommendations:
                  Navigator.pushNamed(context, AppRoutes.recommendations);
                case _MenuAction.journal:
                  Navigator.pushNamed(context, AppRoutes.journal);
                case _MenuAction.profile:
                  onProfile?.call();
                case _MenuAction.favorites:
                  onFavorites?.call();
                case _MenuAction.insights:
                  onInsights?.call();
                case _MenuAction.collections:
                  onCollections?.call();
              }
            },
          ),
        ],
      ),
    );
  }

  String _initials(String resolvedName) {
    final source = resolvedName.trim();
    if (source.isEmpty) return profileService.initials;
    return source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
  }
}

class _HeaderStreak extends StatelessWidget {
  const _HeaderStreak({
    required this.streak,
    required this.goalMet,
    required this.onTap,
  });

  final int streak;
  final bool goalMet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: goalMet
                  ? const [Color(0xFF1FA980), Color(0xFF50C89E)]
                  : const [Color(0xFFFFA45D), Color(0xFFF06473)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:
                    (goalMet
                            ? const Color(0xFF1FA980)
                            : const Color(0xFFF06473))
                        .withValues(alpha: .24),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  goalMet
                      ? Icons.check_rounded
                      : Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streak == 0 ? 'Serini başlat' : '$streak günlük seri',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    goalMet ? 'Bugün tamamlandı' : 'Ritmini koru',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontWeight: FontWeight.w700,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.name, required this.initials});

  final String name;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 234,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
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
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      color: cs.onSurface,
                    ),
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

enum _MenuAction {
  plus,
  recommendations,
  journal,
  profile,
  insights,
  collections,
  favorites,
}
