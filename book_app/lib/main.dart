import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_database.dart';
import 'data/settings_store.dart';
import 'pages/home.dart';
import 'pages/onboarding.dart';
import 'pages/routes.dart'; // AppRoutes + AppRouter
import 'services/first_run.dart';
import 'services/notification_service.dart';
import 'services/plus_manager.dart';
import 'services/profile_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kitaplık tamamen cihazda: veritabanını aç, şema yoksa kur.
  await AppDatabase.instance.db;
  await SettingsStore.migrateLegacyPrefs();

  await profileService.load();
  await themeController.load();
  await plusManager.load();
  await NotificationService.instance.initialize();

  final onboarded = await FirstRun.isDone();

  runApp(BookApp(showOnboarding: !onboarded));
}

class BookApp extends StatefulWidget {
  const BookApp({super.key, this.showOnboarding = false});

  /// İlk açılışta karşılama akışı gösterilir.
  final bool showOnboarding;

  @override
  State<BookApp> createState() => _BookAppState();
}

class _BookAppState extends State<BookApp> {
  @override
  void initState() {
    super.initState();
    // Tema değişimlerini dinle
    themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bilge',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.mode, // toggle ile değişir
      // Giriş ekranı yok: ilk açılışta karşılama, sonrasında doğrudan kitaplık.
      initialRoute: widget.showOnboarding
          ? AppRoutes.onboarding
          : AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomePage(),
        AppRoutes.onboarding: (_) => const OnboardingPage(),
      },

      // /diary ve parametreli sayfalar için:
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
