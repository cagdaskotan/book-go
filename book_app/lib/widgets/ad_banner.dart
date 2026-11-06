import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_config.dart';
import '../services/plus_manager.dart';

/// Uyarlanır (adaptive) çapa banner. Sayfaların altına konabilir.
///
/// - Plus üyeye hiç gösterilmez.
/// - Yüklenene kadar (veya yüklenemezse) **hiç yer kaplamaz** — boş gri kutu
///   bırakmaz, düzeni bozmaz.
class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;

  bool get _plusBlocks => kPlusEnabled && plusManager.isPlus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _plusBlocks) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final media = MediaQuery.of(context);
    final width = media.size.width.truncate();
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
      media.orientation,
      width,
    );
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (_plusBlocks || !_loaded || ad == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
