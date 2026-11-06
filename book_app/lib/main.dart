import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_database.dart';
import 'data/settings_store.dart';
import 'pages/home.dart';
import 'pages/routes.dart'; // AppRoutes + AppRouter
import 'services/ad_route_observer.dart';
import 'services/ad_service.dart';
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
  // Reklam SDK'sı — arka planda başlar, ilk kareyi bloklamaz.
  unawaited(AdService.instance.initialize());

  runApp(const BookApp());
}

class BookApp extends StatefulWidget {
  const BookApp({super.key});

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
      title: 'Mobil Kütüphanem',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.mode, // toggle ile değişir

      navigatorObservers: [AdRouteObserver()],

      // Giriş ekranı yok: uygulama doğrudan kitaplığa açılır.
      initialRoute: AppRoutes.home,
      routes: {AppRoutes.home: (_) => const HomePage()},

      // /diary ve parametreli sayfalar için:
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
