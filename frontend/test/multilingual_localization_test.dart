import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/locale_provider.dart';
import 'package:frontend/core/localization/language_selector_button.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/l10n/app_localizations_en.dart';
import 'package:frontend/l10n/app_localizations_hi.dart';
import 'package:frontend/l10n/app_localizations_mr.dart';

class MockSecureStorage extends FlutterSecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      store[key] = value;
    } else {
      store.remove(key);
    }
  }
}

void main() {
  group('AppLocalizations Strings Verification', () {
    test('verifies English strings', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.appTitle, equals('MeraVyapar AI'));
      expect(l10n.privateDeviceLedger, equals('Private Device Ledger'));
      expect(l10n.language, equals('Language'));
      expect(l10n.english, equals('English'));
      expect(l10n.hindi, equals('हिंदी'));
      expect(l10n.marathi, equals('मराठी'));
      expect(l10n.home, equals('Home'));
      expect(l10n.actions, equals('Actions'));
    });

    test('verifies Hindi strings', () {
      final l10n = AppLocalizationsHi();
      expect(l10n.appTitle, equals('मेरा व्यापार AI'));
      expect(l10n.privateDeviceLedger, equals('निजी डिवाइस बहीखाता'));
      expect(l10n.language, equals('भाषा'));
      expect(l10n.home, equals('होम'));
      expect(l10n.actions, equals('कार्य'));
      expect(l10n.receivables, equals('उधारी वसूली'));
    });

    test('verifies Marathi strings', () {
      final l10n = AppLocalizationsMr();
      expect(l10n.appTitle, equals('माझा व्यापार AI'));
      expect(l10n.privateDeviceLedger, equals('खाजगी डिव्हाइस खातेवही'));
      expect(l10n.language, equals('भाषा'));
      expect(l10n.home, equals('मुख्यपृष्ठ'));
      expect(l10n.actions, equals('कृती'));
      expect(l10n.receivables, equals('येणे बाकी'));
    });

    test('verifies supportedLocales list contains en, hi, mr', () {
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('hi')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('mr')));
    });
  });

  group('LocaleNotifier State & Persistence Tests', () {
    test('defaults to English when no preference is saved', () async {
      final storage = MockSecureStorage();
      final notifier = LocaleNotifier(storage: storage);
      // Wait for microtask/async _loadPreference
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, equals(const Locale('en')));
    });

    test('restores saved Hindi preference from local storage', () async {
      final storage = MockSecureStorage();
      storage.store['mv_app_locale_preference'] = 'hi';

      final notifier = LocaleNotifier(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, equals(const Locale('hi')));
    });

    test('restores saved Marathi preference from local storage', () async {
      final storage = MockSecureStorage();
      storage.store['mv_app_locale_preference'] = 'mr';

      final notifier = LocaleNotifier(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, equals(const Locale('mr')));
    });

    test('falls back to English when invalid locale is in storage', () async {
      final storage = MockSecureStorage();
      storage.store['mv_app_locale_preference'] = 'de_INVALID';

      final notifier = LocaleNotifier(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, equals(const Locale('en')));
    });

    test('setLocale persists changed language', () async {
      final storage = MockSecureStorage();
      final notifier = LocaleNotifier(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await notifier.setLocale(const Locale('hi'));
      expect(notifier.state, equals(const Locale('hi')));
      expect(storage.store['mv_app_locale_preference'], equals('hi'));

      await notifier.setLanguageCode('mr');
      expect(notifier.state, equals(const Locale('mr')));
      expect(storage.store['mv_app_locale_preference'], equals('mr'));
    });

    test('setLocale rejects unsupported locale and resets to English', () async {
      final storage = MockSecureStorage();
      final notifier = LocaleNotifier(storage: storage);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await notifier.setLocale(const Locale('fr'));
      expect(notifier.state, equals(const Locale('en')));
    });
  });

  group('LanguageSelectorButton Widget Tests', () {
    testWidgets('renders language selector badge and switches locale dynamically', (tester) async {
      final storage = MockSecureStorage();
      final notifier = LocaleNotifier(storage: storage);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Test TopBar'),
                actions: const [
                  LanguageSelectorButton(),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify default EN badge
      expect(find.text('EN'), findsOneWidget);
      expect(find.byIcon(Icons.translate_rounded), findsOneWidget);

      // Tap selector button to open popup
      await tester.tap(find.byType(LanguageSelectorButton));
      await tester.pumpAndSettle();

      // Verify all 3 options visible
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('मराठी'), findsOneWidget);

      // Tap Hindi option
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      // State updated to hi
      expect(notifier.state, equals(const Locale('hi')));
      expect(storage.store['mv_app_locale_preference'], equals('hi'));
    });
  });
}
