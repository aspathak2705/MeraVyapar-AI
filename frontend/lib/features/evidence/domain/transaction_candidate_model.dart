class TransactionCandidateModel {
  final String id;
  final String merchantId;
  final String primaryEvidenceId;
  final String transactionType;
  final String? amount;
  final String currency;
  final String? transactionTimestamp;
  final String? counterpartyName;
  final String paymentMode;
  final String? description;
  final String normalizationStatus;
  final String reviewStatus;

  const TransactionCandidateModel({
    required this.id,
    required this.merchantId,
    required this.primaryEvidenceId,
    required this.transactionType,
    this.amount,
    required this.currency,
    this.transactionTimestamp,
    this.counterpartyName,
    required this.paymentMode,
    this.description,
    required this.normalizationStatus,
    required this.reviewStatus,
  });

  factory TransactionCandidateModel.fromJson(Map<String, dynamic> json) {
    return TransactionCandidateModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      primaryEvidenceId: json['primary_evidence_id'],
      transactionType: json['transaction_type'],
      amount: json['amount']?.toString(),
      currency: json['currency'] ?? 'INR',
      transactionTimestamp: json['transaction_timestamp'],
      counterpartyName: json['counterparty_name'],
      paymentMode: json['payment_mode'] ?? 'UNKNOWN',
      description: json['description'],
      normalizationStatus: json['normalization_status'] ?? 'PENDING',
      reviewStatus: json['review_status'] ?? 'NOT_REQUIRED',
    );
  }
}
