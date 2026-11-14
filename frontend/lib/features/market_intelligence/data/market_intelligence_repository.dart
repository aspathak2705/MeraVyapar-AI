import '../../../core/api/api_client.dart';
import '../domain/merchant_market_relevance_model.dart';

class MarketIntelligenceRepository {
  final ApiClient _apiClient;

  MarketIntelligenceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<MerchantMarketRelevanceModel>> getRelevantSignals({String? query}) async {
    final path = (query != null && query.trim().isNotEmpty)
        ? '/market-intelligence/relevant?query=${Uri.encodeComponent(query.trim())}'
        : '/market-intelligence/relevant';
    final res = await _apiClient.get(path);
    final List list = res['data'] ?? [];
    return list.map((item) => MerchantMarketRelevanceModel.fromJson(item)).toList();
  }
}
