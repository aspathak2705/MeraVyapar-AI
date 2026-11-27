import '../../../core/api/api_client.dart';
import '../domain/merchant_insight_model.dart';

class IntelligenceRepository {
  final ApiClient _apiClient;

  IntelligenceRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<MerchantInsightItemModel>> listInsights({int skip = 0, int limit = 20}) async {
    final res = await _apiClient.get('/insights?skip=$skip&limit=$limit');
    final list = res['data'] as List? ?? [];
    return list.map((item) => MerchantInsightItemModel.fromJson(item)).toList();
  }

  Future<MerchantInsightItemModel> getInsightDetail(String insightId) async {
    final res = await _apiClient.get('/insights/$insightId');
    return MerchantInsightItemModel.fromJson(res['data']);
  }
}
