import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama teması (light + dark) ve basit bir tema kontrolcüsü.
/// Light: mevcut yeşil kimlik.
/// Dark: koyu gri + mor (indigo/violet) paleti.
class AppTheme {
  AppTheme._();

  // Mevcut kimlik renkleri (başka dosyalarda kullanılan sabitler)
  static const Color primaryGreen = Color(0xFF6750E8);
  static const Color secondaryGreen = Color(0xFF8B5CF6);
  static const Color darkGreen = Color(0xFF352A78);
  static const Color accentOrange = Color(0xFFE9785D);
  static const Color background = Color(0xFFF7F6FC);

  // Dark mod için brand tonları
  static const Color brandIndigo = Color(0xFF7567F8);
  static const Color brandViolet = Color(0xFFA06AF5);

  // ---------------------- LIGHT THEME ----------------------
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
      primary: primaryGreen,
      secondary: accentOrange,
      surface: background,
    );

    final textTheme = GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      snackBarTheme: _snackBarTheme(textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkGreen,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: darkGreen,
        ),
      ),

      // NOTE: SDK'nın beklediği tip: CardThemeData
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      // NOTE: SDK'nız DialogThemeData bekliyor
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        showDragHandle: false,
        dragHandleColor: colorScheme.onSurface.withValues(alpha: .35),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: background),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: darkGreen),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: darkGreen.withValues(alpha: 0.6),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: .12),
        surfaceTintColor: Colors.transparent,
        height: 64,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: .6),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: .7),
          );
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.outlineVariant.withValues(alpha: .6),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }

  // ---------------------- DARK THEME ----------------------
  static ThemeData dark() {
    // koyu gri + mor
    const surface = Color(0xFF171927);
    const surfaceHigh = Color(0xFF0F1120);
    const outline = Color(0xFF383C55);

    final cs = const ColorScheme(
      brightness: Brightness.dark,
      primary: brandIndigo,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF302B66),
      onPrimaryContainer: Color(0xFFD9D6FF),
      secondary: brandViolet,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF3A2C5C),
      onSecondaryContainer: Color(0xFFEADBFF),
      error: Color(0xFFF87171),
      onError: Colors.black,
      errorContainer: Color(0xFF5A2A2C),
      onErrorContainer: Color(0xFFFFD9DA),
      surface: surface,
      onSurface: Color(0xFFF1F0F8),
      surfaceContainerHighest: surfaceHigh,
      surfaceContainerHigh: Color(0xFF202334),
      surfaceContainer: Color(0xFF1B1E2E),
      surfaceContainerLow: Color(0xFF25283A),
      surfaceContainerLowest: Color(0xFF0A0C17),
      outline: outline,
      outlineVariant: Color(0xFF2D3147),
      shadow: Colors.black,
      scrim: Colors.black87,
      tertiary: Color(0xFF34D399),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF124C3C),
      onTertiaryContainer: Color(0xFFB6F5E1),
      inverseSurface: Color(0xFFF8FAFC),
      onInverseSurface: Color(0xFF0F172A),
      inversePrimary: Color(0xFFADB3FF),
      surfaceTint: brandIndigo,
    );

    final textTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: cs.surfaceContainerHighest,
      snackBarTheme: _snackBarTheme(textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),

      // CardThemeData (SDK’nız bunu bekliyor)
      cardTheme: CardThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),

      // DialogThemeData
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cs.outline),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        showDragHandle: false,
        dragHandleColor: cs.onSurface.withValues(alpha: .35),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: cs.onSurface.withValues(alpha: .8),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: cs.onSurface.withValues(alpha: .55),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withValues(alpha: .18),
        surfaceTintColor: Colors.transparent,
        height: 64,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: .7),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: .8),
          );
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.outlineVariant.withValues(alpha: .4),
      ),

      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
    );
  }

  static SnackBarThemeData _snackBarTheme(TextTheme textTheme) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF171B34),
      elevation: 12,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      actionTextColor: const Color(0xFFB9A7FF),
    );
  }
}

/// Basit global tema kontrolcüsü (toggle için).
/// Seçim shared_preferences ile saklanır; uygulama açılışında [load] çağrılır.
class ThemeController extends ChangeNotifier {
  static const _prefKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Tercih okunamazsa sistem temasıyla devam et.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, switch (_mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {}
  }

  void toggle() {
    _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _persist();
  }

  void set(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    _persist();
  }
}

// Kolay kullanım için singleton (Provider/Riverpod yoksa iş görür)
final themeController = ThemeController();
