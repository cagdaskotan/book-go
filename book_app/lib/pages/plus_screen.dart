import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/plus_manager.dart';
import '../widgets/app_toast.dart';

/// Plus üyelik ekranı (paywall). Sade, kaliteli, gereksiz metinden uzak.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  // 0 = yıllık, 1 = aylık
  int _plan = 0;

  static const _perks = <(IconData, String)>[
    (Icons.recommend_rounded, 'Kişisel kitap önerileri'),
    (Icons.insights_rounded, 'Gelişmiş istatistikler & ısı haritası'),
    (Icons.collections_bookmark_rounded, 'Sınırsız koleksiyon ve alıntı'),
    (Icons.format_quote_rounded, 'Premium alıntı & paylaşım kartları'),
    (Icons.palette_rounded, 'Özel temalar ve maskot kostümleri'),
    (Icons.ios_share_rounded, 'Kütüphaneni dışa aktar'),
  ];

  Future<void> _activate() async {
    HapticFeedback.mediumImpact();
    // TODO: RevenueCat satın alma akışı. Şimdilik yerel etkinleştirme.
    await plusManager.setPlus(true);
    if (!mounted) return;
    AppToast.success(
      context,
      'Tüm Plus özellikleri açıldı. İyi okumalar!',
      title: 'Plus aktif 👑',
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0A24),
        body: AnimatedBuilder(
          animation: plusManager,
          builder: (context, _) {
            final isPlus = plusManager.isPlus;
            return Stack(
              children: [
                // Arka plan gradyanı
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF2A1E63),
                        Color(0xFF170F3A),
                        Color(0xFF0E0A24),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _crown(),
                              const SizedBox(height: 18),
                              const Text(
                                'Kütüphanem Plus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Okuma deneyimini bir üst seviyeye taşı.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ..._perks.map(_perkRow),
                            ],
                          ),
                        ),
                      ),
                      // Alt panel: planlar + CTA
                      _bottomPanel(isPlus),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _crown() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD166), Color(0xFFF7A072)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withValues(alpha: .35),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _perkRow((IconData, String) perk) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(perk.$1, color: const Color(0xFFFFD166), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              perk.$2,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const Icon(Icons.check_rounded, color: Color(0xFF7BE3C0), size: 20),
        ],
      ),
    );
  }

  Widget _bottomPanel(bool isPlus) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF160F3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: isPlus
            ? _activeState()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PlanCard(
                          selected: _plan == 0,
                          title: 'Yıllık',
                          price: '₺199,99',
                          per: '/yıl',
                          badge: '2 ay bedava',
                          onTap: () => setState(() => _plan = 0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PlanCard(
                          selected: _plan == 1,
                          title: 'Aylık',
                          price: '₺29,99',
                          per: '/ay',
                          onTap: () => setState(() => _plan = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _activate,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD166),
                        foregroundColor: const Color(0xFF2A1E63),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Plus’a geç'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İstediğin zaman iptal edebilirsin.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .45),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _activeState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF7BE3C0)),
            SizedBox(width: 8),
            Text(
              'Plus üyesin 👑',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => plusManager.setPlus(false),
          child: Text(
            'Plus’ı kapat (test)',
            style: TextStyle(color: Colors.white.withValues(alpha: .5)),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    required this.per,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String price;
  final String per;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFD166).withValues(alpha: .14)
              : Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFD166)
                : Colors.white.withValues(alpha: .12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7BE3C0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Color(0xFF143C30),
                        fontWeight: FontWeight.w600,
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                Text(
                  per,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
