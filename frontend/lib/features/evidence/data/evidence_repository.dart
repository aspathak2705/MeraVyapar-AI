import '../../../core/api/api_client.dart';
import '../domain/evidence_model.dart';
import '../domain/transaction_candidate_model.dart';

class EvidenceRepository {
  final ApiClient _apiClient;

  EvidenceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<EvidenceModel> submitManualEvidence({
    required String amount,
    required String transactionType,
    String? description,
    String? counterpartyName,
    String? paymentMode,
  }) async {
    final res = await _apiClient.post(
      '/evidence/manual',
      body: {
        'amount': amount,
        'currency': 'INR',
        'transaction_type': transactionType,
        if (description != null) 'description': description,
        if (counterpartyName != null) 'counterparty_name': counterpartyName,
        'payment_mode': paymentMode ?? 'UNKNOWN',
      },
    );
    return EvidenceModel.fromJson(res['data']);
  }

  Future<EvidenceModel> registerMobileEvidence({
    required String evidenceId,
    required String contentType,
    required String originalFilename,
    required int sizeBytes,
    required String clientSha256,
    String evidenceType = 'PAYMENT_SCREENSHOT',
    int storageVersion = 1,
    String? idempotencyKey,
  }) async {
    final res = await _apiClient.post(
      '/evidence/register',
      headers: idempotencyKey != null ? {'X-Idempotency-Key': idempotencyKey} : null,
      body: {
        'evidence_id': evidenceId,
        'evidence_type': evidenceType,
        'content_type': contentType,
        'original_filename': originalFilename,
        'size_bytes': sizeBytes,
        'client_sha256': clientSha256,
        'storage_version': storageVersion,
      },
    );
    return EvidenceModel.fromJson(res['data']);
  }

  Future<EvidenceModel> submitEvidenceExtraction({
    required String evidenceId,
    required String clientSha256,
    String? amount,
    String? transactionType,
    String? counterpartyName,
    String? paymentMode,
    String? referenceNumber,
    String? description,
    String? extractedText,
    String extractionEngine = 'TFLiteExtractionEngine',
    double? confidence,
  }) async {
    final res = await _apiClient.post(
      '/evidence/$evidenceId/extraction',
      body: {
        'client_sha256': clientSha256,
        if (amount != null) 'amount': amount,
        'currency': 'INR',
        if (transactionType != null) 'transaction_type': transactionType,
        if (counterpartyName != null) 'counterparty_name': counterpartyName,
        'payment_mode': paymentMode ?? 'UNKNOWN',
        if (referenceNumber != null) 'reference_number': referenceNumber,
        if (description != null) 'description': description,
        if (extractedText != null) 'extracted_text': extractedText,
        'extraction_engine': extractionEngine,
        if (confidence != null) 'confidence': confidence,
      },
    );
    return EvidenceModel.fromJson(res['data']);
  }

  Future<List<EvidenceModel>> getEvidenceList() async {
    final res = await _apiClient.get('/evidence');
    final List list = res['data'] ?? [];
    return list.map((item) => EvidenceModel.fromJson(item)).toList();
  }

  Future<List<TransactionCandidateModel>> getCandidateList() async {
    final res = await _apiClient.get('/transaction-candidates');
    final List list = res['data'] ?? [];
    return list.map((item) => TransactionCandidateModel.fromJson(item)).toList();
  }
}

