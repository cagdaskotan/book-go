import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';

/// Kullanıcının cihazdaki profili — yalnızca görünen ad.
///
/// Hesap, e-posta ya da şifre yok: uygulama tamamen cihazda çalışır, kimlik
/// doğrulanacak bir sunucu bulunmaz. Ad, kullanıcıya hitap etmek için
/// (ve yedeğe dahil olmak üzere) veritabanında saklanır.
class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const String fallbackName = 'Okur';

  String _displayName = '';

  /// Kullanıcının girdiği ad; hiç girilmediyse boş.
  String get displayName => _displayName;

  /// Arayüzde gösterilecek ad — boşsa [fallbackName].
  String get visibleName =>
      _displayName.trim().isEmpty ? fallbackName : _displayName.trim();

  /// Avatar için baş harfler.
  String get initials {
    final source = _displayName.trim().isEmpty
        ? fallbackName
        : _displayName.trim();
    final parts = source.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final initials = (first + second).toUpperCase();
    return initials.isEmpty ? 'K' : initials;
  }

  Future<void> load() async {
    try {
      _displayName = await SettingsStore.getString(
            SettingsStore.profileName,
          ) ??
          '';
    } catch (_) {
      _displayName = '';
    }
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    final clean = name.trim();
    if (clean == _displayName) return;
    _displayName = clean;
    notifyListeners();
    if (clean.isEmpty) {
      await SettingsStore.remove(SettingsStore.profileName);
    } else {
      await SettingsStore.setString(SettingsStore.profileName, clean);
    }
  }
}

/// Genel erişim için tekil örnek (plusManager ile aynı desen).
final profileService = ProfileService.instance;
