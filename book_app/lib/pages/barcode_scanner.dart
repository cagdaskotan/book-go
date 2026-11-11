import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/isbn.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 350,
  );

  bool _handled = false;
  String? _candidate;
  int _candidateHits = 0;
  DateTime? _candidateStartedAt;
  DateTime? _lastDetection;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.replaceAll(RegExp(r'[\s-]'), '');
      if (value == null || !isValidBookISBN13(value)) continue;

      final now = DateTime.now();
      if (_candidate != value ||
          _lastDetection == null ||
          now.difference(_lastDetection!) > const Duration(seconds: 2)) {
        _candidate = value;
        _candidateHits = 1;
        _candidateStartedAt = now;
      } else {
        _candidateHits++;
      }
      _lastDetection = now;
      final stableFor = _candidateStartedAt == null
          ? Duration.zero
          : now.difference(_candidateStartedAt!);
      if (_candidateHits < 5 || stableFor < const Duration(milliseconds: 900)) {
        return;
      }

      _handled = true;
      await _controller.stop();
      HapticFeedback.mediumImpact();
      if (!mounted) return;

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => _ISBNConfirmation(isbn: value),
      );
      if (!mounted) return;
      if (confirmed == true) {
        Navigator.pop(context, value);
      } else {
        _handled = false;
        _candidate = null;
        _candidateHits = 0;
        _candidateStartedAt = null;
        await _controller.start();
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11101A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final scanWindow = _scanWindow(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
              return MobileScanner(
                controller: _controller,
                scanWindow: scanWindow,
                onDetect: _detect,
                // Varsayılan hata görünümü İngilizce tek satır ve çıkış yolu
                // sunmuyor: kamera izni reddedilen kullanıcı siyah ekranda
                // kalıyordu.
                errorBuilder: (context, error) => _ScannerError(
                  error: error,
                  onRetry: () async {
                    try {
                      await _controller.start();
                    } catch (_) {
                      // İzin hâlâ yoksa aynı ekran kalır; kullanıcı
                      // ayarlardan verip tekrar dener.
                    }
                  },
                ),
              );
            },
          ),
          IgnorePointer(
            child: CustomPaint(painter: const _ScannerOverlayPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _CircleButton(
                        icon: Icons.flash_on_rounded,
                        onTap: _controller.toggleTorch,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 300, height: 190),
                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'ISBN barkodunu çerçevenin içinde sabit tut',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(
                    'Yalnızca 978 veya 979 ile başlayan geçerli kitap kodları kabul edilir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Rect _scanWindow(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, size.height * .49),
    width: 300,
    height: 190,
  );
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .49),
      width: 300,
      height: 190,
    );
    final background = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(28)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      background,
      Paint()..color = Colors.black.withValues(alpha: .58),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(28)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: scanRect.center, width: 230, height: 8),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFFFB457),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ISBNConfirmation extends StatelessWidget {
  const _ISBNConfirmation({required this.isbn});
  final String isbn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2BAE8A).withValues(alpha: .14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF2BAE8A),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Kitap barkodu bulundu',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              _formattedISBN,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bu kodla kitap bilgilerini arayalım mı?',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Yeniden tara'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Kitabı bul'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _formattedISBN =>
      '${isbn.substring(0, 3)}-${isbn.substring(3, 4)}-${isbn.substring(4, 7)}-${isbn.substring(7, 12)}-${isbn.substring(12)}';
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .48),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}

/// Kamera açılamadığında görünen ekran.
///
/// En sık sebep izin reddi. Kullanıcıyı boş ekranda bırakmak yerine neyin
/// eksik olduğunu ve barkod olmadan da kitap ekleyebileceğini söylüyoruz.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;

    final String title;
    final String message;
    if (denied) {
      title = 'Kameraya izin gerekiyor';
      message =
          'Barkod okumak için kamerayı kullanmamız lazım. Telefon '
          'ayarlarından Uygulamalar → Bilge → İzinler → Kamera yolunu '
          'izleyip izni verebilirsin.';
    } else if (unsupported) {
      title = 'Bu cihazda barkod okunamıyor';
      message =
          'Kamera barkod taramayı desteklemiyor. Kitabı adıyla arayarak '
          'ekleyebilirsin.';
    } else {
      title = 'Kamera açılamadı';
      message =
          'Kamerayı başka bir uygulama kullanıyor olabilir. Kapatıp tekrar '
          'denemeyi ya da kitabı adıyla aramayı dene.';
    }

    return ColoredBox(
      color: const Color(0xFF11101A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  denied
                      ? Icons.no_photography_rounded
                      : Icons.videocam_off_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .76),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              if (!unsupported)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tekrar dene'),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Adıyla aramaya dön'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
