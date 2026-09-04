import '../../../core/api/api_client.dart';
import '../domain/financial_event_model.dart';
import '../domain/receivable_model.dart';

class EventRepository {
  final ApiClient _apiClient;

  EventRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

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

  Future<List<ReceivableModel>> getPrioritizedReceivables() async {
    final res = await _apiClient.get('/receivables/prioritized');
    final List list = res['data'] ?? [];
    return list.map((item) => ReceivableModel.fromJson(item)).toList();
  }
}
