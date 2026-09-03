import '../../../core/api/api_client.dart';
import '../domain/counterparty_model.dart';
import '../domain/payment_promise_model.dart';

class MemoryRepository {
  final ApiClient _apiClient;

  MemoryRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<CounterpartyModel>> getCounterparties() async {
    final res = await _apiClient.get('/counterparties');
    final List list = res['data'] ?? [];
    return list.map((item) => CounterpartyModel.fromJson(item)).toList();
  }

  Future<CounterpartyModel> getCounterpartyDetail(String id) async {
    final res = await _apiClient.get('/counterparties/$id');
    return CounterpartyModel.fromJson(res['data']);
  }

  Future<List<FinancialRelationshipEventModel>> getCounterpartyTimeline(String id) async {
    final res = await _apiClient.get('/counterparties/$id/timeline');
    final List list = res['data'] ?? [];
    return list.map((item) => FinancialRelationshipEventModel.fromJson(item)).toList();
  }

  Future<List<PaymentPromiseModel>> getPaymentPromises({String? status}) async {
    final path = status != null ? '/payment-promises?status=$status' : '/payment-promises';
    final res = await _apiClient.get(path);
    final List list = res['data'] ?? [];
    return list.map((item) => PaymentPromiseModel.fromJson(item)).toList();
  }

  Future<PaymentPromiseModel> createPaymentPromise({
    String? counterpartyId,
    required String description,
    required String promisedAmount,
    required String promiseDirection,
    required String dueAt,
  }) async {
    final res = await _apiClient.post(
      '/payment-promises',
      body: {
        if (counterpartyId != null) 'counterparty_id': counterpartyId,
        'description': description,
        'promised_amount': promisedAmount,
        'promise_direction': promiseDirection,
        'due_at': dueAt,
        'source': 'MERCHANT_DECLARED',
      },
    );
    return PaymentPromiseModel.fromJson(res['data']);
  }

  Future<PaymentPromiseModel> fulfillPromise(String promiseId, {String? fulfillmentReference}) async {
    final res = await _apiClient.post(
      '/payment-promises/$promiseId/fulfill',
      body: {
        if (fulfillmentReference != null) 'fulfillment_reference': fulfillmentReference,
      },
    );
    return PaymentPromiseModel.fromJson(res['data']);
  }
}
