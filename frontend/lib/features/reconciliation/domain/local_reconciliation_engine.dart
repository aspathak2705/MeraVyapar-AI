import 'package:uuid/uuid.dart';
import '../../core/database/local_database_service.dart';
import '../../core/database/local_database_schema.dart';
import '../../core/database/migration/migration_verification_service.dart';
import '../../evidence/domain/transaction_candidate_model.dart';
import '../../transactions/domain/canonical_transaction_model.dart';

enum MatchType { exact, probable, conflicting, unmatched }

class ReconciliationMatch {
  final MatchType type;
  final TransactionCandidateModel candidate;
  final CanonicalTransactionModel? existingTransaction;
  final double confidenceScore;
  final String explanation;

  const ReconciliationMatch({
    required this.type,
    required this.candidate,
    this.existingTransaction,
    required this.confidenceScore,
    required this.explanation,
  });
}

class ReconciliationResult {
  final List<ReconciliationMatch> matches;
  final int autoReconciledCount;
  final int reviewRequiredCount;

  const ReconciliationResult({
    required this.matches,
    required this.autoReconciledCount,
    required this.reviewRequiredCount,
  });
}

/// Deterministic, local-only reconciliation engine comparing transaction candidates
/// against confirmed canonical transactions in SQLite.
class LocalReconciliationEngine {
  final LocalDatabaseService _dbService;

  LocalReconciliationEngine({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Compares candidate against canonical transactions within a temporal window.
  Future<ReconciliationMatch> evaluateCandidate({
    required String merchantId,
    required TransactionCandidateModel candidate,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    if (candidate.amount == null) {
      return ReconciliationMatch(
        type: MatchType.unmatched,
        candidate: candidate,
        confidenceScore: 0.0,
        explanation: 'Candidate lacks explicit monetary amount',
      );
    }

    final candidatePaise = MigrationVerificationService.parseExactPaise(candidate.amount);

    // Query canonical transactions with identical amount and direction
    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ? AND transaction_type = ? AND amount_minor_units = ?
      ORDER BY occurred_at DESC
      ''',
      [merchantId, candidate.transactionType, candidatePaise],
    );

    if (rows.isEmpty) {
      return ReconciliationMatch(
        type: MatchType.unmatched,
        candidate: candidate,
        confidenceScore: 0.0,
        explanation: 'No existing transaction found matching amount and direction',
      );
    }

    // Evaluate potential matches
    for (final row in rows) {
      final existingUtr = row['transaction_reference'] as String?;
      final existingCp = (row['counterparty_name'] as String?)?.toLowerCase();
      final candCp = candidate.counterpartyName?.toLowerCase();

      final existingTx = CanonicalTransactionModel(
        id: row['id'] as String,
        merchantId: row['merchant_id'] as String,
        amount: ((row['amount_minor_units'] as int) / 100.0).toStringAsFixed(2),
        currency: row['currency'] as String? ?? 'INR',
        transactionType: row['transaction_type'] as String,
        paymentMode: row['payment_mode'] as String,
        counterpartyName: row['counterparty_name'] as String?,
        transactionReference: existingUtr,
        occurredAt: row['occurred_at'] as String?,
        reconciliationStatus: row['reconciliation_status'] as String? ?? 'UNRESOLVED',
        sourceType: row['source_type'] as String?,
        sourceProvider: row['source_provider'] as String?,
        isSimulated: false,
        candidateLinks: const [],
      );

      // 1. Strong Match: If UTR matches
      if (existingUtr != null && candidate.description != null && candidate.description!.contains(existingUtr)) {
        return ReconciliationMatch(
          type: MatchType.exact,
          candidate: candidate,
          existingTransaction: existingTx,
          confidenceScore: 1.0,
          explanation: 'Exact match on payment reference/UTR ($existingUtr)',
        );
      }

      // 2. Exact match: Amount, direction, and normalized counterparty
      if (existingCp != null && candCp != null && existingCp == candCp) {
        return ReconciliationMatch(
          type: MatchType.exact,
          candidate: candidate,
          existingTransaction: existingTx,
          confidenceScore: 1.0,
          explanation: 'Exact match on amount, direction, and counterparty',
        );
      }

      // 3. Probable match
      return ReconciliationMatch(
        type: MatchType.probable,
        candidate: candidate,
        existingTransaction: existingTx,
        confidenceScore: 0.75,
        explanation: 'Probable match on amount and type; counterparty needs review',
      );
    }

    return ReconciliationMatch(
      type: MatchType.unmatched,
      candidate: candidate,
      confidenceScore: 0.0,
      explanation: 'Unmatched candidate',
    );
  }

  /// Confirm candidate into canonical ledger atomically with cross-evidence idempotency protection.
  /// Updates candidate lifecycle state in SQLite.
  Future<CanonicalTransactionModel> confirmCandidateIntoLedger({
    required String merchantId,
    required TransactionCandidateModel candidate,
    String? counterpartyId,
    String? transactionReference,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final candidatePaise = MigrationVerificationService.parseExactPaise(candidate.amount);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Cross-evidence idempotency key construction:
    final idempotencyKey = transactionReference != null && transactionReference.isNotEmpty
        ? 'ref_${merchantId}_$transactionReference'
        : 'cand_${candidate.id}';

    // Check if canonical transaction already exists under this idempotency key
    final existingRows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE idempotency_key = ?
      ''',
      [idempotencyKey],
    );

    if (existingRows.isNotEmpty) {
      final row = existingRows.first;
      final existingId = row['id'] as String;

      // Update candidate status to CONFIRMED
      await driver.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableTransactionCandidates}
        SET lifecycle_status = 'CONFIRMED', reconciliation_match_id = ?, updated_at = ?
        WHERE id = ? AND merchant_id = ?
        ''',
        [existingId, nowIso, candidate.id, merchantId],
      );

      return CanonicalTransactionModel(
        id: existingId,
        merchantId: row['merchant_id'] as String,
        amount: ((row['amount_minor_units'] as int) / 100.0).toStringAsFixed(2),
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

    final txId = const Uuid().v4();

    // Execute ledger insert and candidate status update atomically inside transaction
    await driver.transaction((txn) async {
      await txn.execute(
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
          candidatePaise,
          candidate.currency,
          candidate.transactionType,
          candidate.paymentMode,
          candidate.counterpartyName,
          counterpartyId,
          transactionReference,
          candidate.description,
          candidate.transactionTimestamp ?? nowIso,
          'RECONCILED',
          'CANDIDATE_CONFIRMED',
          'LOCAL_RECONCILIATION',
          0,
          idempotencyKey,
          nowIso,
        ],
      );

      await txn.execute(
        '''
        UPDATE ${LocalDatabaseSchema.tableTransactionCandidates}
        SET lifecycle_status = 'CONFIRMED', reconciliation_match_id = ?, updated_at = ?
        WHERE id = ? AND merchant_id = ?
        ''',
        [txId, nowIso, candidate.id, merchantId],
      );
    });

    return CanonicalTransactionModel(
      id: txId,
      merchantId: merchantId,
      amount: candidate.amount,
      currency: candidate.currency,
      transactionType: candidate.transactionType,
      paymentMode: candidate.paymentMode,
      counterpartyName: candidate.counterpartyName,
      transactionReference: transactionReference,
      description: candidate.description,
      occurredAt: candidate.transactionTimestamp ?? nowIso,
      reconciliationStatus: 'RECONCILED',
      sourceType: 'CANDIDATE_CONFIRMED',
      sourceProvider: 'LOCAL_RECONCILIATION',
      isSimulated: false,
      candidateLinks: const [],
    );
  }
}
