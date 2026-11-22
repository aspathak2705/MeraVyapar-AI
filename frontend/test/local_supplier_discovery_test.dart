import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/features/market_intelligence/domain/market_event_model.dart';
import 'package:frontend/features/market_intelligence/domain/shortlisted_supplier_model.dart';
import 'package:frontend/features/market_intelligence/data/local_supplier_shortlist_repository.dart';
import 'package:frontend/features/market_intelligence/presentation/interactive_local_map_widget.dart';

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
      return [{'user_version': 6}];
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
  group('MarketEventModel Local Maps Metrics Tests', () {
    test('extracts coordinates, phone, operating hours, placeId from metrics', () {
      final json = {
        'id': 'ev-map-001',
        'event_type': 'SUPPLY_CHAIN_EVENT',
        'title': 'Kalyan Wholesale Traders',
        'summary': 'Wholesale grains and pulses merchant',
        'affected_domains': ['INVENTORY'],
        'price': null,
        'rating': 4.6,
        'reviews': 240,
        'location': 'Market Yard, Pune',
        'engine': 'google_maps',
        'evidence_nature': 'LOCAL_MARKET_LOCATION',
        'metrics': {
          'gps_coordinates': {'latitude': 18.498, 'longitude': 73.864},
          'latitude': 18.498,
          'longitude': 73.864,
          'phone': '+91 98220 12345',
          'website': 'https://kalyanwholesale.test',
          'place_id': 'ChIJ_kalyan_123',
          'data_id': '0x3bc2bf_data',
          'operating_hours': {'Mon-Sat': '9:00 AM - 8:00 PM'},
          'type': 'Wholesale Grocer',
        },
      };

      final event = MarketEventModel.fromJson(json);

      expect(event.title, equals('Kalyan Wholesale Traders'));
      expect(event.latitude, equals(18.498));
      expect(event.longitude, equals(73.864));
      expect(event.phone, equals('+91 98220 12345'));
      expect(event.website, equals('https://kalyanwholesale.test'));
      expect(event.placeId, equals('ChIJ_kalyan_123'));
      expect(event.category, equals('Wholesale Grocer'));
      expect(event.operatingHours, isA<Map>());
    });
  });

  group('ShortlistedSupplierModel Tests', () {
    test('fromMarketEvent correctly builds model and serializes round-trip', () {
      final event = MarketEventModel(
        id: 'ev-test',
        eventType: 'SUPPLY_CHAIN_EVENT',
        title: 'Maharashtra Dal Mill',
        summary: 'Pulse processing and bulk supplies',
        affectedDomains: const ['INVENTORY'],
        rating: 4.8,
        reviews: 95,
        location: 'Gultekdi Mandi, Pune',
        metrics: const {
          'latitude': 18.501,
          'longitude': 73.870,
          'phone': '+91 20 2426 9999',
          'website': 'https://dalmill.test',
          'type': 'Manufacturer & Wholesaler',
          'operating_hours': {'Mon-Sun': '7:00 AM - 9:00 PM'},
        },
      );

      final model = ShortlistedSupplierModel.fromMarketEvent(
        'merchant-123',
        event,
        notes: 'Gave ₹5 discount per kg on bulk order',
      );

      expect(model.merchantId, equals('merchant-123'));
      expect(model.businessName, equals('Maharashtra Dal Mill'));
      expect(model.businessCategory, equals('Manufacturer & Wholesaler'));
      expect(model.address, equals('Gultekdi Mandi, Pune'));
      expect(model.latitude, equals(18.501));
      expect(model.longitude, equals(73.870));
      expect(model.phone, equals('+91 20 2426 9999'));
      expect(model.website, equals('https://dalmill.test'));
      expect(model.notes, equals('Gave ₹5 discount per kg on bulk order'));
      expect(model.operatingHours, contains('Mon-Sun: 7:00 AM - 9:00 PM'));

      // Test toMap and fromMap round-trip
      final map = model.toMap();
      final restored = ShortlistedSupplierModel.fromMap(map);

      expect(restored.id, equals(model.id));
      expect(restored.businessName, equals(model.businessName));
      expect(restored.latitude, equals(18.501));
      expect(restored.longitude, equals(73.870));
      expect(restored.phone, equals('+91 20 2426 9999'));
      expect(restored.notes, equals(model.notes));
    });
  });

  group('LocalSupplierShortlistRepository Tests', () {
    test('adds, retrieves, checks, updates notes, and removes shortlisted suppliers', () async {
      final mockDriver = MockDatabaseDriver();
      final dbService = LocalDatabaseService.instance;
      dbService.reset();
      await dbService.initialize(customDriver: mockDriver, customDbPath: ':memory:');

      final repo = LocalSupplierShortlistRepository(dbService: dbService);

      final supplier1 = ShortlistedSupplierModel(
        id: 'shortlist-001',
        merchantId: 'm-001',
        businessName: 'Apex Spice Traders',
        businessCategory: 'Wholesale Spices',
        address: 'Bhavani Peth, Pune',
        latitude: 18.512,
        longitude: 73.868,
        phone: '+91 20 2634 1111',
        website: 'https://apexspice.test',
        rating: 4.4,
        reviewCount: 62,
        operatingHours: '9 AM - 7 PM',
        sourceUrl: 'https://apexspice.test',
        notes: 'Contact person: Ramesh Bhai',
        createdAt: DateTime.now().toUtc(),
      );

      // 1. Add to shortlist
      await repo.addToShortlist(supplier1);

      // 2. Check isShortlisted
      final isSaved = await repo.isShortlisted(
        merchantId: 'm-001',
        businessName: 'Apex Spice Traders',
        sourceUrl: 'https://apexspice.test',
      );
      expect(isSaved, isTrue);

      final notSaved = await repo.isShortlisted(
        merchantId: 'm-001',
        businessName: 'Non-existent merchant',
      );
      expect(notSaved, isFalse);

      // 3. Get shortlist
      final list = await repo.getShortlist(merchantId: 'm-001');
      expect(list.length, equals(1));
      expect(list.first.businessName, equals('Apex Spice Traders'));
      expect(list.first.notes, equals('Contact person: Ramesh Bhai'));

      // 4. Update notes
      await repo.updateNotes('shortlist-001', 'Updated: Best rate on black pepper');
      final updatedList = await repo.getShortlist(merchantId: 'm-001');
      expect(updatedList.first.notes, equals('Updated: Best rate on black pepper'));

      // 5. Remove from shortlist
      await repo.removeFromShortlist('shortlist-001');
      final afterRemove = await repo.getShortlist(merchantId: 'm-001');
      expect(afterRemove.isEmpty, isTrue);
    });
  });

  group('InteractiveLocalMapWidget Tests', () {
    testWidgets('renders graceful fallback when zero businesses have coordinates', (tester) async {
      final businessesWithoutCoords = [
        const MarketEventModel(
          id: 'b-1',
          eventType: 'SUPPLY_CHAIN_EVENT',
          title: 'Remote Trader 1',
          summary: 'Desc 1',
          affectedDomains: [],
          location: 'Pune Rural',
        ),
        const MarketEventModel(
          id: 'b-2',
          eventType: 'SUPPLY_CHAIN_EVENT',
          title: 'Remote Trader 2',
          summary: 'Desc 2',
          affectedDomains: [],
          location: 'Shikrapur Mandi',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveLocalMapWidget(
              businesses: businessesWithoutCoords,
              height: 300,
            ),
          ),
        ),
      );

      expect(find.text('No Geographic Coordinates Provided'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
    });

    testWidgets('renders map canvas when businesses have valid coordinates', (tester) async {
      final businessesWithCoords = [
        const MarketEventModel(
          id: 'b-coords-1',
          eventType: 'SUPPLY_CHAIN_EVENT',
          title: 'Central Spice Hub',
          summary: 'Bulk spices',
          affectedDomains: [],
          metrics: {
            'latitude': 18.520,
            'longitude': 73.856,
          },
        ),
        const MarketEventModel(
          id: 'b-coords-2',
          eventType: 'SUPPLY_CHAIN_EVENT',
          title: 'Deccan Rice Mill',
          summary: 'Grains wholesale',
          affectedDomains: [],
          metrics: {
            'latitude': 18.510,
            'longitude': 73.840,
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveLocalMapWidget(
              businesses: businessesWithCoords,
              height: 300,
            ),
          ),
        ),
      );

      expect(find.text('2 on map'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
