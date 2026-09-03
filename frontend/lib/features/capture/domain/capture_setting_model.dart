class CaptureSourceSettingModel {
  final String id;
  final String merchantId;
  final String sourceType;
  final String providerIdentifier;
  final bool enabled;

  const CaptureSourceSettingModel({
    required this.id,
    required this.merchantId,
    required this.sourceType,
    required this.providerIdentifier,
    required this.enabled,
  });

  factory CaptureSourceSettingModel.fromJson(Map<String, dynamic> json) {
    return CaptureSourceSettingModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      sourceType: json['source_type'],
      providerIdentifier: json['provider_identifier'],
      enabled: json['enabled'] ?? true,
    );
  }
}
