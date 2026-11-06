import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';

/// Kitabı internette aratır (mağaza bağımsız Google araması).
/// Kullanıcı kendi tercih ettiği mağazadan satın alır — deep-link/affiliate yok.
Future<void> searchBookOnline(
  BuildContext context,
  String title, {
  String? author,
}) async {
  final terms = [
    title.trim(),
    (author ?? '').trim(),
  ].where((e) => e.isNotEmpty).join(' ');
  if (terms.isEmpty) return;

  final uri = Uri.parse(
    'https://www.google.com/search?q=${Uri.encodeQueryComponent(terms)}',
  );

  // Cihaza göre değişebildiği için birkaç yöntemi sırayla dene:
  // harici tarayıcı → varsayılan → uygulama içi Chrome sekmesi.
  const modes = [
    LaunchMode.externalApplication,
    LaunchMode.platformDefault,
    LaunchMode.inAppBrowserView,
  ];
  for (final mode in modes) {
    try {
      if (await launchUrl(uri, mode: mode)) return;
    } catch (_) {
      // sıradaki modu dene
    }
  }
  if (context.mounted) {
    AppToast.error(context, 'Tarayıcı açılamadı.');
  }
}
