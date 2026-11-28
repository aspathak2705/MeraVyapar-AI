import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/core/money/money.dart';
import 'package:frontend/features/transactions/data/local_canonical_transaction_repository.dart';
import 'package:frontend/features/intelligence/domain/local_financial_intelligence_engine.dart';

class MockLedgerDatabaseDriver implements LocalDatabaseDriver {
  final Map<String, List<Map<String, dynamic>>> tables = {};

  @override
  Future<void> open(String path) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase().trim();
    if (lower.startsWith('create table')) {
      final tableName = _extractTableName(sql);
      tables.putIfAbsent(tableName, () => []);
    } else if (lower.startsWith('insert into') || lower.startsWith('insert or replace into')) {
      final tableName = _extractTableName(sql);
      tables.putIfAbsent(tableName, () => []);
      if (arguments != null && arguments.isNotEmpty) {
        if (tableName == LocalDatabaseSchema.tableCanonicalTransactions) {
          tables[tableName]!.removeWhere((r) => r['id'] == arguments[0]);
          tables[tableName]!.add({
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
      }
    } else if (lower.startsWith('delete from')) {
      final tableName = _extractTableName(sql);
      if (tables.containsKey(tableName) && arguments != null && arguments.isNotEmpty) {
        tables[tableName]!.removeWhere((r) => r['id'] == arguments[0]);
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('pragma user_version')) {
      return [{'user_version': 7}];
    }
    final tableName = _extractTableName(sql);
    final rows = List<Map<String, dynamic>>.from(tables[tableName] ?? []);

    if (lower.contains('count(*)')) {
      if (arguments != null && arguments.isNotEmpty) {
        final merchantId = arguments[0];
        final filtered = rows.where((r) => r['merchant_id'] == merchantId).toList();
        return [{'count': filtered.length}];
      }
      return [{'count': rows.length}];
    }

    if (arguments != null && arguments.isNotEmpty) {
      if (sql.contains('idempotency_key = ?')) {
        final key = arguments[0];
        return rows.where((r) => r['idempotency_key'] == key).toList();
      }
      final merchantId = arguments[0];
      return rows.where((r) => r['merchant_id'] == merchantId).toList();
    }

    return rows;
  }

  @override
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action) async {
    await action(this);
  }

  String _extractTableName(String sql) {
    final parts = sql.trim().split(RegExp(r'\s+'));
    for (int i = 0; i < parts.length; i++) {
      final p = parts[i].toLowerCase();
      if ((p == 'into' || p == 'from' || p == 'table') && i + 1 < parts.length) {
        var name = parts[i + 1].replaceAll('(', '').replaceAll(';', '').trim();
        if (name.toLowerCase() == 'if' && i + 3 < parts.length) {
          name = parts[i + 3].replaceAll('(', '').replaceAll(';', '').trim();
        }
        return name;
      }
    }
    return 'unknown';
  }
}

void main() {
  group('Genuine Merchant Ledger Verification (Zero Mock/Demo Data)', () {
    late MockLedgerDatabaseDriver mockDriver;
    late LocalCanonicalTransactionRepository txRepo;
    const testMerchantId = 'merchant_real_sharma_001';

    setUp(() async {
      mockDriver = MockLedgerDatabaseDriver();
      LocalDatabaseService.instance.reset();
      await LocalDatabaseService.instance.initialize(customDriver: mockDriver, customDbPath: ':memory:');
      txRepo = LocalCanonicalTransactionRepository(dbService: LocalDatabaseService.instance);
    });

    tearDown(() {
      LocalDatabaseService.instance.reset();
    });

    test('fresh initialization contains ZERO transactions and zero demo data', () async {
      final txs = await txRepo.getCanonicalTransactions(merchantId: testMerchantId);
      expect(txs, isEmpty);

      final count = await txRepo.getTransactionCount(merchantId: testMerchantId);
      expect(count, equals(0));
    });

    test('inserts genuine transactions with exact integer paise', () async {
      final tx = await txRepo.createTransaction(
        merchantId: testMerchantId,
        amount: '1250.50',
        transactionType: 'MONEY_IN',
        paymentMode: 'UPI',
        counterpartyName: 'Aarav Patel',
        description: 'Customer Store Sale',
      );

      expect(tx.amount, equals('1250.50'));
      expect(Money.parseInrToPaise(tx.amount!), equals(125050));
      expect(tx.counterpartyName, equals('Aarav Patel'));
      expect(tx.isSimulated, isFalse);
      expect(tx.sourceType, isNot('SYNTHETIC_DEMO'));

      final txs = await txRepo.getCanonicalTransactions(merchantId: testMerchantId);
      expect(txs.length, equals(1));
      expect(Money.parseInrToPaise(txs.first.amount!), equals(125050));
      expect(txs.first.counterpartyName, equals('Aarav Patel'));
    });

    test('preserves genuine ledger integrity across multiple operations', () async {
      await txRepo.createTransaction(
        merchantId: testMerchantId,
        amount: '5000.00',
        transactionType: 'MONEY_IN',
        paymentMode: 'UPI',
        counterpartyName: 'Daily Customer UPI',
      );

      await txRepo.createTransaction(
        merchantId: testMerchantId,
        amount: '2000.00',
        transactionType: 'MONEY_OUT',
        paymentMode: 'NEFT',
        counterpartyName: 'Wholesale Distributor',
      );

      final engine = LocalFinancialIntelligenceEngine(dbService: LocalDatabaseService.instance);
      final position = await engine.calculatePosition(merchantId: testMerchantId);

      expect(position.transactionCount, equals(2));
      expect(position.totalInflowsPaise, equals(500000));
      expect(position.totalOutflowsPaise, equals(200000));
      expect(position.netCashMovementPaise, equals(300000));
      expect(Money.formatInr(position.netCashMovementPaise), equals('₹3,000'));
    });
  });
}
