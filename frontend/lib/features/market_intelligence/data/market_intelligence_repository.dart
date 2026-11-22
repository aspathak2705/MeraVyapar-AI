import '../../../core/api/api_client.dart';
import '../../../core/api/gateway_session_service.dart';
import '../domain/merchant_market_relevance_model.dart';

class MarketIntelligenceRepository {
  final ApiClient _apiClient;
  final GatewaySessionService _gatewaySession;

  MarketIntelligenceRepository(
      {ApiClient? apiClient, GatewaySessionService? gatewaySession})
      : _apiClient = apiClient ?? ApiClient(),
        _gatewaySession =
            gatewaySession ?? GatewaySessionService(apiClient: apiClient);

  Future<List<MerchantMarketRelevanceModel>> getRelevantSignals({
    String? query,
    String? category,
    String? businessType,
    String? city,
    String? state,
    String? engine,
    String? mapsType,
    String? placeId,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) params['query'] = query.trim();
    if (category != null && category.trim().isNotEmpty) params['category'] = category.trim();
    if (businessType != null && businessType.trim().isNotEmpty) params['business_type'] = businessType.trim();
    if (city != null && city.trim().isNotEmpty) params['city'] = city.trim();
    if (state != null && state.trim().isNotEmpty) params['state'] = state.trim();
    if (engine != null && engine.trim().isNotEmpty) params['engine'] = engine.trim();
    if (mapsType != null && mapsType.trim().isNotEmpty) params['maps_type'] = mapsType.trim();
    if (placeId != null && placeId.trim().isNotEmpty) params['place_id'] = placeId.trim();

    final uri = Uri(
      path: '/market-intelligence/relevant',
      queryParameters: params.isNotEmpty ? params : null,
    );
    final authorization = await _gatewaySession.getAuthorizationHeader();
    final res =
        await _apiClient.get(uri.toString(), headers: {'Authorization': authorization});
    final message = (res['message'] as String? ?? '').toLowerCase();
    if (message.contains('provider not configured')) {
      throw StateError(
          'SerpApi is not configured on the market intelligence gateway.');
    }
    final List list = res['data'] ?? [];
    return list
        .map((item) => MerchantMarketRelevanceModel.fromJson(item))
        .toList();
  }
}
