class PaymentPromiseEventModel {
  final String id;
  final String eventType;
  final Map<String, dynamic> previousSnapshot;
  final Map<String, dynamic> newSnapshot;
  final DateTime occurredAt;
  final DateTime createdAt;

  const PaymentPromiseEventModel({
    required this.id,
    required this.eventType,
    required this.previousSnapshot,
    required this.newSnapshot,
    required this.occurredAt,
    required this.createdAt,
  });

  factory PaymentPromiseEventModel.fromJson(Map<String, dynamic> json) {
    return PaymentPromiseEventModel(
      id: json['id'],
      eventType: json['event_type'],
      previousSnapshot: json['previous_snapshot'] ?? {},
      newSnapshot: json['new_snapshot'] ?? {},
      occurredAt: DateTime.parse(json['occurred_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class PaymentPromiseModel {
  final String id;
  final String merchantId;
  final String? counterpartyId;
  final String description;
  final String promisedAmount;
  final String currency;
  final String promiseDirection;
  final DateTime dueAt;
  final String status;
  final String source;
  final String? sourceReference;
  final DateTime? fulfilledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PaymentPromiseEventModel> events;

  const PaymentPromiseModel({
    required this.id,
    required this.merchantId,
    this.counterpartyId,
    required this.description,
    required this.promisedAmount,
    required this.currency,
    required this.promiseDirection,
    required this.dueAt,
    required this.status,
    required this.source,
    this.sourceReference,
    this.fulfilledAt,
    required this.createdAt,
    required this.updatedAt,
    required this.events,
  });

  factory PaymentPromiseModel.fromJson(Map<String, dynamic> json) {
    final evList = json['events'] as List? ?? [];
    return PaymentPromiseModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      counterpartyId: json['counterparty_id'],
      description: json['description'],
      promisedAmount: json['promised_amount'].toString(),
      currency: json['currency'] ?? 'INR',
      promiseDirection: json['promise_direction'] ?? 'EXPECTED_INCOMING',
      dueAt: DateTime.parse(json['due_at']),
      status: json['status'] ?? 'OPEN',
      source: json['source'] ?? 'MERCHANT_DECLARED',
      sourceReference: json['source_reference'],
      fulfilledAt: json['fulfilled_at'] != null ? DateTime.parse(json['fulfilled_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      events: evList.map((e) => PaymentPromiseEventModel.fromJson(e)).toList(),
    );
  }
}
