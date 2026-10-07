class StoredEvidenceMetadata {
  static const int currentStorageVersion = 1;

  final String evidenceId;
  final String merchantId;
  final String originalFilename;
  final String contentType;
  final int sizeBytes;
  final String sha256Hash;
  final DateTime createdAt;
  final int storageVersion;

  const StoredEvidenceMetadata({
    required this.evidenceId,
    required this.merchantId,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256Hash,
    required this.createdAt,
    this.storageVersion = currentStorageVersion,
  });

  Map<String, dynamic> toJson() => {
        'evidence_id': evidenceId,
        'merchant_id': merchantId,
        'original_filename': originalFilename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'sha256_hash': sha256Hash,
        'created_at': createdAt.toUtc().toIso8601String(),
        'storage_version': storageVersion,
      };

  factory StoredEvidenceMetadata.fromJson(Map<String, dynamic> json) {
    return StoredEvidenceMetadata(
      evidenceId: json['evidence_id'] as String,
      merchantId: json['merchant_id'] as String,
      originalFilename: json['original_filename'] as String? ?? 'unknown',
      contentType: json['content_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      sha256Hash: json['sha256_hash'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      storageVersion: json['storage_version'] as int? ?? 1,
    );
  }
}
