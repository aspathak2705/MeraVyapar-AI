class FinancialEventModel {
  final String id;
  final String merchantId;
  final String eventType;
  final String severity;
  final String status;
  final String title;
  final String summary;
  final DateTime occurredAt;
  final DateTime detectedAt;
  final String sourceEntityType;
  final String? sourceEntityId;
  final String? deduplicationKey;
  final Map<String, dynamic> metadataInfo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialEventModel({
    required this.id,
    required this.merchantId,
    required this.eventType,
    required this.severity,
    required this.status,
    required this.title,
    required this.summary,
    required this.occurredAt,
    required this.detectedAt,
    required this.sourceEntityType,
    this.sourceEntityId,
    this.deduplicationKey,
    required this.metadataInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinancialEventModel.fromJson(Map<String, dynamic> json) {
    return FinancialEventModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      eventType: json['event_type'],
      severity: json['severity'] ?? 'INFO',
      status: json['status'] ?? 'ACTIVE',
      title: json['title'],
      summary: json['summary'],
      occurredAt: DateTime.parse(json['occurred_at']),
      detectedAt: DateTime.parse(json['detected_at']),
      sourceEntityType: json['source_entity_type'],
      sourceEntityId: json['source_entity_id'],
      deduplicationKey: json['deduplication_key'],
      metadataInfo: json['metadata_info'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
