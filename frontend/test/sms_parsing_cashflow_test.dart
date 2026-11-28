import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/features/capture/domain/sms_parser.dart';
import 'package:frontend/features/capture/domain/sms_service.dart';
import 'package:frontend/features/intelligence/domain/local_financial_intelligence_engine.dart';

/// Test in-memory driver simulating SQLite behavior for isolated unit tests
class TestSmsDatabaseDriver implements LocalDatabaseDriver {
  final Map<String, List<Map<String, dynamic>>> tables = {
    LocalDatabaseSchema.tableMerchantProfile: [],
    LocalDatabaseSchema.tableCanonicalTransactions: [],
    LocalDatabaseSchema.tableEvidenceMetadata: [],
    LocalDatabaseSchema.tableTransactionCandidates: [],
    LocalDatabaseSchema.tableEvidenceTombstones: [],
    LocalDatabaseSchema.tableCounterpartyOverrides: [],
    LocalDatabaseSchema.tablePaymentPromises: [],
  };

  @override
  Future<void> open(String path) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase().trim();

    if (lower.startsWith('insert into') || lower.startsWith('insert or ignore into')) {
      final tableName = _extractTableName(sql);
      tables.putIfAbsent(tableName, () => []);

      if (arguments != null && arguments.isNotEmpty) {
        if (tableName == LocalDatabaseSchema.tableCanonicalTransactions) {
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
            'updated_at': arguments[17],
          });
        } else if (tableName == LocalDatabaseSchema.tableEvidenceMetadata) {
          tables[tableName]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'filename': arguments[2],
            'mime_type': arguments[3],
            'file_size_bytes': arguments[4],
            'sha256_hash': arguments[5],
            'storage_relative_path': arguments[6],
            'captured_at': arguments[7],
            'source_type': arguments[8],
          });
        } else if (tableName == LocalDatabaseSchema.tableTransactionCandidates) {
          tables[tableName]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'primary_evidence_id': arguments[2],
            'transaction_type': arguments[3],
            'amount_minor_units': arguments[4],
            'currency': arguments[5],
            'transaction_timestamp': arguments[6],
            'counterparty_name': arguments[7],
            'payment_mode': arguments[8],
            'description': arguments[9],
            'lifecycle_status': arguments[10],
            'created_at': arguments[11],
            'updated_at': arguments[12],
          });
        } else if (tableName == LocalDatabaseSchema.tableEvidenceTombstones) {
          tables[tableName]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'evidence_fingerprint': arguments[2],
            'source_reference': arguments[3],
            'reason': arguments[4],
            'created_at': arguments[5],
          });
        }
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase().trim();

    if (lower.contains('pragma user_version')) {
      return [{'user_version': 7}];
    }

    final tableName = _extractTableName(sql);
    final rows = tables[tableName] ?? [];

    if (tableName == LocalDatabaseSchema.tableMerchantProfile) {
      return rows.where((r) => r['status'] == 'ACTIVE').toList();
    }

    if (tableName == LocalDatabaseSchema.tableCanonicalTransactions) {
      if (lower.contains('where merchant_id = ? and (')) {
        final merchantId = arguments?[0];
        final idemp = arguments?[1];
        final ref = arguments?[2];
        return rows.where((r) {
          final matchesMerchant = r['merchant_id'] == merchantId;
          final matchesIdemp = idemp != null && r['idempotency_key'] == idemp;
          final matchesRef = ref != null &&
              ref.toString().isNotEmpty &&
              r['transaction_reference'] == ref;
          return matchesMerchant && (matchesIdemp || matchesRef);
        }).toList();
      }

      if (lower.contains('where merchant_id = ?')) {
        final merchantId = arguments?[0];
        return rows.where((r) => r['merchant_id'] == merchantId).toList();
      }
    }

    if (tableName == LocalDatabaseSchema.tableEvidenceTombstones) {
      final merchantId = arguments?[0];
      final idemp = arguments?[1];
      final ref = arguments?[2];
      return rows.where((r) {
        final matchesMerchant = r['merchant_id'] == merchantId;
        final matchesIdemp = r['evidence_fingerprint'] == idemp;
        final matchesRef = ref != null &&
            ref.toString().isNotEmpty &&
            r['source_reference'] == ref;
        return matchesMerchant && (matchesIdemp || matchesRef);
      }).toList();
    }

    if (tableName == LocalDatabaseSchema.tableCounterpartyOverrides) {
      return [];
    }

    if (tableName == LocalDatabaseSchema.tablePaymentPromises) {
      return [];
    }

    return rows;
  }

  @override
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action) async {
    await action(this);
  }

  String _extractTableName(String sql) {
    final clean = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = clean.toLowerCase();

    if (lower.startsWith('insert into') || lower.startsWith('insert or ignore into')) {
      final parts = clean.split(' ');
      final intoIdx = parts.indexWhere((p) => p.toLowerCase() == 'into');
      if (intoIdx != -1 && intoIdx + 1 < parts.length) {
        return parts[intoIdx + 1].replaceAll('(', '').trim();
      }
    }

    if (lower.contains('from ')) {
      final fromIdx = clean.toLowerCase().indexOf('from ');
      final afterFrom = clean.substring(fromIdx + 5).trim();
      final tableToken = afterFrom.split(' ').first;
      return tableToken.trim();
    }

    return '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Parser Unit Tests — Realistic Indian Bank & UPI Formats', () {
    test('Debit SMS (verb-first): debited by Rs. 500.00', () {
      const sms = 'A/c *1234 debited by Rs. 500.00 on 28-Nov-26 by UPI Swiggy Ref: 9876543210';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isTrue);
      expect(parsed.rawDirection, 'debit');
      expect(parsed.type, 'MONEY_OUT');
      expect(parsed.amount, '500.00');
      expect(parsed.amountPaise, 50000);
      expect(parsed.merchant, 'Swiggy');
      expect(parsed.paymentMode, 'UPI');
      expect(parsed.bankRefNo, '9876543210');
      expect(parsed.accountNo, '1234');
    });

    test('Credit SMS (amount-first): Rs. 1,250.50 credited to A/c', () {
      const sms = 'Rs. 1,250.50 credited to A/c XX5678 on 28-Nov-26 from Kavita UPI Ref 1122334455';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isTrue);
      expect(parsed.rawDirection, 'credit');
      expect(parsed.type, 'MONEY_IN');
      expect(parsed.amount, '1250.50');
      expect(parsed.amountPaise, 125050);
      expect(parsed.merchant, 'Kavita');
      expect(parsed.paymentMode, 'UPI');
      expect(parsed.bankRefNo, '1122334455');
    });

    test('Person-to-Merchant Credit: X paid you ₹1,500.00', () {
      const sms = 'KAVITA SANDEEP PATHAK paid you ₹1,500.00 on PhonePe UPI Ref 88776655';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isTrue);
      expect(parsed.type, 'MONEY_IN');
      expect(parsed.amountPaise, 150000);
      expect(parsed.merchant, 'KAVITA SANDEEP PATHAK');
      expect(parsed.paymentMode, 'UPI');
      expect(parsed.bankRefNo, '88776655');
    });

    test('Card Debit at POS: INR 250.00 debited at DMART', () {
      const sms = 'Your card ending with 4321 debited for INR 250.00 at DMART on 28-Nov-26';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isTrue);
      expect(parsed.type, 'MONEY_OUT');
      expect(parsed.amountPaise, 25000);
      expect(parsed.merchant, 'DMart');
      expect(parsed.paymentMode, 'Card');
      expect(parsed.accountNo, '4321');
    });

    test('Refund / Reversal: Rs 350.00 refunded', () {
      const sms = 'Rs 350.00 refunded to your A/c XX1234 for Swiggy txn ref 77665544';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isTrue);
      expect(parsed.type, 'MONEY_IN');
      expect(parsed.amountPaise, 35000);
      expect(parsed.merchant, 'Swiggy');
    });
  });

  group('2. Amount & Paise Normalization Tests', () {
    test('Converts formatted INR strings to exact integer minor units (paise)', () {
      expect(SmsParser.parsePaise('500'), 50000);
      expect(SmsParser.parsePaise('500.00'), 50000);
      expect(SmsParser.parsePaise('1,250.50'), 125050);
      expect(SmsParser.parsePaise('12,34,567.89'), 123456789);
      expect(SmsParser.parsePaise('0.75'), 75);
      expect(SmsParser.parsePaise('0.05'), 5);
      expect(SmsParser.parsePaise('100.5'), 10050);
    });
  });

  group('3. Non-Transactional & Filter Checks', () {
    test('Filters out OTP messages', () {
      const sms = 'Your one time password (OTP) is 482910 for txn of Rs 500.00 at Amazon. Do not share.';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isFalse);
      expect(parsed.classification, 'OTP');
    });

    test('Filters out Promotional & Loan offers', () {
      const sms = 'Pre-approved business loan of Rs 5,00,000 for you. Apply now on MeraVyapar.';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isFalse);
      expect(parsed.classification, 'PROMO');
    });

    test('Filters out Payment Collect Requests', () {
      const sms = 'Sharma Traders has requested Rs 4,500.00 from you on Google Pay. Review and pay.';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isFalse);
      expect(parsed.classification, 'PAYMENT_REQUEST');
    });

    test('Filters out Failed / Declined Transactions', () {
      const sms = 'Transaction of Rs 1,200.00 failed at POS terminal. If debited, will be reversed in 3 days.';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isFalse);
      expect(parsed.classification, 'FAILED');
    });

    test('Filters out Balance Inquiry notifications without movement', () {
      const sms = 'Avail Bal in A/c XX1234 is Rs 45,210.00 as on 28-Nov-26.';
      final parsed = SmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.isEligible, isFalse);
      expect(parsed.classification, 'BALANCE_ONLY');
    });
  });

  group('4. Persistence, Deduplication & Cash-Flow Engine Integration', () {
    late TestSmsDatabaseDriver testDriver;
    const testMerchantId = 'merchant_test_123';

    setUp(() async {
      testDriver = TestSmsDatabaseDriver();
      LocalDatabaseService.instance.reset();
      await LocalDatabaseService.instance.initialize(
        customDriver: testDriver,
        customDbPath: ':memory:',
      );
      testDriver.tables[LocalDatabaseSchema.tableMerchantProfile]!.add({
        'id': testMerchantId,
        'display_name': 'Test Merchant Store',
        'status': 'ACTIVE',
      });
    });

    tearDown(() {
      LocalDatabaseService.instance.reset();
    });

    test('Persists incoming credit SMS and updates total inflows', () async {
      const creditSms = 'Rs. 1,250.50 credited to A/c XX5678 on 28-Nov-26 from Kavita UPI Ref 1122334455';
      final parsed = SmsParser.parse(creditSms)!;

      final success = await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:1795840000:credit1',
        parsed: parsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 0),
        rawBody: creditSms,
        dbService: LocalDatabaseService.instance,
      );

      expect(success, isTrue);

      final canonicalTable = testDriver.tables[LocalDatabaseSchema.tableCanonicalTransactions]!;
      expect(canonicalTable.length, 1);
      final row = canonicalTable.first;
      expect(row['merchant_id'], testMerchantId);
      expect(row['transaction_type'], 'MONEY_IN');
      expect(row['amount_minor_units'], 125050);
      expect(row['counterparty_name'], 'Kavita');
      expect(row['transaction_reference'], '1122334455');
      expect(row['source_type'], 'SMS');
    });

    test('Persists outgoing debit SMS and updates total outflows', () async {
      const debitSms = 'A/c *1234 debited by Rs. 500.00 on 28-Nov-26 by UPI Swiggy Ref: 9876543210';
      final parsed = SmsParser.parse(debitSms)!;

      final success = await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:1795840001:debit1',
        parsed: parsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 5),
        rawBody: debitSms,
        dbService: LocalDatabaseService.instance,
      );

      expect(success, isTrue);

      final canonicalTable = testDriver.tables[LocalDatabaseSchema.tableCanonicalTransactions]!;
      expect(canonicalTable.length, 1);
      final row = canonicalTable.first;
      expect(row['transaction_type'], 'MONEY_OUT');
      expect(row['amount_minor_units'], 50000);
      expect(row['counterparty_name'], 'Swiggy');
      expect(row['transaction_reference'], '9876543210');
    });

    test('Deduplicates repeated SMS broadcast or inbox sync with same identity', () async {
      const creditSms = 'Rs. 1,250.50 credited to A/c XX5678 on 28-Nov-26 from Kavita UPI Ref 1122334455';
      final parsed = SmsParser.parse(creditSms)!;
      final db = LocalDatabaseService.instance;

      final firstInsert = await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:1795840000:credit1',
        parsed: parsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 0),
        rawBody: creditSms,
        dbService: db,
      );
      expect(firstInsert, isTrue);

      // Repeat with identical ID (e.g. Inbox Sync runs after live broadcast)
      final secondInsert = await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:1795840000:credit1',
        parsed: parsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 0),
        rawBody: creditSms,
        dbService: db,
      );
      expect(secondInsert, isFalse);

      final canonicalTable = testDriver.tables[LocalDatabaseSchema.tableCanonicalTransactions]!;
      expect(canonicalTable.length, 1); // No duplicate
    });

    test('Prevents re-importing merchant-tombstoned deleted transactions', () async {
      const creditSms = 'Rs. 500.00 credited to A/c XX5678 UPI Ref 99887766';
      final parsed = SmsParser.parse(creditSms)!;
      final db = LocalDatabaseService.instance;

      // Add tombstone for this reference
      testDriver.tables[LocalDatabaseSchema.tableEvidenceTombstones]!.add({
        'id': 'tomb_1',
        'merchant_id': testMerchantId,
        'evidence_fingerprint': 'sms_tomb_fingerprint',
        'source_reference': '99887766',
        'reason': 'MERCHANT_DELETED',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final insertAttempt = await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:1795840002:tomb',
        parsed: parsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 10),
        rawBody: creditSms,
        dbService: db,
      );

      expect(insertAttempt, isFalse);
      final canonicalTable = testDriver.tables[LocalDatabaseSchema.tableCanonicalTransactions]!;
      expect(canonicalTable.isEmpty, isTrue);
    });

    test('Financial Intelligence Engine calculates net cash movement from persisted SMS', () async {
      final db = LocalDatabaseService.instance;

      // 1. Ingest Inflow (+₹1,250.50)
      const creditSms = 'Rs. 1,250.50 credited to A/c XX5678 on 28-Nov-26 from Kavita UPI Ref 1122334455';
      final creditParsed = SmsParser.parse(creditSms)!;
      await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:1:credit',
        parsed: creditParsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 0),
        rawBody: creditSms,
        dbService: db,
      );

      // 2. Ingest Outflow (-₹500.00)
      const debitSms = 'A/c *1234 debited by Rs. 500.00 on 28-Nov-26 by UPI Swiggy Ref: 9876543210';
      final debitParsed = SmsParser.parse(debitSms)!;
      await SmsService.persistParsedSmsTransaction(
        smsId: 'sms:HDFCBK:2:debit',
        parsed: debitParsed,
        senderAddress: 'VM-HDFCBK',
        occurredAt: DateTime.utc(2026, 11, 28, 10, 5),
        rawBody: debitSms,
        dbService: db,
      );

      // 3. Compute Financial Position
      final engine = LocalFinancialIntelligenceEngine(dbService: db);
      final metrics = await engine.calculatePosition(merchantId: testMerchantId);

      expect(metrics.totalInflowsPaise, 125050);
      expect(metrics.totalOutflowsPaise, 50000);
      expect(metrics.netCashMovementPaise, 75050);
      expect(metrics.totalInflowsInr, 1250.50);
      expect(metrics.totalOutflowsInr, 500.00);
      expect(metrics.netCashMovementInr, 750.50);
      expect(metrics.transactionCount, 2);
    });
  });
}
