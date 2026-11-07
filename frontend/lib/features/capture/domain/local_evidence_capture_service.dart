import 'package:uuid/uuid.dart';
import '../../core/database/local_database_service.dart';
import '../../core/database/local_database_schema.dart';
import '../../core/database/migration/migration_verification_service.dart';
import '../domain/evidence_model.dart';
import '../domain/transaction_candidate_model.dart';

class LocalEvidenceCaptureService {
  final LocalDatabaseService _dbService;

  LocalEvidenceCaptureService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Ingest raw evidence metadata into local SQLite and extract a structured candidate.
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

    final evidenceId = const Uuid().v4();
    final candidateId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Persist Evidence Metadata Locally
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

    // 2. Deterministic Local Parsing
    String amountStr = declaredAmount ?? '0.00';
    String txType = declaredType ?? 'UNKNOWN';
    String? detectedCounterparty = counterpartyName;

    if (rawText != null && rawText.isNotEmpty) {
      final parsed = _parseNotificationText(rawText);
      if (parsed['amount'] != null) amountStr = parsed['amount']!;
      if (parsed['type'] != null) txType = parsed['type']!;
      if (parsed['counterparty'] != null && detectedCounterparty == null) {
        detectedCounterparty = parsed['counterparty'];
      }
    }

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
      description: 'Extracted from $sourceType: $filename',
      normalizationStatus: 'NORMALIZED',
      reviewStatus: 'NOT_REQUIRED',
    );
  }

  /// Rule-based regex extractor for Indian financial SMS / notification formats
  Map<String, String> _parseNotificationText(String text) {
    final result = <String, String>{};

    // Amount regex: matches Rs. 1500.00, INR 500, etc.
    final amtRegex = RegExp(r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final amtMatch = amtRegex.firstMatch(text);
    if (amtMatch != null) {
      result['amount'] = amtMatch.group(1)!.replaceAll(',', '');
    }

    // Direction regex
    final lower = text.toLowerCase();
    if (lower.contains('credited') || lower.contains('received')) {
      result['type'] = 'CREDIT';
    } else if (lower.contains('debited') || lower.contains('sent') || lower.contains('paid')) {
      result['type'] = 'DEBIT';
    }

    // Counterparty extraction heuristics (e.g. "VPA ...", "to XYZ", "from ABC")
    final cpRegex = RegExp(r'(?:to|from|by|at)\s+([A-Za-z0-9\s]+?)(?:\s+on|\s+ref|\s+upi|\.|$)', caseSensitive: false);
    final cpMatch = cpRegex.firstMatch(text);
    if (cpMatch != null) {
      result['counterparty'] = cpMatch.group(1)!.trim();
    }

    return result;
  }
}
