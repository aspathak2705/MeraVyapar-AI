class EvidenceModel {
  final String id;
  final String merchantId;
  final String evidenceType;
  final String evidenceSource;
  final String evidenceStrength;
  final String? rawText;
  final Map<String, dynamic> metadataInfo;
  final String? storageObjectKey;
  final String? contentType;
  final String? originalFilename;
  final String processingStatus;
  final String receivedAt;

  const EvidenceModel({
    required this.id,
    required this.merchantId,
    required this.evidenceType,
    required this.evidenceSource,
    required this.evidenceStrength,
    this.rawText,
    required this.metadataInfo,
    this.storageObjectKey,
    this.contentType,
    this.originalFilename,
    required this.processingStatus,
    required this.receivedAt,
  });

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    return EvidenceModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      evidenceType: json['evidence_type'],
      evidenceSource: json['evidence_source'],
      evidenceStrength: json['evidence_strength'],
      rawText: json['raw_text'],
      metadataInfo: json['metadata_info'] ?? {},
      storageObjectKey: json['storage_object_key'],
      contentType: json['content_type'],
      originalFilename: json['original_filename'],
      processingStatus: json['processing_status'],
      receivedAt: json['received_at'],
    );
  }
}
