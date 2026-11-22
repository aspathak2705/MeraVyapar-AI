import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _kLocalePreferenceKey = 'mv_app_locale_preference';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  Locale get locale => Locale(code);
}

const List<AppLanguage> kSupportedLanguages = [
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
  AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिंदी'),
  AppLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
];

/// StateNotifier to manage and persist application Locale across app restarts.
class LocaleNotifier extends StateNotifier<Locale> {
  final FlutterSecureStorage _storage;

  LocaleNotifier({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        super(const Locale('en')) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final saved = await _storage.read(key: _kLocalePreferenceKey);
      if (saved != null && _isSupported(saved)) {
        state = Locale(saved);
      } else {
        state = const Locale('en');
      }
    } catch (_) {
      state = const Locale('en');
    }
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode.toLowerCase();
    if (!_isSupported(code)) {
      state = const Locale('en');
      return;
    }

    state = Locale(code);
    try {
      await _storage.write(key: _kLocalePreferenceKey, value: code);
    } catch (_) {}
  }

  Future<void> setLanguageCode(String code) async {
    await setLocale(Locale(code));
  }

  bool _isSupported(String code) {
    return kSupportedLanguages.any((lang) => lang.code == code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
