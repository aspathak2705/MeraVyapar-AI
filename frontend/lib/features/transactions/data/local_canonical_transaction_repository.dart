import 'package:uuid/uuid.dart';
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
      final amountStr = amountMinor != null
          ? (amountMinor / 100.0).toStringAsFixed(2)
          : null;

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
        reconciliationStatus: row['reconciliation_status'] as String? ?? 'UNRESOLVED',
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
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      throw StateError('Database not initialized');
    }

    // Exact minor unit calculation (paise)
    final doubleAmount = double.tryParse(amount);
    if (doubleAmount == null) {
      throw ArgumentError('Invalid monetary amount format: $amount');
    }
    final int amountMinor = (doubleAmount * 100).round();

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
          amount: existingMinor != null ? (existingMinor / 100.0).toStringAsFixed(2) : null,
          currency: row['currency'] as String? ?? 'INR',
          transactionType: row['transaction_type'] as String,
          paymentMode: row['payment_mode'] as String,
          counterpartyName: row['counterparty_name'] as String?,
          transactionReference: row['transaction_reference'] as String?,
          description: row['description'] as String?,
          occurredAt: row['occurred_at'] as String?,
          reconciliationStatus: row['reconciliation_status'] as String? ?? 'UNRESOLVED',
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
        'LOCAL_ENTRY',
        0,
        finalIdempotency,
        nowIso,
      ],
    );

    return CanonicalTransactionModel(
      id: txId,
      merchantId: merchantId,
      amount: (amountMinor / 100.0).toStringAsFixed(2),
      currency: 'INR',
      transactionType: transactionType,
      paymentMode: paymentMode,
      counterpartyName: counterpartyName,
      transactionReference: transactionReference,
      description: description,
      occurredAt: txOccurred,
      reconciliationStatus: 'UNRESOLVED',
      sourceType: sourceType,
      sourceProvider: 'LOCAL_ENTRY',
      isSimulated: false,
      candidateLinks: const [],
    );
  }
}
