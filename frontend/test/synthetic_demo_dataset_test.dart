import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/features/transactions/data/local_canonical_transaction_repository.dart';
import 'package:frontend/features/transactions/domain/synthetic_demo_dataset_service.dart';
import 'package:frontend/features/intelligence/domain/local_financial_intelligence_engine.dart';

class InMemoryTxDatabaseDriver implements LocalDatabaseDriver {
  final List<Map<String, dynamic>> canonicalTxTable = [];

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
    final lower = sql.toLowerCase().trim();

    if (lower.startsWith('insert into') && lower.contains('canonical_transactions')) {
      if (arguments != null && arguments.length >= 17) {
        canonicalTxTable.add({
          'id': arguments[0],
          'merchant_id': arguments[1],
          'amount_minor_units': arguments[2],
          'currency': arguments[3],
          'transaction_type': arguments[4],
          'payment_mode': arguments[5],
          'counterparty_name': arguments[6],
          'counterparty_id': arguments[7],
          'transaction_reference': arguments[8],
          'description': arguments[9],
          'occurred_at': arguments[10],
          'reconciliation_status': arguments[11],
          'source_type': arguments[12],
          'source_provider': arguments[13],
          'is_simulated': arguments[14],
          'idempotency_key': arguments[15],
          'created_at': arguments[16],
        });
      }
    } else if (lower.startsWith('delete from') && lower.contains('canonical_transactions')) {
      final merchantId = arguments?[0] as String?;
      if (merchantId != null) {
        if (lower.contains('synthetic_demo') || lower.contains('is_simulated = 1')) {
          canonicalTxTable.removeWhere((r) =>
              r['merchant_id'] == merchantId &&
              (r['source_type'] == 'SYNTHETIC_DEMO' ||
                  r['is_simulated'] == 1 ||
                  (r['idempotency_key'] as String? ?? '').startsWith('demo_30d_')));
        } else {
          canonicalTxTable.removeWhere((r) => r['merchant_id'] == merchantId);
        }
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase();

    if (lower.contains('pragma user_version')) {
      return [{'user_version': 7}];
    }

    if (lower.contains('count(*)')) {
      final merchantId = arguments?[0] as String?;
      if (lower.contains('!=') || lower.contains('not like')) {
        final matches = canonicalTxTable.where((r) =>
            r['merchant_id'] == merchantId &&
            r['source_type'] != 'SYNTHETIC_DEMO' &&
            r['is_simulated'] != 1 &&
            !(r['idempotency_key'] as String? ?? '').startsWith('demo_30d_')).toList();
        return [{'count': matches.length}];
      } else {
        final matches = canonicalTxTable.where((r) =>
            r['merchant_id'] == merchantId &&
            (r['source_type'] == 'SYNTHETIC_DEMO' ||
                r['is_simulated'] == 1 ||
                (r['idempotency_key'] as String? ?? '').startsWith('demo_30d_'))).toList();
        return [{'count': matches.length}];
      }
    }

    if (lower.contains('from canonical_transactions') && lower.contains('idempotency_key = ?')) {
      final key = arguments?[0];
      return canonicalTxTable.where((r) => r['idempotency_key'] == key).toList();
    }

    if (lower.contains('from canonical_transactions') && lower.contains('where id = ? and merchant_id = ?')) {
      final id = arguments?[0];
      final mId = arguments?[1];
      return canonicalTxTable.where((r) => r['id'] == id && r['merchant_id'] == mId).toList();
    }

    if (lower.contains('from canonical_transactions') && lower.contains('where merchant_id = ?')) {
      final mId = arguments?[0];
      final filtered = canonicalTxTable.where((r) => r['merchant_id'] == mId).toList();
      return List<Map<String, dynamic>>.from(filtered);
    }

    if (lower.contains('from payment_promises') || lower.contains('from procurement_supplier_obligations')) {
      return [];
    }

    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('30-Day Synthetic Financial Demo Dataset Verification', () {
    late InMemoryTxDatabaseDriver testDriver;
    late LocalDatabaseService dbService;
    late LocalCanonicalTransactionRepository txRepo;
    const testMerchantId = 'merchant_ramesh_store';

    setUp(() async {
      testDriver = InMemoryTxDatabaseDriver();
      dbService = LocalDatabaseService.instance;
      dbService.reset();
      await dbService.initialize(
        customDriver: testDriver,
        customDbPath: ':memory:',
      );
      txRepo = LocalCanonicalTransactionRepository(dbService: dbService);
    });

    test('verifies blueprint structure and 30-day temporal coverage', () {
      final bps = SyntheticDemoDatasetService.blueprints;
      expect(bps.length, equals(89));

      final dayOffsets = bps.map((b) => b.dayOffset).toSet();
      // Verifies all 30 days (0 to 29) are covered
      expect(dayOffsets.length, equals(30));
      for (int day = 0; day < 30; day++) {
        expect(dayOffsets.contains(day), isTrue,
            reason: 'Day $day must have at least one transaction');
      }

      // Verify amounts stored strictly in integer paise
      for (final b in bps) {
        expect(b.amountPaise, greaterThan(0));
        expect(
            b.reference.endsWith('/DEMO') || b.reference.contains('/'), isTrue);
      }
    });

    test(
        'seeds 30-day demo dataset through canonical repository with integer paise',
        () async {
      final result = await SyntheticDemoDatasetService.seed30DayDemoData(
        merchantId: testMerchantId,
        txRepo: txRepo,
      );

      expect(result.totalRecords, equals(89));
      expect(result.totalInserted, equals(89));
      expect(result.totalInflowsPaise, greaterThan(0));
      expect(result.totalOutflowsPaise, greaterThan(0));
      expect(result.netPaise,
          equals(result.totalInflowsPaise - result.totalOutflowsPaise));
      expect(result.sampleMerchantName, equals('Ramesh Store'));

      // Check rows in database
      final storedTxs =
          await txRepo.getCanonicalTransactions(merchantId: testMerchantId);
      expect(storedTxs.length, equals(89));

      // Verify each record has synthetic demo flag and valid minor units
      for (final tx in storedTxs) {
        expect(tx.isSimulated, isTrue);
        expect(tx.sourceType, equals('SYNTHETIC_DEMO'));
        expect(tx.currency, equals('INR'));
        expect(tx.amount, isNotNull);
        expect(tx.description!.startsWith('[Synthetic Demo Data]'), isTrue);
      }

      // Check specific categories are present
      final hasRent = storedTxs.any((t) => t.counterpartyName?.contains('Suresh Agarwal') == true);
      final hasElectricity = storedTxs.any((t) => t.counterpartyName?.contains('MSEDCL') == true);
      final hasInternet = storedTxs.any((t) => t.counterpartyName?.contains('Jio') == true);
      final hasMandi = storedTxs.any((t) => t.counterpartyName?.contains('Mandi') == true);
      final hasDailySales = storedTxs.any((t) => t.transactionType == 'CREDIT');

      expect(hasRent, isTrue, reason: 'Rent expense must be present');
      expect(hasElectricity, isTrue, reason: 'Electricity utility must be present');
      expect(hasInternet, isTrue, reason: 'Internet utility must be present');
      expect(hasMandi, isTrue, reason: 'Supplier Mandi purchase must be present');
      expect(hasDailySales, isTrue, reason: 'Daily sales must be present');
    });

    test(
        'is fully idempotent: repeated seed runs do NOT create duplicate records',
        () async {
      // First seed
      await SyntheticDemoDatasetService.seed30DayDemoData(
        merchantId: testMerchantId,
        txRepo: txRepo,
      );

      final countAfterFirstSeed =
          await txRepo.getDemoTransactionCount(merchantId: testMerchantId);
      expect(countAfterFirstSeed, equals(89));

      // Second seed run
      final secondResult = await SyntheticDemoDatasetService.seed30DayDemoData(
        merchantId: testMerchantId,
        txRepo: txRepo,
      );

      final countAfterSecondSeed =
          await txRepo.getDemoTransactionCount(merchantId: testMerchantId);
      expect(countAfterSecondSeed, equals(89)); // Zero duplicates!
      expect(secondResult.totalRecords, equals(89));
    });

    test(
        'preserves genuine merchant records when seeding and clearing demo data',
        () async {
      const realMerchantId = 'merchant_real_123';

      // 1. Create a genuine real transaction
      await txRepo.createTransaction(
        merchantId: realMerchantId,
        amount: '12500.00',
        transactionType: 'CREDIT',
        paymentMode: 'UPI',
        counterpartyName: 'Real Customer Mehta',
        description: 'Genuine counter sale invoice #849',
        sourceType: 'MANUAL',
        isSimulated: false,
      );

      final initialRealCount =
          await txRepo.getGenuineTransactionCount(merchantId: realMerchantId);
      expect(initialRealCount, equals(1));

      // 2. Seed 30-day demo dataset for real merchant
      await SyntheticDemoDatasetService.seed30DayDemoData(
        merchantId: realMerchantId,
        txRepo: txRepo,
      );

      // Verify total is 1 real + 89 demo = 90
      final totalTxs =
          await txRepo.getCanonicalTransactions(merchantId: realMerchantId);
      expect(totalTxs.length, equals(90));

      // Real merchant count is STILL 1
      final midRealCount =
          await txRepo.getGenuineTransactionCount(merchantId: realMerchantId);
      expect(midRealCount, equals(1));

      // 3. Clear demo transactions
      final cleared = await SyntheticDemoDatasetService.clearDemoData(
        merchantId: realMerchantId,
        txRepo: txRepo,
      );
      expect(cleared, equals(89));

      // 4. Verify demo count is 0 and real transaction is 100% preserved
      final postDemoCount =
          await txRepo.getDemoTransactionCount(merchantId: realMerchantId);
      expect(postDemoCount, equals(0));

      final finalRealTxs =
          await txRepo.getCanonicalTransactions(merchantId: realMerchantId);
      expect(finalRealTxs.length, equals(1));
      expect(
          finalRealTxs.first.counterpartyName, equals('Real Customer Mehta'));
      expect(finalRealTxs.first.isSimulated, isFalse);
    });

    test(
        'seamlessly integrates with existing Financial Intelligence calculations',
        () async {
      await SyntheticDemoDatasetService.seed30DayDemoData(
        merchantId: testMerchantId,
        txRepo: txRepo,
      );

      final engine = LocalFinancialIntelligenceEngine(dbService: dbService);
      final position =
          await engine.calculatePosition(merchantId: testMerchantId);

      expect(position.transactionCount, equals(89));
      expect(position.totalInflowsPaise, greaterThan(0));
      expect(position.totalOutflowsPaise, greaterThan(0));
      expect(position.netCashMovementPaise,
          equals(position.totalInflowsPaise - position.totalOutflowsPaise));
      expect(position.currency, equals('INR'));
      expect(position.totalReceivablesPaise, equals(0),
          reason: 'No payment promises seeded');
      expect(position.openPromiseCount, equals(0),
          reason: 'No promises seeded');
    });
  });
}
