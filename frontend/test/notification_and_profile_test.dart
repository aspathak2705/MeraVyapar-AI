import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/capture/domain/local_evidence_capture_service.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/features/onboarding/domain/merchant_business_profile.dart';
import 'package:frontend/features/onboarding/data/local_business_profile_repository.dart';

class MockInMemoryDriver implements LocalDatabaseDriver {
  bool isOpen = false;
  final List<String> executedStatements = [];
  final Map<String, dynamic> pragmaStore = {'user_version': 4};
  final Map<String, List<Map<String, dynamic>>> tables = {};

  @override
  Future<void> open(String path) async {
    isOpen = true;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    executedStatements.add(sql);
    final lower = sql.toLowerCase();

    if (lower.contains('insert') && lower.contains(LocalDatabaseSchema.tableEvidenceMetadata)) {
      tables.putIfAbsent(LocalDatabaseSchema.tableEvidenceMetadata, () => []);
      tables[LocalDatabaseSchema.tableEvidenceMetadata]!.add({
        'id': arguments![0],
        'merchant_id': arguments[1],
        'filename': arguments[2],
        'sha256_hash': arguments[5],
      });
    } else if (lower.contains('insert') && lower.contains(LocalDatabaseSchema.tableTransactionCandidates)) {
      tables.putIfAbsent(LocalDatabaseSchema.tableTransactionCandidates, () => []);
      tables[LocalDatabaseSchema.tableTransactionCandidates]!.add({
        'id': arguments![0],
        'merchant_id': arguments[1],
        'primary_evidence_id': arguments[2],
        'transaction_type': arguments[3],
        'amount_minor_units': arguments[4],
        'counterparty_name': arguments[7],
      });
    } else if (lower.contains('insert or replace into ${LocalDatabaseSchema.tableMerchantBusinessProfile}')) {
      tables.putIfAbsent(LocalDatabaseSchema.tableMerchantBusinessProfile, () => []);
      tables[LocalDatabaseSchema.tableMerchantBusinessProfile]!.removeWhere((r) => r['merchant_id'] == arguments![0]);
      tables[LocalDatabaseSchema.tableMerchantBusinessProfile]!.add({
        'merchant_id': arguments![0],
        'business_name': arguments[1],
        'business_category': arguments[2],
        'business_type': arguments[3],
        'products_and_services': arguments[4],
        'city': arguments[5],
        'state': arguments[6],
        'customer_type': arguments[7],
        'sales_channels': arguments[8],
        'main_procurement_categories': arguments[9],
        'turnover_range': arguments[10],
        'business_goals': arguments[11],
        'updated_at': arguments[12],
      });
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('pragma user_version')) {
      return [{'user_version': pragmaStore['user_version']}];
    }
    if (lower.contains('from ${LocalDatabaseSchema.tableEvidenceMetadata}')) {
      final rows = tables[LocalDatabaseSchema.tableEvidenceMetadata] ?? [];
      if (arguments != null && arguments.isNotEmpty) {
        return rows.where((r) => r['sha256_hash'] == arguments[1]).toList();
      }
      return rows;
    }
    if (lower.contains('from ${LocalDatabaseSchema.tableTransactionCandidates}')) {
      final rows = tables[LocalDatabaseSchema.tableTransactionCandidates] ?? [];
      if (arguments != null && arguments.isNotEmpty) {
        return rows.where((r) => r['id'] == arguments[0]).toList();
      }
      return rows;
    }
    if (lower.contains('from ${LocalDatabaseSchema.tableMerchantBusinessProfile}')) {
      final rows = tables[LocalDatabaseSchema.tableMerchantBusinessProfile] ?? [];
      if (arguments != null && arguments.isNotEmpty) {
        return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
      }
      return rows;
    }
    return [];
  }

  @override
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action) async {
    await action(this);
  }

  @override
  Future<void> close() async {
    isOpen = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Extraction & Regression Tests', () {
    late LocalDatabaseService dbService;
    late MockInMemoryDriver mockDriver;

    setUp(() async {
      LocalDatabaseService.instance.reset();
      dbService = LocalDatabaseService.instance;
      mockDriver = MockInMemoryDriver();
      mockDriver.pragmaStore['user_version'] = 4;
      await dbService.initialize(customDriver: mockDriver, customDbPath: ':memory:');
    });

    tearDown(() async {
      await mockDriver.close();
    });

    test('GPay/PhonePe real notification extracts exact paise and credit direction', () async {
      final captureService = LocalEvidenceCaptureService(dbService: dbService);
      const merchantId = 'test_merchant_gpay';

      final candidate = await captureService.ingestEvidenceAndExtract(
        merchantId: merchantId,
        filename: 'notif_001.txt',
        mimeType: 'text/plain',
        fileSizeBytes: 35,
        sha256Hash: 'dummy_hash_001',
        storageRelativePath: 'evidence/notif_001.txt',
        sourceType: 'NOTIFICATION',
        rawText: 'KAVITA SANDEEP PATHAK paid you ₹1.00',
      );

      // Verify exact extraction properties
      expect(candidate.transactionType, equals('CREDIT'));
      expect(candidate.amount, equals('1.00'));
      expect(candidate.counterpartyName, equals('KAVITA SANDEEP PATHAK'));

      // Verify persistence via mock query
      final candidateRows = await mockDriver.query(
        'SELECT * FROM ${LocalDatabaseSchema.tableTransactionCandidates} WHERE id = ?',
        [candidate.id],
      );
      expect(candidateRows.isNotEmpty, isTrue);
      expect(candidateRows.first['amount_minor_units'], equals(100)); // Exactly 100 paise
      expect(candidateRows.first['transaction_type'], equals('CREDIT'));
      expect(candidateRows.first['counterparty_name'], equals('KAVITA SANDEEP PATHAK'));
    });

    test('Failed payment notification is rejected and does not fabricate candidate amount', () async {
      final captureService = LocalEvidenceCaptureService(dbService: dbService);
      const merchantId = 'test_merchant_failed';

      final candidate = await captureService.ingestEvidenceAndExtract(
        merchantId: merchantId,
        filename: 'notif_failed.txt',
        mimeType: 'text/plain',
        fileSizeBytes: 42,
        sha256Hash: 'dummy_hash_failed',
        storageRelativePath: 'evidence/notif_failed.txt',
        sourceType: 'NOTIFICATION',
        rawText: 'Payment of Rs. 500 from Rajesh failed due to bank timeout',
      );

      // Rejected transaction defaults safely to 0 paise UNKNOWN
      expect(candidate.transactionType, equals('UNKNOWN'));
      expect(candidate.amount, equals('0.00'));
    });
  });

  group('Merchant Business Profile Local Persistence Tests', () {
    late LocalDatabaseService dbService;
    late MockInMemoryDriver mockDriver;

    setUp(() async {
      LocalDatabaseService.instance.reset();
      dbService = LocalDatabaseService.instance;
      mockDriver = MockInMemoryDriver();
      mockDriver.pragmaStore['user_version'] = 4;
      await dbService.initialize(customDriver: mockDriver, customDbPath: ':memory:');
    });

    tearDown(() async {
      await mockDriver.close();
    });

    test('Business profile creates, persists in SQLite, and reads back with all fields', () async {
      final profileRepo = LocalBusinessProfileRepository(dbService: dbService);
      const merchantId = 'm_profile_test_1';

      final profile = MerchantBusinessProfile(
        merchantId: merchantId,
        businessName: 'Ramesh Kirana & General Store',
        businessCategory: 'Grocery & Spices',
        businessType: 'RETAIL',
        productsAndServices: 'Wheat, Pulses, Mustard Oil, Spices',
        city: 'Pune',
        state: 'Maharashtra',
        customerType: 'B2C',
        salesChannels: 'OFFLINE_STORE',
        mainProcurementCategories: 'Grains, Edible Oils',
        turnoverRange: '10L - 40L',
        businessGoals: 'Reduce supplier prices, recover customer balances',
        updatedAt: '2026-11-14T10:00:00Z',
      );

      await profileRepo.saveProfile(profile);

      final loaded = await profileRepo.getProfile(merchantId: merchantId);
      expect(loaded.businessName, equals('Ramesh Kirana & General Store'));
      expect(loaded.businessCategory, equals('Grocery & Spices'));
      expect(loaded.businessType, equals('RETAIL'));
      expect(loaded.productsAndServices, equals('Wheat, Pulses, Mustard Oil, Spices'));
      expect(loaded.city, equals('Pune'));
      expect(loaded.state, equals('Maharashtra'));
      expect(loaded.customerType, equals('B2C'));
      expect(loaded.turnoverRange, equals('10L - 40L'));
      expect(loaded.businessGoals, equals('Reduce supplier prices, recover customer balances'));
    });
  });
}
