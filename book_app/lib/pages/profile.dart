import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/sample_library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sheet.dart';
import '../widgets/appbar.dart';
import '../widgets/book_add_launcher.dart';
import '../widgets/navigation.dart';
import 'routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _displayName = TextEditingController();

  bool _saving = false;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool _exporting = false;
  bool _restoring = false;
  bool _sampleBusy = false;
  bool _sampleInstalled = false;

  @override
  void initState() {
    super.initState();
    _displayName.text = profileService.displayName;
    profileService.addListener(_onProfileChanged);
    _loadReminder();
    _loadSampleState();
  }

  @override
  void dispose() {
    profileService.removeListener(_onProfileChanged);
    _displayName.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Profil
  // ---------------------------------------------------------------------------

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await profileService.setDisplayName(_displayName.text);
      if (!mounted) return;
      _toast('Adın kaydedildi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Hatırlatıcı
  // ---------------------------------------------------------------------------

  Future<void> _loadReminder() async {
    final settings = await NotificationService.instance.settings();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = settings.enabled;
      _reminderTime = TimeOfDay(hour: settings.hour, minute: settings.minute);
    });
  }

  Future<void> _toggleReminder(bool enabled) async {
    try {
      if (!enabled) {
        await NotificationService.instance.cancelDaily();
        if (mounted) setState(() => _reminderEnabled = false);
        return;
      }
      final allowed = await NotificationService.instance.requestPermission();
      if (!mounted) return;
      if (!allowed) {
        _toast('Hatırlatıcı için bildirim iznine ihtiyacımız var.');
        return;
      }
      await NotificationService.instance.scheduleDaily(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      if (!mounted) return;
      setState(() => _reminderEnabled = true);
      _toast('Okuma hatırlatıcın ${_reminderTime.format(context)} için hazır.');
    } catch (_) {
      if (mounted) _toast('Hatırlatıcı ayarlanamadı.');
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    if (_reminderEnabled) {
      await NotificationService.instance.scheduleDaily(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Yedekleme
  // ---------------------------------------------------------------------------

  Future<void> _exportBackup() async {
    setState(() => _exporting = true);
    try {
      await BackupService().shareBackup();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Yedek dosyası hazırlanamadı.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Yedek dosyasını seç',
      type: FileType.any,
    );
    final files = picked?.files ?? const [];
    final path = files.isEmpty ? null : files.first.path;
    if (path == null) return;

    setState(() => _restoring = true);
    try {
      final service = BackupService();
      final file = File(path);
      final preview = await service.inspect(file);
      if (!mounted) return;

      final confirmed = await _confirmRestore(preview);
      if (confirmed != true) return;

      await service.restore(file);
      if (!mounted) return;
      _toast('Yedek geri yüklendi.');
      // Her ekran veriyi yeniden okusun diye kitaplığa dön.
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Yedek geri yüklenemedi.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<bool?> _confirmRestore(BackupPreview preview) {
    final date = preview.exportedAt;
    final stamp = date == null
        ? ''
        : '${date.day}.${date.month}.${date.year} tarihli yedek — ';
    return showAppConfirm(
      context,
      title: 'Yedeği geri yükle',
      message:
          '$stamp${preview.books} kitap, ${preview.logs} günlük kaydı, '
          '${preview.collections} raf, ${preview.quotes} alıntı, '
          '${preview.journalPages} defter sayfası. '
          'Şu anda cihazda olan kitaplık silinip yerine bu yedek yazılacak. '
          'Bu işlem geri alınamaz.',
      confirmLabel: 'Geri yükle',
      destructive: true,
      icon: Icons.settings_backup_restore_rounded,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goTab(HeaderTab tab) {
    final dest = (tab == HeaderTab.home) ? AppRoutes.home : AppRoutes.books;
    if (ModalRoute.of(context)?.settings.name != dest) {
      Navigator.pushReplacementNamed(context, dest);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: MainAppBar(
        activeTab: HeaderTab.home,
        showAddButton: false,
        onNavSelected: _goTab,
        onToggleTheme: null,
        onProfile: null,
        onFavorites: () => Navigator.pushNamed(context, AppRoutes.favorites),
        onInsights: () => Navigator.pushNamed(context, AppRoutes.insights),
        onCollections: () =>
            Navigator.pushNamed(context, AppRoutes.collections),
        userName: profileService.visibleName,
        brandColor: const Color(0xFF4F46E5),
      ),
      bottomNavigationBar: MainNavigation(
        current: null,
        allowCurrentSelection: true,
        onTabSelected: _goTab,
        onAddPressed: () => showBookAddLauncher(context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomNavInset(context)),
        child: Column(
          children: [
            _identityCard(),
            const SizedBox(height: 12),
            _appearanceCard(),
            const SizedBox(height: 12),
            _habitCard(),
            const SizedBox(height: 12),
            _sampleCard(),
            const SizedBox(height: 12),
            _backupCard(),
          ],
        ),
      ),
    );
  }

  Widget _identityCard() {
    final cs = Theme.of(context).colorScheme;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  profileService.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileService.visibleName,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kitaplığın bu cihazda saklanıyor',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayName,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveProfile(),
            decoration: const InputDecoration(
              labelText: 'Adın',
              hintText: 'Uygulamanın sana hitap etmesi için',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceCard() {
    final cs = Theme.of(context).colorScheme;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Görünüm',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Uygulamanın temasını seç; tercihin hatırlanır.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest_rounded, size: 18),
                    label: Text('Sistem'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, size: 18),
                    label: Text('Açık'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 18),
                    label: Text('Koyu'),
                  ),
                ],
                selected: {themeController.mode},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    themeController.set(values.first),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitCard() {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Okuma alışkanlığın',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _reminderEnabled,
            onChanged: _toggleReminder,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text(
              'Günlük okuma hatırlatıcısı',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('Her gün ${_reminderTime.format(context)}'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickReminderTime,
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Saati değiştir'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backupCard() {
    final cs = Theme.of(context).colorScheme;
    final busy = _exporting || _restoring;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yedekleme',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Kitaplığın yalnızca bu cihazda. Telefonu değiştirirken ya da '
            'uygulamayı silmeden önce yedek almayı unutma.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text(
              'Yedek al',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Kitaplar, günlük, raflar, alıntılar ve defter sayfaları',
            ),
            trailing: _exporting
                ? const _Spinner()
                : const Icon(Icons.chevron_right_rounded),
            onTap: busy ? null : _exportBackup,
          ),
          const Divider(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: const Text(
              'Yedekten geri yükle',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Mevcut kitaplığın yedekle değiştirilir'),
            trailing: _restoring
                ? const _Spinner()
                : const Icon(Icons.chevron_right_rounded),
            onTap: busy ? null : _restoreBackup,
          ),
        ],
      ),
    );
  }

  // Örnek kitaplık

  Future<void> _loadSampleState() async {
    final installed = await SampleLibraryService.isInstalled();
    if (mounted) setState(() => _sampleInstalled = installed);
  }

  Future<void> _installSample() async {
    final onay = await showAppConfirm(
      context,
      title: 'Örnek kitaplık eklensin mi?',
      message:
          'Kitaplığına 10 örnek kitap, okuma geçmişi, iki raf, alıntılar ve '
          'defter sayfaları eklenecek. Kendi kitapların olduğu gibi kalır; '
          'örnekleri daha sonra tek dokunuşla temizleyebilirsin.',
      confirmLabel: 'Ekle',
    );
    if (onay != true) return;

    setState(() => _sampleBusy = true);
    try {
      final summary = await SampleLibraryService.install();
      if (!mounted) return;
      setState(() {
        _sampleInstalled = true;
        _sampleBusy = false;
      });
      _toast(
        '${summary.books} kitap, ${summary.quotes} alıntı, '
        '${summary.collections} raf ve ${summary.journalPages} defter '
        'sayfası eklendi.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sampleBusy = false);
      _toast(e is ApiException ? e.message : 'Örnek kitaplık eklenemedi.');
    }
  }

  Future<void> _removeSample() async {
    final onay = await showAppConfirm(
      context,
      title: 'Örnek veriler silinsin mi?',
      message:
          'Yalnızca örnek kitaplar ve onlara bağlı kayıtlar silinir. '
          'Kendi eklediğin kitaplara dokunulmaz.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (onay != true) return;

    setState(() => _sampleBusy = true);
    try {
      await SampleLibraryService.remove();
      if (!mounted) return;
      setState(() {
        _sampleInstalled = false;
        _sampleBusy = false;
      });
      _toast('Örnek veriler temizlendi.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _sampleBusy = false);
      _toast('Örnek veriler silinemedi.');
    }
  }

  Widget _sampleCard() {
    final cs = Theme.of(context).colorScheme;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Örnek kitaplık',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (_sampleInstalled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Yüklü',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _sampleInstalled
                ? 'Örnekleri silmek kendi kitaplarına dokunmaz.'
                : 'Uygulamayı dolu hâliyle gezmek için örnek kitaplar, okuma '
                      'geçmişi, raflar, alıntılar ve defter sayfaları ekler.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _sampleInstalled
                  ? Icons.delete_sweep_rounded
                  : Icons.auto_stories_rounded,
            ),
            title: Text(
              _sampleInstalled
                  ? 'Örnek verileri temizle'
                  : 'Örnek verileri ekle',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _sampleInstalled
                  ? 'Eklenen örnek kayıtların tamamı silinir'
                  : '10 kitap · okuma geçmişi · 2 raf · alıntılar · defter',
            ),
            trailing: _sampleBusy
                ? const _Spinner()
                : const Icon(Icons.chevron_right_rounded),
            onTap: _sampleBusy
                ? null
                : (_sampleInstalled ? _removeSample : _installSample),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
