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

  Future<List<MerchantMarketRelevanceModel>> getRelevantSignals(
      {String? query}) async {
    final path = (query != null && query.trim().isNotEmpty)
        ? '/market-intelligence/relevant?query=${Uri.encodeComponent(query.trim())}'
        : '/market-intelligence/relevant';
    final authorization = await _gatewaySession.getAuthorizationHeader();
    final res =
        await _apiClient.get(path, headers: {'Authorization': authorization});
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
