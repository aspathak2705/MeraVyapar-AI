import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/features/capture/domain/local_evidence_capture_service.dart';
import 'package:frontend/features/transactions/data/local_canonical_transaction_repository.dart';
import 'package:frontend/features/transactions/domain/statement_import_service.dart';

/// Test in-memory SQLite driver
class InMemoryDatabaseDriver implements LocalDatabaseDriver {
  bool isOpen = false;
  final List<String> executedStatements = [];
  final Map<String, dynamic> pragmaStore = {'user_version': 0};
  final Map<String, List<Map<String, dynamic>>> tables = {};

  @override
  Future<void> open(String path) async {
    isOpen = true;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) throw StateError('DB driver not open');
    executedStatements.add(sql.trim());

    final cleanSql = sql.trim();
    if (cleanSql.contains('PRAGMA user_version =')) {
      final match = RegExp(r'PRAGMA user_version\s*=\s*(\d+)').firstMatch(cleanSql);
      if (match != null) {
        pragmaStore['user_version'] = int.parse(match.group(1)!);
      }
      return;
    }

    if (cleanSql.startsWith('INSERT') || cleanSql.startsWith('INSERT OR IGNORE')) {
      _handleInsert(cleanSql, arguments);
    } else if (cleanSql.startsWith('DELETE')) {
      _handleDelete(cleanSql, arguments);
    } else if (cleanSql.startsWith('UPDATE')) {
      _handleUpdate(cleanSql, arguments);
    }
  }

  void _handleInsert(String sql, List<dynamic>? args) {
    String tableName = '';
    for (final t in [
      LocalDatabaseSchema.tableEvidenceTombstones,
      LocalDatabaseSchema.tableCounterpartyOverrides,
      LocalDatabaseSchema.tableCanonicalTransactions,
      LocalDatabaseSchema.tableEvidenceMetadata,
      LocalDatabaseSchema.tableTransactionCandidates,
      LocalDatabaseSchema.tableMerchantProfile,
    ]) {
      if (sql.contains(t)) {
        tableName = t;
        break;
      }
    }
    if (tableName.isEmpty) return;

    tables.putIfAbsent(tableName, () => []);

    if (tableName == LocalDatabaseSchema.tableEvidenceTombstones && args != null) {
      tables[tableName]!.add({
        'id': args[0],
        'merchant_id': args[1],
        'evidence_fingerprint': args[2],
        'source_reference': args[3],
        'reason': args[4],
        'created_at': args[5],
      });
    } else if (tableName == LocalDatabaseSchema.tableCounterpartyOverrides && args != null) {
      tables[tableName]!.removeWhere((r) =>
          r['merchant_id'] == args[1] && r['raw_counterparty_alias'] == args[2]);
      tables[tableName]!.add({
        'id': args[0],
        'merchant_id': args[1],
        'raw_counterparty_alias': args[2],
        'normalized_name': args[3],
        'assigned_category': args[4],
        'apply_to_historical': args[5],
        'created_at': args[6],
        'updated_at': args[7],
      });
    } else if (tableName == LocalDatabaseSchema.tableCanonicalTransactions && args != null) {
      tables[tableName]!.add({
        'id': args[0],
        'merchant_id': args[1],
        'amount_minor_units': args[2],
        'currency': args[3],
        'transaction_type': args[4],
        'payment_mode': args[5],
        'counterparty_name': args[6],
        'counterparty_id': args[7],
        'transaction_reference': args[8],
        'description': args[9],
        'occurred_at': args[10],
        'reconciliation_status': args[11],
        'source_type': args[12],
        'source_provider': args[13],
        'is_simulated': args[14],
        'idempotency_key': args[15],
        'created_at': args[16],
      });
    } else if (tableName == LocalDatabaseSchema.tableEvidenceMetadata && args != null) {
      tables[tableName]!.add({
        'id': args[0],
        'merchant_id': args[1],
        'filename': args[2],
        'mime_type': args[3],
        'file_size_bytes': args[4],
        'sha256_hash': args[5],
        'storage_relative_path': args[6],
        'captured_at': args[7],
        'source_type': args[8],
      });
    } else if (tableName == LocalDatabaseSchema.tableTransactionCandidates && args != null) {
      tables[tableName]!.add({
        'id': args[0],
        'merchant_id': args[1],
        'primary_evidence_id': args[2],
        'transaction_type': args[3],
        'amount_minor_units': args[4],
        'currency': args[5],
        'transaction_timestamp': args[6],
        'counterparty_name': args[7],
        'payment_mode': args[8],
        'description': args[9],
        'lifecycle_status': args[10],
        'created_at': args[11],
        'updated_at': args[12],
      });
    }
  }

  void _handleDelete(String sql, List<dynamic>? args) {
    if (sql.contains(LocalDatabaseSchema.tableCanonicalTransactions) && args != null) {
      final list = tables[LocalDatabaseSchema.tableCanonicalTransactions];
      if (list != null) {
        list.removeWhere((r) => r['id'] == args[0] && r['merchant_id'] == args[1]);
      }
    }
  }

  void _handleUpdate(String sql, List<dynamic>? args) {
    if (sql.contains(LocalDatabaseSchema.tableCanonicalTransactions) && args != null) {
      final list = tables[LocalDatabaseSchema.tableCanonicalTransactions];
      if (list != null) {
        for (final row in list) {
          if (row['merchant_id'] == args[2] && (row['counterparty_name'] as String?)?.toLowerCase() == (args[3] as String).toLowerCase()) {
            row['counterparty_name'] = args[0];
            row['description'] = '${row['description']} [Category: ${args[1]}]';
          }
        }
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    if (!isOpen) throw StateError('DB driver not open');
    if (sql.contains('PRAGMA user_version')) {
      return [{'user_version': pragmaStore['user_version']}];
    }

    String tableName = '';
    for (final t in [
      LocalDatabaseSchema.tableEvidenceTombstones,
      LocalDatabaseSchema.tableCounterpartyOverrides,
      LocalDatabaseSchema.tableCanonicalTransactions,
      LocalDatabaseSchema.tableEvidenceMetadata,
      LocalDatabaseSchema.tableTransactionCandidates,
      LocalDatabaseSchema.tableMerchantProfile,
    ]) {
      if (sql.contains(t)) {
        tableName = t;
        break;
      }
    }

    final rows = tables[tableName] ?? [];

    if (tableName == LocalDatabaseSchema.tableEvidenceTombstones && arguments != null) {
      if (sql.contains('source_reference = ?')) {
        return rows.where((r) =>
            r['merchant_id'] == arguments[0] &&
            (r['evidence_fingerprint'] == arguments[1] ||
                (arguments[2] != '' && r['source_reference'] != null && r['source_reference'] == arguments[2]))).toList();
      }
      if (arguments.length == 2) {
        return rows.where((r) => r['merchant_id'] == arguments[0] && r['evidence_fingerprint'] == arguments[1]).toList();
      }
      return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
    }

    if (tableName == LocalDatabaseSchema.tableCounterpartyOverrides && arguments != null) {
      return rows.where((r) => r['merchant_id'] == arguments[0] && r['raw_counterparty_alias'] == arguments[1]).toList();
    }

    if (tableName == LocalDatabaseSchema.tableCanonicalTransactions && arguments != null) {
      if (sql.contains('idempotency_key = ?')) {
        return rows.where((r) => r['idempotency_key'] == arguments[0]).toList();
      }
      if (sql.contains('WHERE id = ? AND merchant_id = ?')) {
        return rows.where((r) => r['id'] == arguments[0] && r['merchant_id'] == arguments[1]).toList();
      }
      return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
    }

    if (tableName == LocalDatabaseSchema.tableEvidenceMetadata && arguments != null) {
      return rows.where((r) => r['merchant_id'] == arguments[0] && r['sha256_hash'] == arguments[1]).toList();
    }

    return rows;
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

  group('Advanced Evidence Extraction & SMS Intelligence', () {
    late InMemoryDatabaseDriver driver;
    late LocalEvidenceCaptureService evidenceService;
    late LocalCanonicalTransactionRepository txRepo;
    late StatementImportService statementService;
    const merchantId = 'merchant_test_001';

    setUp(() async {
      LocalDatabaseService.instance.reset();
      driver = InMemoryDatabaseDriver();
      await LocalDatabaseService.instance.initialize(customDriver: driver, customDbPath: ':memory:');
      evidenceService = LocalEvidenceCaptureService(dbService: LocalDatabaseService.instance);
      txRepo = LocalCanonicalTransactionRepository(dbService: LocalDatabaseService.instance);
      statementService = StatementImportService(dbService: LocalDatabaseService.instance, txRepo: txRepo);
    });

    test('1. Deterministic Extraction: Valid credit SMS with counterparty and UPI UTR', () {
      const sms = 'KAVITA SANDEEP PATHAK paid you ₹1.00 on PhonePe. UPI Ref: 432198765432';
      final details = evidenceService.extractFinancialDetails(
        text: sms,
        merchantId: merchantId,
      );

      expect(details.isEligibleTransaction, isTrue);
      expect(details.transactionType, equals('CREDIT'));
      expect(details.amount, equals('1.00'));
      expect(details.amountPaise, equals(100));
      expect(details.counterparty, equals('KAVITA SANDEEP PATHAK'));
      expect(details.referenceNumber, equals('432198765432'));
      expect(details.paymentMode, equals('UPI'));
    });

    test('2. Deterministic Extraction: Valid debit SMS with masked account and alias normalization', () {
      const sms = 'Your A/c XX4821 is debited by Rs. 450.50 on 14-Nov-26 transferred to AVENUE SUPERMARTS. Avail Bal: Rs. 15,200.00';
      final details = evidenceService.extractFinancialDetails(
        text: sms,
        merchantId: merchantId,
      );

      expect(details.isEligibleTransaction, isTrue);
      expect(details.transactionType, equals('DEBIT'));
      expect(details.amount, equals('450.50'));
      expect(details.amountPaise, equals(45050));
      expect(details.normalizedCounterparty, equals('DMart'));
      expect(details.assignedCategory, equals('Groceries & Provisions'));
      expect(details.maskedAccount, equals('XX4821'));
    });

    test('3. Non-transaction filtering: OTP, Balance Inquiry, and Failed Payments rejected', () {
      // OTP
      final otpDetails = evidenceService.extractFinancialDetails(
        text: 'Your OTP is 948201 for bank login. Do not share secret code with anyone.',
        merchantId: merchantId,
      );
      expect(otpDetails.isEligibleTransaction, isFalse);
      expect(otpDetails.rawClassification, equals('OTP'));

      // Balance-only
      final balDetails = evidenceService.extractFinancialDetails(
        text: 'Avail Bal in A/c XX9922 is Rs. 45,000.00 as of 14-Nov-26.',
        merchantId: merchantId,
      );
      expect(balDetails.isEligibleTransaction, isFalse);
      expect(balDetails.rawClassification, equals('BALANCE_ONLY'));

      // Failed Payment
      final failDetails = evidenceService.extractFinancialDetails(
        text: 'Transaction of Rs. 1,200.00 failed at merchant gateway due to bank timeout.',
        merchantId: merchantId,
      );
      expect(failDetails.isEligibleTransaction, isFalse);
      expect(failDetails.rawClassification, equals('FAILED'));
    });

    test('4. Integer Paise Arithmetic: Multi-format Indian currency parsing', () {
      final t1 = evidenceService.extractFinancialDetails(text: 'Paid ₹1.00', merchantId: merchantId);
      final t2 = evidenceService.extractFinancialDetails(text: 'Paid Rs. 450.50', merchantId: merchantId);
      final t3 = evidenceService.extractFinancialDetails(text: 'Transferred INR 1,25,000.75 to supplier', merchantId: merchantId);

      expect(t1.amountPaise, equals(100));
      expect(t2.amountPaise, equals(45050));
      expect(t3.amountPaise, equals(12500075));
    });

    test('5. Deletion Tombstones: Deleted transaction cannot be resurrected by re-scanned evidence', () async {
      // Create canonical transaction
      final tx = await txRepo.createTransaction(
        merchantId: merchantId,
        amount: '1200.00',
        transactionType: 'DEBIT',
        paymentMode: 'UPI',
        counterpartyName: 'Test Vendor',
        transactionReference: 'REF_998877',
        occurredAt: '2026-11-14T10:00:00Z',
      );

      // Verify created in DB
      final beforeDelete = await txRepo.getCanonicalTransactions(merchantId: merchantId);
      expect(beforeDelete.length, equals(1));

      // Merchant deletes transaction -> creates tombstone
      await txRepo.deleteTransactionWithTombstone(
        merchantId: merchantId,
        transactionId: tx.id,
        reason: 'MERCHANT_DELETED_INCORRECT_ENTRY',
      );

      final afterDelete = await txRepo.getCanonicalTransactions(merchantId: merchantId);
      expect(afterDelete.isEmpty, isTrue);

      // Attempt to re-ingest same raw SMS evidence
      final candidate = await evidenceService.ingestEvidenceAndExtract(
        merchantId: merchantId,
        filename: 'sms_001.txt',
        mimeType: 'text/plain',
        fileSizeBytes: 120,
        sha256Hash: 'hash_abc_123',
        storageRelativePath: 'evidence/sms_001.txt',
        sourceType: 'SMS',
        rawText: 'You paid Rs. 1200.00 to Test Vendor on 2026-11-14. UPI Ref: REF_998877',
        counterpartyName: 'Test Vendor',
      );

      // Tombstone blocks recreation: candidate is null
      expect(candidate, isNull);

      // Attempt to re-import through statement import
      final records = [
        ExtractedStatementRecord(
          date: '2026-11-14',
          description: 'Payment to Test Vendor',
          amount: '1200.00',
          type: 'DEBIT',
          reference: 'REF_998877',
          counterparty: 'Test Vendor',
        )
      ];

      final evaluated = await statementService.detectDuplicates(
        merchantId: merchantId,
        candidates: records,
      );

      expect(evaluated.first.isPossibleDuplicate, isTrue);
      expect(evaluated.first.duplicateReason, contains('tombstone active'));
      expect(evaluated.first.isSelected, isFalse);
    });

    test('6. User Categorization Memory (Tier 0 Override): Remembers merchant feedback', () async {
      // Store user override: map "XYZ STORE" to "Shree Ganesh Traders" as "Wholesale Procurement"
      await evidenceService.recordCounterpartyOverride(
        merchantId: merchantId,
        rawAlias: 'XYZ STORE',
        normalizedName: 'Shree Ganesh Traders',
        assignedCategory: 'Wholesale Procurement',
        applyToHistorical: false,
      );

      // Ingest evidence with "XYZ STORE"
      final candidate = await evidenceService.ingestEvidenceAndExtract(
        merchantId: merchantId,
        filename: 'sms_002.txt',
        mimeType: 'text/plain',
        fileSizeBytes: 150,
        sha256Hash: 'hash_xyz_789',
        storageRelativePath: 'evidence/sms_002.txt',
        sourceType: 'SMS',
        rawText: 'Paid Rs. 5,000.00 to XYZ STORE on 14-Nov-26 via UPI Ref: 5544332211',
      );

      expect(candidate, isNotNull);
      expect(candidate!.counterpartyName, equals('Shree Ganesh Traders'));

      final candidateRows = driver.tables[LocalDatabaseSchema.tableTransactionCandidates]!;
      expect(candidateRows.last['description'], contains('[Category: Wholesale Procurement]'));
    });
  });
}
