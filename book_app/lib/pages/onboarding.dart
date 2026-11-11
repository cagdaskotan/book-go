import 'package:flutter/material.dart';

import '../services/first_run.dart';
import '../services/gamification_service.dart';
import '../services/profile_service.dart';
import '../services/sample_library_service.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/mascot.dart';
import 'routes.dart';

/// İlk açılış karşılaması — üç soru, bir dakika.
///
/// Amaç kullanıcıyı eğitmek değil, <b>ilk kitabı rafa koydurmak</b>. Uzun
/// tanıtım turları yerine kısa bir karşılama, ilk oturum tutundurmasını en çok
/// etkileyen şey. Her adım atlanabilir: kimse kapıda tutulmuyor.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const int _stepCount = 3;
  static const List<int> _goalChoices = [10, 20, 30, 50];

  final _pager = PageController();
  final _nameCtrl = TextEditingController();

  int _step = 0;
  int _dailyGoal = 20;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = profileService.displayName;
  }

  @override
  void dispose() {
    _pager.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    final target = step.clamp(0, _stepCount - 1);
    setState(() => _step = target);
    _pager.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish({int? addedBookId}) async {
    if (_finishing) return;
    setState(() => _finishing = true);

    await profileService.setDisplayName(_nameCtrl.text);
    try {
      await GamificationService().updateDailyGoal(_dailyGoal);
    } catch (_) {
      // Hedef kaydedilemezse varsayılanla devam; karşılamayı tıkamayalım.
    }
    await FirstRun.markDone();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
      arguments: addedBookId,
    );
  }

  Future<void> _addFirstBook() async {
    final id = await showBookAddLauncher(context);
    if (!mounted) return;
    await _finish(addedBookId: id);
  }

  /// Eli boş gelen kullanıcı için örnek kitaplık.
  ///
  /// Boş bir kitaplıkta ısı haritası, seri, yıl karnesi ve alıntı defteri
  /// hep gri duruyor; uygulamanın ne yaptığı ancak dolu hâlinde görülüyor.
  /// Örnekler profilden tek dokunuşla temizlenebiliyor.
  Future<void> _browseSample() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await SampleLibraryService.install();
    } catch (_) {
      // Örnek kurulamadıysa karşılamayı tıkamayalım, boş kitaplıkla geç.
    }
    if (!mounted) return;
    setState(() => _finishing = false);
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              step: _step,
              total: _stepCount,
              onSkip: _finishing ? null : () => _finish(),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                children: [_nameStep(cs), _goalStep(cs), _bookStep(cs)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Ad
  // ---------------------------------------------------------------------------

  Widget _nameStep(ColorScheme cs) {
    return _StepFrame(
      mood: MascotMood.greeting,
      title: 'Merhaba, ben Bilge',
      subtitle:
          'Kitaplığını birlikte kuracağız. Sana nasıl hitap etmemi istersin?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _goTo(1),
            decoration: const InputDecoration(
              hintText: 'Adın',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          Gap.vSm,
          Text(
            'İstemezsen boş bırak — bu bilgi telefonundan çıkmıyor.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
      primaryLabel: 'Devam',
      onPrimary: () => _goTo(1),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Günlük hedef
  // ---------------------------------------------------------------------------

  Widget _goalStep(ColorScheme cs) {
    return _StepFrame(
      mood: MascotMood.encourage,
      title: 'Günde kaç sayfa?',
      subtitle:
          'Küçük başlamak en iyisi. Seriyi sürdürmek, çok okumaktan daha çok '
          'işe yarıyor. Sonra ayarlardan değiştirebilirsin.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final choice in _goalChoices)
                ChoiceChip(
                  label: Text('$choice sayfa'),
                  selected: _dailyGoal == choice,
                  onSelected: (_) => setState(() => _dailyGoal = choice),
                ),
            ],
          ),
          Gap.vLg,
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _dailyGoal.clamp(1, 120).toDouble(),
                  min: 1,
                  max: 120,
                  label: '$_dailyGoal',
                  onChanged: (v) => setState(() => _dailyGoal = v.round()),
                ),
              ),
              SizedBox(
                width: 54,
                child: Text(
                  '$_dailyGoal',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      primaryLabel: 'Devam',
      onPrimary: () => _goTo(2),
      onBack: () => _goTo(0),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. İlk kitap
  // ---------------------------------------------------------------------------

  Widget _bookStep(ColorScheme cs) {
    return _StepFrame(
      mood: MascotMood.reading,
      title: 'İlk kitabını koyalım',
      subtitle:
          'Barkodu okutmak en hızlısı: arka kapaktaki çizgili koda tut, '
          'künye kendiliğinden dolsun.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _finishing ? null : _addFirstBook,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Kitap ekle'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Gap.lg),
            ),
          ),
          Gap.vSm,
          OutlinedButton.icon(
            onPressed: _finishing ? null : _browseSample,
            icon: const Icon(Icons.auto_stories_rounded),
            label: const Text('Örnek kitaplıkla gez'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
            ),
          ),
          Gap.vMd,
          Text(
            'Elinde kitap yoksa örnek kitaplıkla dolaşabilirsin; '
            'örnekleri profilden tek dokunuşla temizlersin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
      primaryLabel: 'Kitaplığa geç',
      onPrimary: _finishing ? null : () => _finish(),
      onBack: () => _goTo(1),
      busy: _finishing,
    );
  }
}

/// Üst çubuk: adım göstergesi ve "şimdilik geç".
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.total,
    required this.onSkip,
  });

  final int step;
  final int total;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, 0),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: Gap.xs),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              height: 4,
              width: i == step ? 26 : 12,
              decoration: BoxDecoration(
                color: i <= step
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: .16),
                borderRadius: Radii.brPill,
              ),
            ),
          ],
          const Spacer(),
          TextButton(onPressed: onSkip, child: const Text('Şimdilik geç')),
        ],
      ),
    );
  }
}

/// Her adımın ortak iskeleti: maskot, başlık, açıklama, içerik, düğmeler.
class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.mood,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.busy = false,
  });

  final MascotMood mood;
  final String title;
  final String subtitle;
  final Widget body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Ekranı doldur ama içerik taşarsa kaydırılabilir kal. Daha önce her şey
    // üste yapışıyor, altta ekranın üçte biri kadar boşluk kalıyordu; düğme
    // de parmağın doğal olarak durduğu yerden uzaktaydı.
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xl);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Mascot(mood: mood, size: 128)),
                  Gap.vLg,
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                      color: cs.onSurface,
                    ),
                  ),
                  Gap.vSm,
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Gap.vXl,
                  body,
                  // Kalan boşluğu yut: düğmeler ekranın altına otursun.
                  const Spacer(),
                  Gap.vXl,
                  Row(
                    children: [
                      if (onBack != null) ...[
                        OutlinedButton(
                          onPressed: busy ? null : onBack,
                          child: const Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                        const SizedBox(width: Gap.sm),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: onPrimary,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: Gap.lg,
                            ),
                            backgroundColor: AppTheme.brandPrimary,
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(primaryLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
