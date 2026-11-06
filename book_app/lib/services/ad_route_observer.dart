import 'package:flutter/widgets.dart';

import 'ad_service.dart';

/// Yalnızca *ileri* sayfa geçişlerini (push) sayar ve reklam yöneticisini
/// tetikler. Geri gitme (pop) reklam üretmez — kullanıcı akışı kesilmesin.
///
/// Tam-ekran diyalog rotaları ve isimsiz/geçici rotalar sayılmaz.
class AdRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!_counts(route)) return;
    // İlk açılıştaki kök rotada previousRoute null olur; onu saymayalım.
    if (previousRoute == null) return;
    AdService.instance.onForwardNavigation();
  }

  bool _counts(Route<dynamic> route) {
    if (route is! PageRoute) return false;
    // Modal/bottom-sheet gibi geçici rotalar zaten PageRoute değil.
    return true;
  }
}
