import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/features/market_intelligence/data/local_supplier_shortlist_repository.dart';
import 'package:frontend/features/market_intelligence/domain/market_event_model.dart';
import 'package:frontend/features/market_intelligence/domain/merchant_market_relevance_model.dart';
import 'package:frontend/features/market_intelligence/domain/shortlisted_supplier_model.dart';
import 'package:frontend/features/market_intelligence/presentation/business_detail_screen.dart';
import 'package:frontend/features/market_intelligence/presentation/market_signal_detail_screen.dart';
import 'package:frontend/features/market_intelligence/presentation/relevant_market_signals_screen.dart';
import 'package:frontend/features/market_intelligence/presentation/supplier_shortlist_screen.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/l10n/app_localizations_en.dart';
import 'package:frontend/l10n/app_localizations_hi.dart';
import 'package:frontend/l10n/app_localizations_mr.dart';

class MockDatabaseDriver implements LocalDatabaseDriver {
  final List<Map<String, dynamic>> _storage = [];

  @override
  Future<void> open(String path) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action) async {
    await action(this);
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('INSERT OR REPLACE INTO supplier_shortlist')) {
      final args = arguments!;
      _storage.removeWhere((item) => item['id'] == args[0]);
      _storage.add({
        'id': args[0],
        'merchant_id': args[1],
        'business_name': args[2],
        'business_category': args[3],
        'address': args[4],
        'latitude': args[5],
        'longitude': args[6],
        'phone': args[7],
        'website': args[8],
        'rating': args[9],
        'review_count': args[10],
        'operating_hours': args[11],
        'source_url': args[12],
        'notes': args[13],
        'created_at': args[14],
      });
    } else if (normalized.contains('DELETE FROM supplier_shortlist WHERE id = ?')) {
      final id = arguments![0];
      _storage.removeWhere((item) => item['id'] == id);
    } else if (normalized.contains('UPDATE supplier_shortlist SET notes = ? WHERE id = ?')) {
      final args = arguments!;
      final notes = args[0];
      final id = args[1];
      for (final item in _storage) {
        if (item['id'] == id) {
          item['notes'] = notes;
        }
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final normalized = sql.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('PRAGMA user_version')) {
      return [{'user_version': 7}];
    }
    if (normalized.contains('WHERE merchant_id = ? AND (source_url = ? OR business_name = ?)')) {
      final args = arguments!;
      final mId = args[0];
      final url = args[1];
      final name = args[2];
      return _storage
          .where((item) => item['merchant_id'] == mId && (item['source_url'] == url || item['business_name'] == name))
          .toList();
    }
    if (normalized.contains('WHERE merchant_id = ? AND business_name = ?')) {
      final args = arguments!;
      final mId = args[0];
      final name = args[1];
      return _storage
          .where((item) => item['merchant_id'] == mId && item['business_name'] == name)
          .toList();
    }
    if (normalized.contains('FROM supplier_shortlist WHERE merchant_id = ?')) {
      final args = arguments!;
      final mId = args[0];
      return _storage.where((item) => item['merchant_id'] == mId).toList();
    }
    return [];
  }
}

void main() {
  group('Pass 3B Multilingual Keys Verification', () {
    test('verifies English Pass 3B keys', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.observedPriceDisclaimer, contains('Not a negotiated commercial trade quote'));
      expect(l10n.discoveredSupplierNotice, equals('Discovered Business • Unverified Supplier'));
      expect(l10n.observedPriceNotice, equals('Observed Listing Price • Not Trade Quote'));
      expect(l10n.externalNewsNotice, equals('External News Report'));
      expect(l10n.localMarketNotice, equals('Local Market Location'));
      expect(l10n.splitView, equals('Split View'));
      expect(l10n.mapOnly, equals('Map View'));
      expect(l10n.listOnly, equals('List View'));
      expect(l10n.selectAtLeastTwoToCompare, equals('Select at least 2 suppliers to compare.'));
    });

    test('verifies Hindi Pass 3B keys', () {
      final l10n = AppLocalizationsHi();
      expect(l10n.discoveredSupplierNotice, equals('खोजा गया व्यवसाय • असत्यापित आपूर्तिकर्ता'));
      expect(l10n.observedPriceNotice, equals('देखी गई सूची कीमत • व्यापार कोटेशन नहीं'));
      expect(l10n.splitView, equals('विभाजित दृश्य'));
      expect(l10n.mapOnly, equals('मानचित्र दृश्य'));
      expect(l10n.listOnly, equals('सूची दृश्य'));
    });

    test('verifies Marathi Pass 3B keys', () {
      final l10n = AppLocalizationsMr();
      expect(l10n.discoveredSupplierNotice, equals('शोधलेला व्यवसाय • अपुष्ट पुरवठादार'));
      expect(l10n.observedPriceNotice, equals('निदर्शनास आलेली सूची किंमत • व्यापार कोटेशन नाही'));
      expect(l10n.splitView, equals('विभाजित दृश्य'));
      expect(l10n.mapOnly, equals('नकाशा दृश्य'));
      expect(l10n.listOnly, equals('यादी दृश्य'));
    });
  });

  group('VyaparPulse & Supplier Experience Widget Tests', () {
    late MockDatabaseDriver mockDriver;

    setUp(() async {
      mockDriver = MockDatabaseDriver();
      final dbService = LocalDatabaseService.instance;
      dbService.reset();
      await dbService.initialize(customDriver: mockDriver, customDbPath: ':memory:');
    });

    testWidgets('RelevantMarketSignalsScreen renders engine filters and verification notices', (tester) async {
      final event = MarketEventModel.fromJson({
        'id': 'ev_1',
        'event_type': 'WHOLESALE_OFFER',
        'title': 'Premium Basmati Rice 25kg Bag',
        'summary': 'Bulk wholesale rice available from regional mandi.',
        'raw_occurred_at': '2026-11-20',
        'engine': 'google_shopping',
        'price': '₹1,850',
        'affected_domains': ['PROCUREMENT'],
        'source': {
          'id': 'src_1',
          'source_name': 'Google Shopping',
          'provider_name': 'SerpApi',
          'engine': 'google_shopping',
          'retrieved_at': '2026-11-20T10:00:00Z',
        },
      });

      final testSignal = MerchantMarketRelevanceModel(
        id: 'rel_1',
        merchantId: 'm_1',
        marketEventId: 'ev_1',
        relevanceStatus: 'POTENTIALLY_RELEVANT',
        reasonCodes: const ['CATEGORY_MATCH'],
        explanation: 'FMCG wholesale price benchmark',
        contextSnapshot: const {},
        detectedAt: DateTime.now(),
        marketEvent: event,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RelevantMarketSignalsScreen(
            initialSignals: [testSignal],
            onSignalTap: (_) {},
            onFetchSignals: ({category, businessType, city, engine, mapsType, placeId, query, state}) async => [testSignal],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify localized filter chips
      expect(find.text('All Markets'), findsOneWidget);
      expect(find.text('Wholesale Goods'), findsOneWidget);
      expect(find.text('Commodity News'), findsOneWidget);
      expect(find.text('Suppliers & Markets'), findsOneWidget);

      // Verify product card and observed price disclaimer notice
      expect(find.text('Premium Basmati Rice 25kg Bag'), findsOneWidget);
      expect(find.text('₹1,850'), findsOneWidget);
      expect(find.text('Observed Listing Price • Not Trade Quote'), findsOneWidget);
    });

    testWidgets('BusinessDetailScreen renders unverified discovery safeguard and toggles shortlist', (tester) async {
      final business = MarketEventModel.fromJson({
        'id': 'biz_1',
        'event_type': 'LOCAL_BUSINESS',
        'title': 'Shree Ganesh Wholesalers',
        'summary': 'Wholesale grains and pulses merchant.',
        'raw_occurred_at': '2026-11-22',
        'location': 'Market Yard, Pune',
        'rating': 4.6,
        'reviews': 42,
        'metrics': {
          'phone': '+91 98765 43210',
        },
        'affected_domains': ['PROCUREMENT'],
        'engine': 'google_maps',
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: BusinessDetailScreen(
              business: business,
              merchantId: 'm_test_1',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify unverified discovery safeguard banner
      expect(find.text('Discovered Business • Unverified Supplier'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().unverifiedDiscoveryDisclaimer), findsOneWidget);

      // Verify business details
      expect(find.text('Shree Ganesh Wholesalers'), findsWidgets);
      expect(find.text('Market Yard, Pune'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);

      // Toggle shortlist
      expect(find.text('Save to Shortlist'), findsOneWidget);
      await tester.ensureVisible(find.text('Save to Shortlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to Shortlist'));
      await tester.pumpAndSettle();

      expect(find.text('Saved to shortlist.'), findsOneWidget);
    });

    testWidgets('SupplierShortlistScreen renders comparison matrix and trade note editing', (tester) async {
      final repo = LocalSupplierShortlistRepository();
      await repo.addToShortlist(
        ShortlistedSupplierModel(
          id: 's_1',
          merchantId: 'm_test_2',
          businessName: 'Apex Distributors',
          businessCategory: 'FMCG Wholesale',
          address: 'Camp, Pune',
          rating: 4.5,
          reviewCount: 20,
          phone: '9822000000',
          createdAt: DateTime.now().toUtc(),
        ),
      );
      await repo.addToShortlist(
        ShortlistedSupplierModel(
          id: 's_2',
          merchantId: 'm_test_2',
          businessName: 'Bharat Traders',
          businessCategory: 'Grains & Spices',
          address: 'Hadapsar, Pune',
          rating: 4.2,
          reviewCount: 15,
          phone: '9822111111',
          createdAt: DateTime.now().toUtc(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: SupplierShortlistScreen(
              merchantId: 'm_test_2',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Saved Suppliers tab
      expect(find.text('Saved Suppliers (2)'), findsOneWidget);
      expect(find.text('Apex Distributors'), findsOneWidget);
      expect(find.text('Bharat Traders'), findsOneWidget);

      // Switch to Compare Selected tab
      await tester.tap(find.text('Compare Selected (2)'));
      await tester.pumpAndSettle();

      // Verify side-by-side comparison matrix renders
      expect(find.text('Compare Selected (2)'), findsWidgets);
      expect(find.text('FMCG Wholesale'), findsOneWidget);
      expect(find.text('Grains & Spices'), findsOneWidget);
      expect(find.text('★ 4.5'), findsOneWidget);
      expect(find.text('★ 4.2'), findsOneWidget);
    });

    testWidgets('MarketSignalDetailScreen displays observed price disclaimer and analyze action', (tester) async {
      final event = MarketEventModel.fromJson({
        'id': 'ev_shop',
        'event_type': 'COMMODITY_PRICE',
        'title': 'Refined Sunflower Oil 15L Tin',
        'summary': 'Online shopping wholesale price benchmark.',
        'raw_occurred_at': '2026-11-21',
        'price': '₹1,620',
        'engine': 'google_shopping',
        'affected_domains': ['PROCUREMENT'],
      });

      final signal = MerchantMarketRelevanceModel(
        id: 'rel_shop',
        merchantId: 'm_1',
        marketEventId: 'ev_shop',
        relevanceStatus: 'HIGHLY_RELEVANT',
        reasonCodes: const ['COMMODITY_MATCH'],
        contextSnapshot: const {},
        detectedAt: DateTime.now(),
        marketEvent: event,
      );

      bool analyzed = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MarketSignalDetailScreen(
            signal: signal,
            onAnalyzeWithFinancials: (_) => analyzed = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify observed listing price safeguard disclaimer
      expect(find.text('Refined Sunflower Oil 15L Tin'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().observedPriceDisclaimer), findsOneWidget);

      // Verify analyze impact button
      expect(find.text('Analyze Impact on My Business'), findsOneWidget);
      await tester.ensureVisible(find.text('Analyze Impact on My Business'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze Impact on My Business'));
      expect(analyzed, isTrue);
    });
  });
}
