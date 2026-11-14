import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/features/transactions/data/local_canonical_transaction_repository.dart';
import 'package:frontend/features/intelligence/domain/local_financial_intelligence_engine.dart';
import 'package:frontend/features/intelligence/domain/local_fig_service.dart';
import 'package:frontend/features/procurement/data/local_procurement_repository.dart';
import 'package:frontend/features/memory/data/local_memory_repository.dart';

class InMemoryUnifiedDriver implements LocalDatabaseDriver {
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

    if (lower.contains('insert into ${LocalDatabaseSchema.tableCanonicalTransactions}')) {
      tables.putIfAbsent(LocalDatabaseSchema.tableCanonicalTransactions, () => []);
      tables[LocalDatabaseSchema.tableCanonicalTransactions]!.add({
        'id': arguments![0],
        'merchant_id': arguments[1],
        'amount_minor_units': arguments[2] is num ? (arguments[2] as num).toInt() : int.tryParse(arguments[2].toString()) ?? 0,
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
    } else if (lower.contains('insert into ${LocalDatabaseSchema.tablePaymentPromises}')) {
      tables.putIfAbsent(LocalDatabaseSchema.tablePaymentPromises, () => []);
      tables[LocalDatabaseSchema.tablePaymentPromises]!.add({
        'id': arguments![0],
        'merchant_id': arguments[1],
        'counterparty_id': arguments[2],
        'amount_minor_units': arguments[3],
        'currency': arguments[4],
        'due_date': arguments[5],
        'status': arguments[6],
        'direction': arguments[7],
        'counterparty_name': arguments[8],
        'notes': arguments[9],
        'created_at': arguments[10],
        'updated_at': arguments[11],
      });
    } else if (lower.contains('insert into ${LocalDatabaseSchema.tableSupplierObligations}')) {
      tables.putIfAbsent(LocalDatabaseSchema.tableSupplierObligations, () => []);
      tables[LocalDatabaseSchema.tableSupplierObligations]!.add({
        'id': arguments![0],
        'merchant_id': arguments[1],
        'purchase_order_id': arguments[2],
        'supplier_id': arguments[3],
        'supplier_name': arguments[4],
        'total_obligation_minor_units': arguments[5],
        'settled_minor_units': arguments[6],
        'outstanding_minor_units': arguments[7],
        'due_date': arguments[8],
        'status': arguments[9],
        'created_at': arguments[10],
        'settled_at': arguments[11],
      });
    } else if (lower.contains('insert into ${LocalDatabaseSchema.tableFinancialCounterparties}')) {
      tables.putIfAbsent(LocalDatabaseSchema.tableFinancialCounterparties, () => []);
      tables[LocalDatabaseSchema.tableFinancialCounterparties]!.add({
        'id': arguments![0],
        'merchant_id': arguments[1],
        'name': arguments[2],
        'phone_number': arguments[3],
        'category': arguments[4],
        'created_at': arguments[5],
        'updated_at': arguments[6],
      });
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('pragma user_version')) {
      return [{'user_version': pragmaStore['user_version']}];
    }
    if (lower.contains('from ${LocalDatabaseSchema.tableCanonicalTransactions}')) {
      final rows = tables[LocalDatabaseSchema.tableCanonicalTransactions] ?? [];
      if (lower.contains('where idempotency_key = ?')) {
        return rows.where((r) => r['idempotency_key'] == arguments![0]).toList();
      }
      if (arguments != null && arguments.isNotEmpty) {
        return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
      }
      return rows;
    }
    if (lower.contains('from ${LocalDatabaseSchema.tablePaymentPromises}')) {
      final rows = tables[LocalDatabaseSchema.tablePaymentPromises] ?? [];
      if (arguments != null && arguments.isNotEmpty) {
        return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
      }
      return rows;
    }
    if (lower.contains('from ${LocalDatabaseSchema.tableSupplierObligations}')) {
      final rows = tables[LocalDatabaseSchema.tableSupplierObligations] ?? [];
      if (arguments != null && arguments.isNotEmpty) {
        return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
      }
      return rows;
    }
    if (lower.contains('from ${LocalDatabaseSchema.tableFinancialCounterparties}')) {
      final rows = tables[LocalDatabaseSchema.tableFinancialCounterparties] ?? [];
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

  group('Full Architecture Runtime Integration & Engine Derivation Tests', () {
    late LocalDatabaseService dbService;
    late InMemoryUnifiedDriver mockDriver;

    setUp(() async {
      LocalDatabaseService.instance.reset();
      dbService = LocalDatabaseService.instance;
      mockDriver = InMemoryUnifiedDriver();
      mockDriver.pragmaStore['user_version'] = 4;
      await dbService.initialize(customDriver: mockDriver, customDbPath: ':memory:');
    });

    tearDown(() async {
      await mockDriver.close();
    });

    test('Manual Income and Expense records update Financial Position without double-counting', () async {
      final txRepo = LocalCanonicalTransactionRepository(dbService: dbService);
      final engine = LocalFinancialIntelligenceEngine(dbService: dbService);
      const merchantId = 'merchant_unified_001';

      // 1. Record Manual Income: ₹1,500.00 (150,000 paise)
      await txRepo.createTransaction(
        merchantId: merchantId,
        amount: '1500.00',
        transactionType: 'CREDIT',
        paymentMode: 'CASH',
        counterpartyName: 'Walk-in Customer',
        description: 'Retail Sale',
        sourceType: 'MANUAL',
      );

      // 2. Record Manual Expense: ₹400.00 (40,000 paise)
      await txRepo.createTransaction(
        merchantId: merchantId,
        amount: '400.00',
        transactionType: 'DEBIT',
        paymentMode: 'UPI',
        counterpartyName: 'Local Transport',
        description: 'Tempo freight charge',
        sourceType: 'MANUAL',
      );

      // 3. Evaluate Grounded Position from Canonical SQLite
      final metrics = await engine.calculatePosition(merchantId: merchantId);
      expect(metrics.totalInflowsPaise, equals(150000));
      expect(metrics.totalOutflowsPaise, equals(40000));
      expect(metrics.netCashMovementPaise, equals(110000)); // Exactly ₹1,100.00
      expect(metrics.netCashMovementInr, equals(1100.00));
      expect(metrics.transactionCount, equals(2));
    });

    test('Outstanding Supplier Obligation updates Payables without fabricating actual expense transactions', () async {
      final engine = LocalFinancialIntelligenceEngine(dbService: dbService);
      const merchantId = 'merchant_unified_002';

      // Inject 1 unfulfilled supplier obligation of ₹8,000.00 (800,000 paise)
      await mockDriver.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableSupplierObligations} (
          id, merchant_id, purchase_order_id, supplier_id, supplier_name,
          total_obligation_minor_units, settled_minor_units, outstanding_minor_units,
          due_date, status, created_at, settled_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'ob_1',
          merchantId,
          'po_1',
          'sup_1',
          'Ambuja Cements Dist.',
          800000,
          0,
          800000,
          '2026-11-20T00:00:00Z',
          'PENDING',
          '2026-11-14T00:00:00Z',
          null,
        ],
      );

      // Evaluate position
      final metrics = await engine.calculatePosition(merchantId: merchantId);
      // Obligations should show in payables but NOT decrease cash or count as actual outflows
      expect(metrics.totalPayablesPaise, equals(800000));
      expect(metrics.totalPayablesInr, equals(8000.00));
      expect(metrics.totalOutflowsPaise, equals(0));
      expect(metrics.netCashMovementPaise, equals(0));
    });

    test('FIG derivation constructs connected graph snapshot without mutating canonical ledger', () async {
      final figService = LocalFinancialIntelligenceGraphService(dbService: dbService);
      final txRepo = LocalCanonicalTransactionRepository(dbService: dbService);
      const merchantId = 'merchant_fig_test';

      // Add counterparty and canonical transaction
      await mockDriver.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableFinancialCounterparties} (
          id, merchant_id, name, phone_number, category, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        ['cp_101', merchantId, 'Sharma Ji', '9876543210', 'CUSTOMER', '2026-11-14T00:00:00Z', '2026-11-14T00:00:00Z'],
      );

      final tx = await txRepo.createTransaction(
        merchantId: merchantId,
        amount: '500.00',
        transactionType: 'CREDIT',
        paymentMode: 'UPI',
        counterpartyName: 'Sharma Ji',
        counterpartyId: 'cp_101',
        description: 'Udhaar payment',
        sourceType: 'MANUAL',
      );

      final snapshot = await figService.buildGraphSnapshot(merchantId: merchantId);
      expect(snapshot.nodes.any((n) => n.id == merchantId), isTrue);
      expect(snapshot.nodes.any((n) => n.id == 'cp_101'), isTrue);
      expect(snapshot.nodes.any((n) => n.id == tx.id), isTrue);
      expect(snapshot.edges.any((e) => e.sourceId == merchantId && e.targetId == 'cp_101'), isTrue);
      expect(snapshot.edges.any((e) => e.sourceId == 'cp_101' && e.targetId == tx.id), isTrue);
    });
  });
}
