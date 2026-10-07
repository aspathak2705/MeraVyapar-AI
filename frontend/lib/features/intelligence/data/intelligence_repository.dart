import '../../../core/api/api_client.dart';
import '../domain/grounded_insight_model.dart';
import '../domain/merchant_insight_model.dart';

class IntelligenceRepository {
  final ApiClient _apiClient;

  IntelligenceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<GroundedInsightModel> explainEvent(String eventId) async {
    final res = await _apiClient.post('/financial-events/$eventId/explain');
    return GroundedInsightModel.fromJson(res['data']);
  }

  Future<FinancialQueryResultModel> queryIntelligence({
    required String question,
    String? focusEntityId,
  }) async {
    final res = await _apiClient.post(
      '/financial-intelligence/query',
      body: {
        'question': question,
        if (focusEntityId != null) 'focus_entity_id': focusEntityId,
      },
    );
    return FinancialQueryResultModel.fromJson(res['data']);
  }

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
