class CandidateLinkSummaryModel {
  final String id;
  final String transactionCandidateId;
  final String relationshipType;
  final String linkedAt;
  final String linkedBy;

  const CandidateLinkSummaryModel({
    required this.id,
    required this.transactionCandidateId,
    required this.relationshipType,
    required this.linkedAt,
    required this.linkedBy,
  });

  factory CandidateLinkSummaryModel.fromJson(Map<String, dynamic> json) {
    return CandidateLinkSummaryModel(
      id: json['id'],
      transactionCandidateId: json['transaction_candidate_id'],
      relationshipType: json['relationship_type'],
      linkedAt: json['linked_at'],
      linkedBy: json['linked_by'] ?? 'SYSTEM_RECONCILIATION',
    );
  }
}

class CanonicalTransactionModel {
  final String id;
  final String merchantId;
  final String? amount;
  final String currency;
  final String transactionType;
  final String paymentMode;
  final String? counterpartyName;
  final String? transactionReference;
  final String? description;
  final String? occurredAt;
  final String reconciliationStatus;
  final List<CandidateLinkSummaryModel> candidateLinks;

  const CanonicalTransactionModel({
    required this.id,
    required this.merchantId,
    this.amount,
    required this.currency,
    required this.transactionType,
    required this.paymentMode,
    this.counterpartyName,
    this.transactionReference,
    this.description,
    this.occurredAt,
    required this.reconciliationStatus,
    required this.candidateLinks,
  });

  factory CanonicalTransactionModel.fromJson(Map<String, dynamic> json) {
    final List linksJson = json['candidate_links'] ?? [];
    return CanonicalTransactionModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      amount: json['amount']?.toString(),
      currency: json['currency'] ?? 'INR',
      transactionType: json['transaction_type'] ?? 'UNKNOWN',
      paymentMode: json['payment_mode'] ?? 'UNKNOWN',
      counterpartyName: json['counterparty_name'],
      transactionReference: json['transaction_reference'],
      description: json['description'],
      occurredAt: json['occurred_at'],
      reconciliationStatus: json['reconciliation_status'] ?? 'UNRESOLVED',
      candidateLinks: linksJson.map((l) => CandidateLinkSummaryModel.fromJson(l)).toList(),
    );
  }
}
