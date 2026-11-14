import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';

/// Test in-memory SQLite driver implementing LocalDatabaseDriver
class TestDatabaseDriver implements LocalDatabaseDriver {
  bool isOpen = false;
  final List<String> executedStatements = [];
  final Map<String, dynamic> pragmaStore = {'user_version': 0};
  final Map<String, List<Map<String, dynamic>>> tableData = {};

  @override
  Future<void> open(String path) async {
    isOpen = true;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) throw StateError('DB driver not open');
    executedStatements.add(sql.trim());

    if (sql.contains('PRAGMA user_version =')) {
      final match = RegExp(r'PRAGMA user_version\s*=\s*(\d+)').firstMatch(sql);
      if (match != null) {
        pragmaStore['user_version'] = int.parse(match.group(1)!);
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) throw StateError('DB driver not open');
    if (sql.contains('PRAGMA user_version')) {
      return [{'user_version': pragmaStore['user_version']}];
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

  group('SQLite V4 Schema & Migration Verification', () {
    setUp(() {
      LocalDatabaseService.instance.reset();
    });

    test('Fresh installation initializes full V4 schema and sets user_version to 4', () async {
      final driver = TestDatabaseDriver();
      driver.pragmaStore['user_version'] = 0; // Fresh install

      await LocalDatabaseService.instance.initialize(customDriver: driver, customDbPath: ':memory:');

      expect(driver.isOpen, isTrue);
      expect(driver.pragmaStore['user_version'], equals(4));

      // Check all procurement tables exist in executed statements
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableSuppliers)), isTrue);
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tablePurchaseRequests)), isTrue);
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableSupplierQuotations)), isTrue);
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tablePurchaseOrders)), isTrue);
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableSupplierObligations)), isTrue);

      // Check existing V3 canonical tables also exist
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableCanonicalTransactions)), isTrue);
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableMerchantProfile)), isTrue);
    });

    test('Upgrade from existing V3 database applies additive procurement migration transactionally', () async {
      final driver = TestDatabaseDriver();
      driver.pragmaStore['user_version'] = 3; // Existing V3 database

      await LocalDatabaseService.instance.initialize(customDriver: driver, customDbPath: ':memory:');

      expect(driver.isOpen, isTrue);
      expect(driver.pragmaStore['user_version'], equals(4));

      // Should execute procurement statements
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableSuppliers)), isTrue);
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableSupplierObligations)), isTrue);

      // Should not re-run V3 baseline table creation statements (e.g. tableCanonicalTransactions)
      expect(driver.executedStatements.any((s) => s.contains(LocalDatabaseSchema.tableCanonicalTransactions)), isFalse);
    });
  });
}
