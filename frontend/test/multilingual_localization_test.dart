import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/money/money.dart';
import 'package:frontend/core/localization/app_date_formatter.dart';
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

  group('Indian Currency Formatting Tests (Money.formatInr & formatRupees)', () {
    test('formats exact Indian numbering system commas from canonical integer paise', () {
      // 1,00,000 paise = ₹1,000
      expect(Money.formatInr(100000), equals('₹1,000'));

      // 25,00,000 paise = ₹25,000
      expect(Money.formatInr(2500000), equals('₹25,000'));

      // 1,50,00,000 paise = ₹1,50,000 (1.5 Lakhs)
      expect(Money.formatInr(15000000), equals('₹1,50,000'));

      // 1,25,00,00,000 paise = ₹1,25,00,000 (1.25 Crores)
      expect(Money.formatInr(1250000000), equals('₹1,25,00,000'));
    });

    test('preserves integer paise invariant during formatting and parsing', () {
      const canonicalPaise = 15000000; // ₹1,50,000
      final formatted = Money.formatInr(canonicalPaise);
      expect(formatted, equals('₹1,50,000'));

      final parsedPaise = Money.parseInrToPaise('150000');
      expect(parsedPaise, equals(canonicalPaise));
      expect(Money.formatPaise(parsedPaise), equals('150000.00'));
    });

    test('formats decimal paise cleanly when requested', () {
      expect(Money.formatInr(1500050, showDecimals: true), equals('₹15,000.50'));
      expect(Money.formatRupees(25000.75, showDecimals: true), equals('₹25,000.75'));
    });
  });

  group('Multilingual Date & Time Formatting Tests (AppDateFormatter)', () {
    final fixedDateTime = DateTime.utc(2026, 10, 24, 14, 30);

    test('formats dates across English, Hindi, and Marathi with same input DateTime', () {
      final enDate = AppDateFormatter.formatDate(fixedDateTime, locale: 'en');
      final hiDate = AppDateFormatter.formatDate(fixedDateTime, locale: 'hi');
      final mrDate = AppDateFormatter.formatDate(fixedDateTime, locale: 'mr');

      expect(enDate, equals('Oct 24, 2026'));
      expect(hiDate, isNotEmpty);
      expect(mrDate, isNotEmpty);
      // Hindi contains October representation (अक्तू or अक्टू) and 2026
      expect(hiDate.contains('2026') || hiDate.contains('२०२६'), isTrue);
      // Marathi contains October representation (ऑक्टो) and 2026
      expect(mrDate.contains('2026') || mrDate.contains('२०२६'), isTrue);
    });

    test('formats ISO strings while preserving exact timestamp', () {
      const isoString = '2026-10-24T14:30:00.000Z';
      final formatted = AppDateFormatter.formatIsoDate(isoString, locale: 'en');
      expect(formatted, equals('Oct 24, 2026'));
    });
  });

  group('ARB Key Completeness & Representative Key-Value Verification', () {
    test('verifies expanded strings match across en, hi, mr', () {
      final en = AppLocalizationsEn();
      final hi = AppLocalizationsHi();
      final mr = AppLocalizationsMr();

      // Representative pair 1: passbookAndTransactions
      expect(en.passbookAndTransactions, equals('Passbook & Transactions'));
      expect(hi.passbookAndTransactions, equals('पासबुक और लेन-देन'));
      expect(mr.passbookAndTransactions, equals('पासबुक आणि व्यवहार'));

      // Representative pair 2: paymentPromisesTitle
      expect(en.paymentPromisesTitle, equals('Payment Promises Memory'));
      expect(hi.paymentPromisesTitle, equals('भुगतान वादे मेमोरी'));
      expect(mr.paymentPromisesTitle, equals('पेमेंट वचने मेमरी'));

      // Representative pair 3: counterpartyRelationships
      expect(en.counterpartyRelationships, equals('Financial Relationships'));
      expect(hi.counterpartyRelationships, equals('व्यापारिक संबंध'));
      expect(mr.counterpartyRelationships, equals('व्यावसायिक संबंध'));

      // Representative pair 4: procurementAndKharidSaathi
      expect(en.procurementAndKharidSaathi, equals('Procurement & KharidSaathi'));
      expect(hi.procurementAndKharidSaathi, equals('खरीद और खरीदसाथी'));
      expect(mr.procurementAndKharidSaathi, equals('खरेदी आणि खरेदीसाथी'));

      // Representative pair 5: actionCenterTitle
      expect(en.actionCenterTitle, equals('Action Center'));
      expect(hi.actionCenterTitle, equals('कार्य केंद्र'));
      expect(mr.actionCenterTitle, equals('कृती केंद्र'));

      // Representative pair 6: reminderDraftTitle
      expect(en.reminderDraftTitle, equals('Payment Reminder Draft'));
      expect(hi.reminderDraftTitle, equals('भुगतान स्मरण ड्राफ्ट'));
      expect(mr.reminderDraftTitle, equals('पेमेंट स्मरणपत्र मसुदा'));

      // Representative pair 7: setupBusinessTitle
      expect(en.setupBusinessTitle, equals('Merchant Business Profile'));
      expect(hi.setupBusinessTitle, equals('व्यापारी प्रोफ़ाइल'));
      expect(mr.setupBusinessTitle, equals('व्यापार प्रोफाइल'));

      // Representative pair 8: permissionSettings
      expect(en.permissionSettings, equals('Permission Settings'));
      expect(hi.permissionSettings, equals('अनुमति सेटिंग्स'));
      expect(mr.permissionSettings, equals('परवानगी सेटिंग्ज'));

      // Representative pair 9: localSupplierDiscovery
      expect(en.localSupplierDiscovery, equals('Local Supplier Discovery'));
      expect(hi.localSupplierDiscovery, equals('स्थानीय सप्लायर खोज'));
      expect(mr.localSupplierDiscovery, equals('स्थानिक पुरवठादार शोध'));

      // Representative pair 10: unverifiedDiscoveryDisclaimer
      expect(en.unverifiedDiscoveryDisclaimer, contains('Unverified Online Supplier Discovery'));
      expect(hi.unverifiedDiscoveryDisclaimer, contains('असत्यापित ऑनलाइन'));
      expect(mr.unverifiedDiscoveryDisclaimer, contains('अपुष्ट ऑनलाइन'));
    });
  });
}
