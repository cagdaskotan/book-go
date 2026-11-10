// lib/pages/routes.dart
import 'package:flutter/material.dart';
import 'home.dart';
import 'diary.dart';
import 'favorites.dart';
import 'books.dart'; // ⬅️ yeni
import 'profile.dart'; // profil sayfan varsa
import 'insights.dart';
import 'collections.dart';
import 'recommendations_page.dart';
import 'plus_screen.dart';
import 'journal_gallery.dart';
import 'onboarding.dart';

class AppRoutes {
  AppRoutes._();
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String books = '/books'; // ⬅️ yeni
  static const String diary = '/diary';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String insights = '/insights';
  static const String collections = '/collections';
  static const String recommendations = '/recommendations';
  static const String plus = '/plus';
  static const String journal = '/journal';
}

int? _extractBookId(Object? a) {
  if (a == null) return null;
  if (a is int) return a;
  if (a is String) return int.tryParse(a);
  if (a is Map) {
    final v = a['id'] ?? a['bookId'] ?? a['book_id'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
  }
  return null;
}

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingPage());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case AppRoutes.books: // ⬅️ yeni
        return MaterialPageRoute(builder: (_) => const BooksPage());
      case AppRoutes.favorites:
        return MaterialPageRoute(builder: (_) => const FavoritesPage());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case AppRoutes.insights:
        return MaterialPageRoute(builder: (_) => const InsightsPage());
      case AppRoutes.collections:
        return MaterialPageRoute(builder: (_) => const CollectionsPage());
      case AppRoutes.recommendations:
        return MaterialPageRoute(builder: (_) => const RecommendationsPage());
      case AppRoutes.journal:
        return MaterialPageRoute(builder: (_) => const JournalGalleryPage());
      case AppRoutes.plus:
        return MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PlusScreen(),
        );
      case AppRoutes.diary:
        final bookId = _extractBookId(settings.arguments);
        if (bookId == null) {
          return MaterialPageRoute(builder: (_) => const _BadArgs());
        }
        // Kitap açılış animasyonu Hero uçuşuna bağlı ve Hero, rotanın
        // geçiş süresini kullanır. Varsayılan 300 ms'de sayfa çevirme
        // penceresi ~80 ms'ye düşüyor; göz bunu animasyon olarak bile
        // algılamıyor. Açılışa nefes alacak süre veriyoruz; geri dönüş
        // daha kısa, çünkü orada anlatılacak bir şey yok.
        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 950),
          reverseTransitionDuration: const Duration(milliseconds: 620),
          pageBuilder: (_, __, ___) => DiaryPage(bookId: bookId),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              // Sayfa, kitap kapanıp yerine oturduktan sonra belirsin.
              curve: const Interval(.72, 1, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
    }
    return null;
  }
}

class _BadArgs extends StatelessWidget {
  const _BadArgs();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Geçersiz yönlendirme parametresi')),
    );
  }
}
