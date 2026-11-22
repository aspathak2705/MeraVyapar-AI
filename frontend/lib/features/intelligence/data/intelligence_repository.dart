import '../../../core/api/api_client.dart';
import '../../../core/api/gateway_session_service.dart';
import '../domain/grounded_insight_model.dart';
import '../domain/merchant_insight_model.dart';

class IntelligenceRepository {
  final ApiClient _apiClient;
  final GatewaySessionService _gatewaySession;

  IntelligenceRepository({
    ApiClient? apiClient,
    GatewaySessionService? gatewaySession,
  })  : _apiClient = apiClient ?? ApiClient(),
        _gatewaySession =
            gatewaySession ?? GatewaySessionService(apiClient: apiClient);

  Future<GroundedInsightModel> explainEvent(String eventId) async {
    final authorization = await _gatewaySession.getAuthorizationHeader();
    final res = await _apiClient.post(
      '/financial-events/$eventId/explain',
      headers: {'Authorization': authorization},
    );
    return GroundedInsightModel.fromJson(res['data']);
  }

  Future<FinancialQueryResultModel> queryIntelligence({
    required String question,
    String? focusEntityId,
    Map<String, dynamic>? sanitizedContext,
    String? targetLanguage,
  }) async {
    final authorization = await _gatewaySession.getAuthorizationHeader();
    final res = await _apiClient.post(
      '/financial-intelligence/query',
      headers: {'Authorization': authorization},
      body: {
        'question': question,
        if (focusEntityId != null) 'focus_entity_id': focusEntityId,
        if (sanitizedContext != null) 'sanitized_context': sanitizedContext,
        if (targetLanguage != null) 'target_language': targetLanguage,
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
