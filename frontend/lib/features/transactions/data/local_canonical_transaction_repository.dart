import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../../core/money/money.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/database/local_database_schema.dart';
import '../domain/canonical_transaction_model.dart';

class LocalCanonicalTransactionRepository {
  final LocalDatabaseService _dbService;

  LocalCanonicalTransactionRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Fetch canonical transactions for the active merchant.
  Future<List<CanonicalTransactionModel>> getCanonicalTransactions({
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      return [];
    }

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ORDER BY occurred_at DESC, created_at DESC
      ''',
      [merchantId],
    );

    return rows.map((row) {
      final amountMinor = row['amount_minor_units'] as int?;
      final amountStr =
          amountMinor != null ? Money.formatPaise(amountMinor) : null;

      return CanonicalTransactionModel(
        id: row['id'] as String,
        merchantId: row['merchant_id'] as String,
        amount: amountStr,
        currency: row['currency'] as String? ?? 'INR',
        transactionType: row['transaction_type'] as String,
        paymentMode: row['payment_mode'] as String,
        counterpartyName: row['counterparty_name'] as String?,
        transactionReference: row['transaction_reference'] as String?,
        description: row['description'] as String?,
        occurredAt: row['occurred_at'] as String?,
        reconciliationStatus:
            row['reconciliation_status'] as String? ?? 'UNRESOLVED',
        sourceType: row['source_type'] as String?,
        sourceProvider: row['source_provider'] as String?,
        isSimulated: (row['is_simulated'] as int? ?? 0) == 1,
        candidateLinks: const [],
      );
    }).toList();
  }

  /// Create transaction with strict integer minor units and idempotency checking.
  Future<CanonicalTransactionModel> createTransaction({
    required String merchantId,
    required String amount,
    required String transactionType,
    required String paymentMode,
    String? counterpartyName,
    String? counterpartyId,
    String? transactionReference,
    String? description,
    String? occurredAt,
    String? idempotencyKey,
    String? sourceType = 'MANUAL',
    String? sourceProvider = 'LOCAL_ENTRY',
    bool isSimulated = false,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Database not initialized');
    }

    final int amountMinor;
    try {
      amountMinor = Money.parseInrToPaise(amount);
    } on FormatException catch (error) {
      throw ArgumentError(error.message);
    }
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final txId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final txOccurred = occurredAt ?? nowIso;
    final finalIdempotency = idempotencyKey ?? 'idemp_${const Uuid().v4()}';

    // Duplicate idempotency check
    final existing = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE idempotency_key = ?
      ''',
      [finalIdempotency],
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as String;
      final existingRows = await driver.query(
        '''
        SELECT * FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
        WHERE id = ? AND merchant_id = ?
        ''',
        [existingId, merchantId],
      );
      if (existingRows.isNotEmpty) {
        final row = existingRows.first;
        final existingMinor = row['amount_minor_units'] as int?;
        return CanonicalTransactionModel(
          id: row['id'] as String,
          merchantId: row['merchant_id'] as String,
          amount:
              existingMinor != null ? Money.formatPaise(existingMinor) : null,
          currency: row['currency'] as String? ?? 'INR',
          transactionType: row['transaction_type'] as String,
          paymentMode: row['payment_mode'] as String,
          counterpartyName: row['counterparty_name'] as String?,
          transactionReference: row['transaction_reference'] as String?,
          description: row['description'] as String?,
          occurredAt: row['occurred_at'] as String?,
          reconciliationStatus:
              row['reconciliation_status'] as String? ?? 'UNRESOLVED',
          sourceType: row['source_type'] as String?,
          sourceProvider: row['source_provider'] as String?,
          isSimulated: false,
          candidateLinks: const [],
        );
      }
    }

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableCanonicalTransactions} (
        id, merchant_id, amount_minor_units, currency, transaction_type,
        payment_mode, counterparty_name, counterparty_id, transaction_reference,
        description, occurred_at, reconciliation_status, source_type,
        source_provider, is_simulated, idempotency_key, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        txId,
        merchantId,
        amountMinor,
        'INR',
        transactionType,
        paymentMode,
        counterpartyName,
        counterpartyId,
        transactionReference,
        description,
        txOccurred,
        'UNRESOLVED',
        sourceType,
        sourceProvider ?? 'LOCAL_ENTRY',
        isSimulated ? 1 : 0,
        finalIdempotency,
        nowIso,
      ],
    );

    return CanonicalTransactionModel(
      id: txId,
      merchantId: merchantId,
      amount: Money.formatPaise(amountMinor),
      currency: 'INR',
      transactionType: transactionType,
      paymentMode: paymentMode,
      counterpartyName: counterpartyName,
      transactionReference: transactionReference,
      description: description,
      occurredAt: txOccurred,
      reconciliationStatus: 'UNRESOLVED',
      sourceType: sourceType,
      sourceProvider: sourceProvider ?? 'LOCAL_ENTRY',
      isSimulated: isSimulated,
      candidateLinks: const [],
    );
  }

  /// Delete canonical transaction and install evidence tombstone to prevent resurrection
  Future<void> deleteTransactionWithTombstone({
    required String merchantId,
    required String transactionId,
    String reason = 'MERCHANT_DELETED',
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database not initialized');

    final txRows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE id = ? AND merchant_id = ?
      ''',
      [transactionId, merchantId],
    );

    if (txRows.isEmpty) return;

    final row = txRows.first;
    final amountPaise = row['amount_minor_units'] as int? ?? 0;
    final direction = row['transaction_type'] as String? ?? 'UNKNOWN';
    final ref = row['transaction_reference'] as String?;
    final counterparty = row['counterparty_name'] as String?;

    // Compute fingerprint
    final rawFp =
        '$merchantId|$amountPaise|$direction|${ref ?? ''}|${counterparty?.toLowerCase() ?? ''}';
    final fp = sha256.convert(utf8.encode(rawFp)).toString();

    await driver.transaction((txn) async {
      // 1. Delete canonical transaction
      await txn.execute(
        '''
        DELETE FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
        WHERE id = ? AND merchant_id = ?
        ''',
        [transactionId, merchantId],
      );

      // 2. Insert deletion tombstone
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final tombstoneId = const Uuid().v4();
      await txn.execute(
        '''
        INSERT OR IGNORE INTO ${LocalDatabaseSchema.tableEvidenceTombstones} (
          id, merchant_id, evidence_fingerprint, source_reference, reason, created_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [tombstoneId, merchantId, fp, ref, reason, nowIso],
      );
    });
  }

  /// Get total count of canonical transactions for merchant.
  Future<int> getTransactionCount({required String merchantId}) async {
    final driver = _dbService.driver;
    if (driver == null) return 0;

    final rows = await driver.query(
      '''
      SELECT COUNT(*) as count FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );

    return rows.isNotEmpty ? (rows.first['count'] as int? ?? 0) : 0;
  }
}
