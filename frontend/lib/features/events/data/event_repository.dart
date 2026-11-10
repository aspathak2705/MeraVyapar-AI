import '../../../core/api/api_client.dart';
import '../../intelligence/domain/local_financial_intelligence_engine.dart';
import '../domain/financial_event_model.dart';
import '../domain/receivable_model.dart';

class EventRepository {
  final ApiClient _apiClient;
  final LocalFinancialIntelligenceEngine _localEngine;

  EventRepository({
    ApiClient? apiClient,
    LocalFinancialIntelligenceEngine? localEngine,
  })  : _apiClient = apiClient ?? ApiClient(),
        _localEngine = localEngine ?? LocalFinancialIntelligenceEngine();

  Future<void> evaluateEvents() async {
    await _apiClient.post('/events/evaluate');
  }

  Future<List<FinancialEventModel>> getEvents({String? status}) async {
    final path = status != null ? '/events?status=$status' : '/events';
    final res = await _apiClient.get(path);
    final List list = res['data'] ?? [];
    return list.map((item) => FinancialEventModel.fromJson(item)).toList();
  }

  Future<FinancialEventModel> acknowledgeEvent(String eventId) async {
    final res = await _apiClient.post('/events/$eventId/acknowledge');
    return FinancialEventModel.fromJson(res['data']);
  }

  Future<FinancialEventModel> dismissEvent(String eventId) async {
    final res = await _apiClient.post('/events/$eventId/dismiss');
    return FinancialEventModel.fromJson(res['data']);
  }

  /// Fetch prioritized receivables from local SQLite engine for the active merchant.
  /// Fully operational offline.
  Future<List<ReceivableModel>> getPrioritizedReceivables({String? merchantId}) async {
    if (merchantId != null && merchantId.isNotEmpty) {
      final localMaps = await _localEngine.getPrioritizedReceivables(merchantId: merchantId);
      return localMaps.map((m) => ReceivableModel.fromJson(m)).toList();
    }

    try {
      final res = await _apiClient.get('/receivables/prioritized');
      final List list = res['data'] ?? [];
      return list.map((item) => ReceivableModel.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }
}
