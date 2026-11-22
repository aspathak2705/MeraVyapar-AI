import 'dart:convert';

/// Represents an intelligent local report generated and persisted on device SQLite.
class GeneratedReportModel {
  final String id;
  final String merchantId;
  final String reportType;
  final String title;
  final String summary;
  final String language;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const GeneratedReportModel({
    required this.id,
    required this.merchantId,
    required this.reportType,
    required this.title,
    required this.summary,
    required this.language,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'report_type': reportType,
      'title': title,
      'summary': summary,
      'language': language,
      'payload_json': jsonEncode(payload),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GeneratedReportModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    if (map['payload_json'] != null) {
      try {
        parsedPayload = jsonDecode(map['payload_json'] as String) as Map<String, dynamic>;
      } catch (_) {
        parsedPayload = {};
      }
    }

    return GeneratedReportModel(
      id: map['id'] as String,
      merchantId: map['merchant_id'] as String,
      reportType: map['report_type'] as String,
      title: map['title'] as String,
      summary: map['summary'] as String,
      language: (map['language'] as String?) ?? 'en',
      payload: parsedPayload,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
