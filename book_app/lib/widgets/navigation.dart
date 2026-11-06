import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appbar.dart';

/// Süzülen nav bar'ın kapladığı alan + cihazın alt güvenli boşluğu.
/// Scroll içeriklerinin alt padding'inde kullanılır ki son öğeler bar
/// arkasında kalmasın (gesture-nav telefonlarda da).
double bottomNavInset(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom + 104;

class MainNavigation extends StatelessWidget {
  const MainNavigation({
    super.key,
    required this.current,
    required this.onTabSelected,
    required this.onAddPressed,
    this.allowCurrentSelection = false,
  });

  /// Aktif sekme. Ana sayfa/Kütüphanem dışındaki sayfalarda `null` verilirse
  /// hiçbir nav butonu aktif görünmez.
  final HeaderTab? current;
  final void Function(HeaderTab tab) onTabSelected;
  final VoidCallback onAddPressed;
  final bool allowCurrentSelection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _buildBar(context, cs);
  }

  Widget _buildBar(BuildContext context, ColorScheme cs) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Container(
        height: 82,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: cs.primary.withValues(alpha: .10)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E245D).withValues(alpha: .18),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                selected: current == HeaderTab.home,
                icon: Icons.home_rounded,
                label: 'Ana sayfa',
                onTap: () => _select(HeaderTab.home),
              ),
            ),
            SizedBox(
              width: 88,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Yeni kitap ekle',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onAddPressed();
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6750E8), Color(0xFFA264F4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: cs.surface, width: 5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6750E8,
                              ).withValues(alpha: .35),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _NavItem(
                selected: current == HeaderTab.books,
                icon: Icons.auto_stories_rounded,
                label: 'Kütüphanem',
                onTap: () => _select(HeaderTab.books),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(HeaderTab tab) {
    if (tab == current && !allowCurrentSelection) return;
    HapticFeedback.selectionClick();
    onTabSelected(tab);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: .11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
