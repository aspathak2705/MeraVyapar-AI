import '../../../core/api/api_client.dart';
import '../domain/merchant_market_relevance_model.dart';

class MarketIntelligenceRepository {
  final ApiClient _apiClient;

  MarketIntelligenceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<MerchantMarketRelevanceModel>> getRelevantSignals() async {
    final res = await _apiClient.get('/market-intelligence/relevant');
    final List list = res['data'] ?? [];
    return list.map((item) => MerchantMarketRelevanceModel.fromJson(item)).toList();
  }
}
