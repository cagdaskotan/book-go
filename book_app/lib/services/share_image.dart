import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Ekrandaki bir widget'ı görsele çevirip paylaşır.
///
/// Sunucusuz bir uygulamanın en güçlü dağıtım kolu bu: kullanıcı kendi
/// okuma karnesini ya da alıntısını paylaştığında uygulamanın adı da onunla
/// gidiyor. O yüzden üretilen görselin kalitesi doğrudan büyüme meselesi —
/// [pixelRatio] 3 ile hikâye boyutunda bile keskin kalıyor.
///
/// Yakalanacak widget bir [RepaintBoundary] içinde olmalı ve o sınıra
/// [boundaryKey] ile ulaşılmalı.
Future<void> shareWidgetAsImage({
  required GlobalKey boundaryKey,
  required String fileName,
  String? text,
  String? subject,
  double pixelRatio = 3.0,
}) async {
  // Kapak görselleri gibi geç yüklenen parçalar için bir kare bekle.
  await Future<void>.delayed(const Duration(milliseconds: 120));

  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw StateError('Paylaşılacak görsel henüz çizilmemiş.');
  }

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Görsel verisi okunamadı.');
  }

  final dir = await getTemporaryDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${dir.path}/${fileName}_$stamp.png');
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    text: text,
    subject: subject,
  );
}
