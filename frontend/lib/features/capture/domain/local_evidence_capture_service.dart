import 'package:uuid/uuid.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../../../core/database/migration/migration_verification_service.dart';
import '../../evidence/domain/transaction_candidate_model.dart';

class LocalEvidenceCaptureService {
  final LocalDatabaseService _dbService;

  LocalEvidenceCaptureService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Ingest raw evidence metadata into local SQLite and persist an extracted candidate.
  Future<TransactionCandidateModel> ingestEvidenceAndExtract({
    required String merchantId,
    required String filename,
    required String mimeType,
    required int fileSizeBytes,
    required String sha256Hash,
    required String storageRelativePath,
    required String sourceType, // 'SMS', 'STATEMENT', 'MANUAL', 'NOTIFICATION'
    String? rawText,
    String? declaredAmount,
    String? declaredType,
    String? counterpartyName,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final candidateId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Idempotent Evidence Ingestion: Check if sha256 already exists for this merchant
    final existingEvidence = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableEvidenceMetadata}
      WHERE merchant_id = ? AND sha256_hash = ?
      ''',
      [merchantId, sha256Hash],
    );

    String evidenceId;
    if (existingEvidence.isNotEmpty) {
      evidenceId = existingEvidence.first['id'] as String;
    } else {
      evidenceId = const Uuid().v4();
      await driver.execute(
        '''
        INSERT INTO ${LocalDatabaseSchema.tableEvidenceMetadata} (
          id, merchant_id, filename, mime_type, file_size_bytes,
          sha256_hash, storage_relative_path, captured_at, source_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          evidenceId,
          merchantId,
          filename,
          mimeType,
          fileSizeBytes,
          sha256Hash,
          storageRelativePath,
          nowIso,
          sourceType,
        ],
      );
    }

    // 2. Deterministic Local Parsing
    String amountStr = declaredAmount ?? '0.00';
    String txType = declaredType ?? 'UNKNOWN';
    String? detectedCounterparty = counterpartyName;
    String? referenceNumber;

    if (rawText != null && rawText.isNotEmpty) {
      final parsed = _parseNotificationText(rawText);
      if (parsed['amount'] != null) amountStr = parsed['amount']!;
      if (parsed['type'] != null) txType = parsed['type']!;
      if (parsed['counterparty'] != null && detectedCounterparty == null) {
        detectedCounterparty = parsed['counterparty'];
      }
      if (parsed['reference'] != null) {
        referenceNumber = parsed['reference'];
      }
    }

    int candidatePaise = 0;
    try {
      candidatePaise = MigrationVerificationService.parseExactPaise(amountStr);
    } catch (_) {
      candidatePaise = 0;
    }

    final candidateDescription = referenceNumber != null
        ? 'Ref: $referenceNumber | Extracted from $sourceType: $filename'
        : 'Extracted from $sourceType: $filename';

    // 3. Persist Candidate into SQLite for crash resilience
    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableTransactionCandidates} (
        id, merchant_id, primary_evidence_id, transaction_type,
        amount_minor_units, currency, transaction_timestamp,
        counterparty_name, payment_mode, description,
        lifecycle_status, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        candidateId,
        merchantId,
        evidenceId,
        txType,
        candidatePaise,
        'INR',
        nowIso,
        detectedCounterparty,
        sourceType == 'SMS' ? 'UPI' : 'UNKNOWN',
        candidateDescription,
        'EXTRACTED',
        nowIso,
        nowIso,
      ],
    );

    return TransactionCandidateModel(
      id: candidateId,
      merchantId: merchantId,
      primaryEvidenceId: evidenceId,
      transactionType: txType,
      amount: amountStr,
      currency: 'INR',
      transactionTimestamp: nowIso,
      counterpartyName: detectedCounterparty,
      paymentMode: sourceType == 'SMS' ? 'UPI' : 'UNKNOWN',
      description: candidateDescription,
      normalizationStatus: 'NORMALIZED',
      reviewStatus: 'NOT_REQUIRED',
    );
  }

  /// Rule-based regex extractor for Indian financial SMS / notification formats
  /// Correctly distinguishes actual transactions from available balances.
  Map<String, String> _parseNotificationText(String text) {
    final result = <String, String>{};

    // 1. Check for failure or reversal
    final lower = text.toLowerCase();
    if (lower.contains('failed') || lower.contains('declined') || lower.contains('unsuccessful')) {
      return result; // Reject failed transactions from candidate creation
    }

    // 2. Extract transaction amount (ignore "Avail Bal", "Bal Rs.", "Balance:")
    final txAmtRegex = RegExp(
      r'(?:debited(?:\s+by)?|credited(?:\s+with)?|paid|received|sent|transferred|spent)\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final txMatch = txAmtRegex.firstMatch(text);

    if (txMatch != null) {
      result['amount'] = txMatch.group(1)!.replaceAll(',', '');
    } else {
      // Fallback: match currency amount not preceded by balance keywords
      final generalAmtRegex = RegExp(r'(?<!bal(?:ance)?[\s\:\.]*)(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
      final generalMatch = generalAmtRegex.firstMatch(text);
      if (generalMatch != null) {
        result['amount'] = generalMatch.group(1)!.replaceAll(',', '');
      }
    }

    // 3. Direction regex
    if (lower.contains('credited') || lower.contains('received') || lower.contains('deposited') || lower.contains('refunded')) {
      result['type'] = 'CREDIT';
    } else if (lower.contains('debited') || lower.contains('sent') || lower.contains('paid') || lower.contains('withdrawn')) {
      result['type'] = 'DEBIT';
    }

    // 4. Reference / UTR extraction
    final utrRegex = RegExp(r'(?:UPI\s*Ref(?:\s*no)?|Ref(?:\s*no)?|UTR(?:\s*no)?|Txn\s*ID)\s*[:\s]*([A-Za-z0-9]+)', caseSensitive: false);
    final utrMatch = utrRegex.firstMatch(text);
    if (utrMatch != null) {
      result['reference'] = utrMatch.group(1)!.trim();
    }

    // 5. Counterparty extraction
    final cpRegex = RegExp(r'(?:to|from|by|at|VPA)\s+([A-Za-z0-9\.\@\s]{3,35}?)(?:\s+on|\s+ref|\s+upi|\s+avl|\.|$)', caseSensitive: false);
    final cpMatch = cpRegex.firstMatch(text);
    if (cpMatch != null) {
      final cpCandidate = cpMatch.group(1)!.trim();
      if (!cpCandidate.toLowerCase().contains('account') && !cpCandidate.toLowerCase().contains('your')) {
        result['counterparty'] = cpCandidate;
      }
    }

    return result;
  }
}
