import '../../../core/api/api_client.dart';
import '../domain/canonical_transaction_model.dart';

class CanonicalTransactionRepository {
  final ApiClient _apiClient;

  CanonicalTransactionRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<CanonicalTransactionModel>> getCanonicalTransactions() async {
    final res = await _apiClient.get('/canonical-transactions');
    final List list = res['data'] ?? [];
    return list.map((item) => CanonicalTransactionModel.fromJson(item)).toList();
  }

  Future<CanonicalTransactionModel> getCanonicalTransactionDetail(String id) async {
    final res = await _apiClient.get('/canonical-transactions/$id');
    return CanonicalTransactionModel.fromJson(res['data']);
  }

  Future<Map<String, dynamic>> runReconciliation() async {
    final res = await _apiClient.post('/reconciliation/run');
    return res['data'] ?? {};
  }
}
