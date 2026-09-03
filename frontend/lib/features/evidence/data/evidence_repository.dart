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
