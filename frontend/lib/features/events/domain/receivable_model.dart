class ReceivableModel {
  final String receivableId;
  final String? counterpartyId;
  final String? counterpartyName;
  final String amount;
  final String currency;
  final DateTime dueAt;
  final String state; // PENDING, DUE_SOON, OVERDUE, SETTLED
  final String priority; // HIGH, MEDIUM, LOW
  final List<String> reasonCodes;
  final String sourcePaymentPromiseId;

  const ReceivableModel({
    required this.receivableId,
    this.counterpartyId,
    this.counterpartyName,
    required this.amount,
    required this.currency,
    required this.dueAt,
    required this.state,
    required this.priority,
    required this.reasonCodes,
    required this.sourcePaymentPromiseId,
  });

  factory ReceivableModel.fromJson(Map<String, dynamic> json) {
    final reasons = json['reason_codes'] as List? ?? [];
    return ReceivableModel(
      receivableId: json['receivable_id'],
      counterpartyId: json['counterparty_id'],
      counterpartyName: json['counterparty_name'],
      amount: json['amount'].toString(),
      currency: json['currency'] ?? 'INR',
      dueAt: DateTime.parse(json['due_at']),
      state: json['state'] ?? 'PENDING',
      priority: json['priority'] ?? 'LOW',
      reasonCodes: reasons.map((r) => r.toString()).toList(),
      sourcePaymentPromiseId: json['source_payment_promise_id'],
    );
  }
}
