import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../local_database_service.dart';
import '../local_database_schema.dart';

class MigrationPreflightReport {
  final bool ready;
  final String sourceMerchantId;
  final int counterpartyCount;
  final int transactionCount;
  final int promiseCount;
  final int totalDebitMinor;
  final int totalCreditMinor;
  final int totalReceivableMinor;
  final int totalPayableMinor;
  final List<String> warnings;
  final List<String> validationErrors;

  const MigrationPreflightReport({
    required this.ready,
    required this.sourceMerchantId,
    required this.counterpartyCount,
    required this.transactionCount,
    required this.promiseCount,
    required this.totalDebitMinor,
    required this.totalCreditMinor,
    required this.totalReceivableMinor,
    required this.totalPayableMinor,
    required this.warnings,
    required this.validationErrors,
  });

  Map<String, dynamic> toJson() => {
        'ready': ready,
        'source_merchant_id': sourceMerchantId,
        'counterparty_count': counterpartyCount,
        'transaction_count': transactionCount,
        'promise_count': promiseCount,
        'total_debit_minor': totalDebitMinor,
        'total_credit_minor': totalCreditMinor,
        'total_receivable_minor': totalReceivableMinor,
        'total_payable_minor': totalPayableMinor,
        'warnings': warnings,
        'validation_errors': validationErrors,
      };
}

class MigrationVerificationResult {
  final bool verified;
  final int sourceRecordsCount;
  final int destinationRecordsCount;
  final bool amountsMatch;
  final bool foreignKeysIntact;
  final List<String> discrepancies;

  const MigrationVerificationResult({
    required this.verified,
    required this.sourceRecordsCount,
    required this.destinationRecordsCount,
    required this.amountsMatch,
    required this.foreignKeysIntact,
    required this.discrepancies,
  });
}

/// Service providing preflight validation, dry-run previews, and deep record-level verification.
class MigrationVerificationService {
  final LocalDatabaseService _dbService;

  MigrationVerificationService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Executes preflight analysis of an export JSON payload without writing to SQLite.
  MigrationPreflightReport preflightCheck(Map<String, dynamic> exportData) {
    final warnings = <String>[];
    final errors = <String>[];

    final merchant = exportData['merchant'] as Map<String, dynamic>?;
    if (merchant == null || merchant['id'] == null) {
      errors.add('Missing valid merchant profile in export payload');
    }
    final merchantId = merchant?['id']?.toString() ?? 'UNKNOWN';

    final counterparties = exportData['counterparties'] as List? ?? [];
    final transactions = exportData['transactions'] as List? ?? [];
    final promises = exportData['promises'] as List? ?? [];

    int totalDebit = 0;
    int totalCredit = 0;
    int totalReceivable = 0;
    int totalPayable = 0;

    // Validate Transactions
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i] as Map<String, dynamic>;
      final txId = tx['id'];
      if (txId == null) {
        errors.add('Transaction at index $i is missing unique ID');
      }

      int? minor;
      if (tx['amount_minor_units'] != null) {
        minor = tx['amount_minor_units'] as int;
      } else if (tx['amount'] != null) {
        final d = double.tryParse(tx['amount'].toString());
        if (d != null) {
          minor = (d * 100).round();
        }
      }

      if (minor == null) {
        errors.add('Transaction $txId has unparseable monetary amount');
      } else {
        final type = (tx['transaction_type'] ?? '').toString().toUpperCase();
        if (type == 'DEBIT') {
          totalDebit += minor;
        } else if (type == 'CREDIT') {
          totalCredit += minor;
        }
      }
    }

    // Validate Promises
    for (int i = 0; i < promises.length; i++) {
      final pr = promises[i] as Map<String, dynamic>;
      final prId = pr['id'];
      if (prId == null) {
        errors.add('Promise at index $i is missing unique ID');
      }

      int? minor;
      if (pr['amount_minor_units'] != null) {
        minor = pr['amount_minor_units'] as int;
      } else if (pr['amount'] != null) {
        final d = double.tryParse(pr['amount'].toString());
        if (d != null) {
          minor = (d * 100).round();
        }
      }

      if (minor == null) {
        errors.add('Promise $prId has unparseable monetary amount');
      } else {
        final dir = (pr['direction'] ?? '').toString().toUpperCase();
        if (dir == 'EXPECTED_INCOMING') {
          totalReceivable += minor;
        } else if (dir == 'EXPECTED_OUTGOING') {
          totalPayable += minor;
        }
      }
    }

    return MigrationPreflightReport(
      ready: errors.isEmpty,
      sourceMerchantId: merchantId,
      counterpartyCount: counterparties.length,
      transactionCount: transactions.length,
      promiseCount: promises.length,
      totalDebitMinor: totalDebit,
      totalCreditMinor: totalCredit,
      totalReceivableMinor: totalReceivable,
      totalPayableMinor: totalPayable,
      warnings: warnings,
      validationErrors: errors,
    );
  }

  /// Deep semantic verification comparing source payload with active SQLite database.
  Future<MigrationVerificationResult> verifyMigratedDatabase({
    required Map<String, dynamic> exportData,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      return const MigrationVerificationResult(
        verified: false,
        sourceRecordsCount: 0,
        destinationRecordsCount: 0,
        amountsMatch: false,
        foreignKeysIntact: false,
        discrepancies: ['Database driver not initialized'],
      );
    }

    final discrepancies = <String>[];
    final merchant = exportData['merchant'] as Map<String, dynamic>;
    final merchantId = merchant['id'] as String;

    // 1. Verify Transaction Counts & Amounts
    final sourceTxs = exportData['transactions'] as List? ?? [];
    final dbTxRows = await driver.query(
      '''
      SELECT id, amount_minor_units FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );

    if (sourceTxs.length != dbTxRows.length) {
      discrepancies.add(
        'Transaction count mismatch: source had ${sourceTxs.length}, database has ${dbTxRows.length}',
      );
    }

    final dbTxAmounts = {for (var r in dbTxRows) r['id'] as String: r['amount_minor_units'] as int?};
    for (final src in sourceTxs) {
      final srcId = src['id'] as String;
      final expectedMinor = src['amount_minor_units'] != null
          ? src['amount_minor_units'] as int
          : (double.parse(src['amount'].toString()) * 100).round();

      final actualMinor = dbTxAmounts[srcId];
      if (actualMinor == null) {
        discrepancies.add('Transaction $srcId missing from SQLite database');
      } else if (actualMinor != expectedMinor) {
        discrepancies.add('Transaction $srcId amount mismatch: expected $expectedMinor, got $actualMinor');
      }
    }

    // 2. Foreign Key Integrity Check
    final orphanTxs = await driver.query(
      '''
      SELECT t.id FROM ${LocalDatabaseSchema.tableCanonicalTransactions} t
      LEFT JOIN ${LocalDatabaseSchema.tableFinancialCounterparties} c ON t.counterparty_id = c.id
      WHERE t.counterparty_id IS NOT NULL AND c.id IS NULL
      ''',
    );
    if (orphanTxs.isNotEmpty) {
      discrepancies.add('Found ${orphanTxs.length} transactions referencing non-existent counterparties');
    }

    return MigrationVerificationResult(
      verified: discrepancies.isEmpty,
      sourceRecordsCount: sourceTxs.length,
      destinationRecordsCount: dbTxRows.length,
      amountsMatch: discrepancies.isEmpty,
      foreignKeysIntact: orphanTxs.isEmpty,
      discrepancies: discrepancies,
    );
  }
}
