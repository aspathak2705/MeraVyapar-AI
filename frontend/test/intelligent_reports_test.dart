import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/features/intelligence/data/local_report_repository.dart';
import 'package:frontend/features/intelligence/domain/generated_report_model.dart';
import 'package:frontend/features/intelligence/domain/local_report_generator_service.dart';
import 'package:frontend/features/intelligence/domain/local_financial_intelligence_engine.dart';
import 'package:frontend/features/onboarding/data/local_business_profile_repository.dart';
import 'package:frontend/features/onboarding/domain/merchant_business_profile.dart';

class MockDatabaseDriver implements LocalDatabaseDriver {
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
    } else if (lower.startsWith('insert or replace into') || lower.startsWith('insert into')) {
      final tableName = _extractTableName(sql);
      tables.putIfAbsent(tableName, () => []);
      if (arguments != null && arguments.isNotEmpty) {
        if (tableName == LocalDatabaseSchema.tableGeneratedReports) {
          tables[tableName]!.removeWhere((r) => r['id'] == arguments[0]);
          tables[tableName]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'report_type': arguments[2],
            'title': arguments[3],
            'summary': arguments[4],
            'language': arguments[5],
            'payload_json': arguments[6],
            'created_at': arguments[7],
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

    if (arguments != null && arguments.isNotEmpty) {
      final merchantId = arguments[0];
      var filtered = rows.where((r) => r['merchant_id'] == merchantId).toList();
      if (arguments.length > 1 && arguments[1] != null) {
        final lang = arguments[1];
        filtered = filtered.where((r) => r['language'] == lang).toList();
      }
      return filtered;
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

class FakeBusinessProfileRepository extends LocalBusinessProfileRepository {
  @override
  Future<MerchantBusinessProfile> getProfile({required String merchantId, String? fallbackName}) async {
    return MerchantBusinessProfile(
      merchantId: merchantId,
      businessName: 'Patel General Store',
      businessCategory: 'Retail Grocery',
      businessType: 'RETAIL',
      city: 'Pune',
      state: 'Maharashtra',
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
}

class FakeFinancialIntelligenceEngine extends LocalFinancialIntelligenceEngine {
  @override
  Future<FinancialPositionMetrics> calculatePosition({required String merchantId}) async {
    return const FinancialPositionMetrics(
      totalInflowsPaise: 25000000, // ₹2,50,000
      totalOutflowsPaise: 10000000, // ₹1,00,000
      netCashMovementPaise: 15000000, // ₹1,50,000
      totalReceivablesPaise: 15000000, // ₹1,50,000
      totalOverdueReceivablesPaise: 5000000, // ₹50,000
      totalPayablesPaise: 3000000, // ₹30,000
      transactionCount: 24,
      openPromiseCount: 3,
      overduePromiseCount: 1,
      counterpartyCount: 8,
      currency: 'INR',
      oldestTransactionDate: '2026-01-01',
      newestTransactionDate: '2026-10-24',
    );
  }
}

void main() {
  group('LocalReportRepository SQLite Persistence Tests', () {
    late LocalReportRepository repo;
    late MockDatabaseDriver driver;

    setUp(() async {
      driver = MockDatabaseDriver();
      final dbService = LocalDatabaseService.instance;
      await dbService.initialize(customDriver: driver, customDbPath: ':memory:');
      repo = LocalReportRepository(dbService: dbService);
    });

    test('saves, retrieves, and filters intelligent reports by language', () async {
      const merchantId = 'test-merchant-001';

      final reportEn = GeneratedReportModel(
        id: 'rep-en-1',
        merchantId: merchantId,
        reportType: 'DAILY_FINANCIAL_DIGEST',
        title: 'Daily Financial Digest',
        summary: 'Cash flow is healthy.',
        language: 'en',
        payload: {'inflows_paise': 25000000},
        createdAt: DateTime.utc(2026, 10, 24, 10, 0),
      );

      final reportHi = GeneratedReportModel(
        id: 'rep-hi-1',
        merchantId: merchantId,
        reportType: 'DAILY_FINANCIAL_DIGEST',
        title: 'दैनिक वित्तीय सारांश',
        summary: 'रोकड़ प्रवाह स्थिर है।',
        language: 'hi',
        payload: {'inflows_paise': 25000000},
        createdAt: DateTime.utc(2026, 10, 24, 11, 0),
      );

      final reportMr = GeneratedReportModel(
        id: 'rep-mr-1',
        merchantId: merchantId,
        reportType: 'CASH_FLOW_HEALTH',
        title: 'रोख प्रवाह आरोग्य अहवाल',
        summary: 'रोख प्रवाह चांगला आहे.',
        language: 'mr',
        payload: {'inflows_paise': 25000000},
        createdAt: DateTime.utc(2026, 10, 24, 12, 0),
      );

      await repo.saveReport(reportEn);
      await repo.saveReport(reportHi);
      await repo.saveReport(reportMr);

      // Retrieve all reports
      final allReports = await repo.getReports(merchantId: merchantId);
      expect(allReports.length, equals(3));

      // Filter by language 'hi'
      final hiReports = await repo.getReports(merchantId: merchantId, language: 'hi');
      expect(hiReports.length, equals(1));
      expect(hiReports.first.title, equals('दैनिक वित्तीय सारांश'));
      expect(hiReports.first.language, equals('hi'));

      // Filter by language 'mr'
      final mrReports = await repo.getReports(merchantId: merchantId, language: 'mr');
      expect(mrReports.length, equals(1));
      expect(mrReports.first.title, equals('रोख प्रवाह आरोग्य अहवाल'));
      expect(mrReports.first.language, equals('mr'));

      // Delete a report
      await repo.deleteReport('rep-hi-1');
      final remaining = await repo.getReports(merchantId: merchantId);
      expect(remaining.length, equals(2));
      expect(remaining.any((r) => r.id == 'rep-hi-1'), isFalse);
    });
  });

  group('LocalReportGeneratorService Independent Language Tests', () {
    test('generates intelligent report with independent language selection without altering app UI', () async {
      final driver = MockDatabaseDriver();
      final dbService = LocalDatabaseService.instance;
      await dbService.initialize(customDriver: driver, customDbPath: ':memory:');
      final reportRepo = LocalReportRepository(dbService: dbService);
      final fakeProfile = FakeBusinessProfileRepository();
      final fakeEngine = FakeFinancialIntelligenceEngine();

      final generator = LocalReportGeneratorService(
        reportRepository: reportRepo,
        businessProfileRepository: fakeProfile,
        finEngine: fakeEngine,
      );

      // Generate report with independent language 'hi'
      final reportHi = await generator.generateReport(
        merchantId: 'test-merchant-001',
        reportType: 'DAILY_FINANCIAL_DIGEST',
        reportLanguage: 'hi',
      );

      expect(reportHi.language, equals('hi'));
      expect(reportHi.title, equals('दैनिक वित्तीय सारांश'));
      expect(reportHi.summary, contains('Patel General Store'));

      // Verify deterministic financial metrics stored as integer paise
      final metrics = reportHi.payload['metrics'] as Map<String, dynamic>;
      expect(metrics['total_inflows_paise'], equals(25000000));
      expect(metrics['net_cash_movement_paise'], equals(15000000));
      expect(metrics['total_receivables_paise'], equals(15000000));

      // Generate report with independent language 'mr'
      final reportMr = await generator.generateReport(
        merchantId: 'test-merchant-001',
        reportType: 'CASH_FLOW_HEALTH',
        reportLanguage: 'mr',
      );

      expect(reportMr.language, equals('mr'));
      expect(reportMr.title, equals('रोख प्रवाह आरोग्य अहवाल'));
      expect(reportMr.summary, contains('रोख'));
    });
  });
}
