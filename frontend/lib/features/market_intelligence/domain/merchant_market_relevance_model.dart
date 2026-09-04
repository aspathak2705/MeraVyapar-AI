import 'market_event_model.dart';

class MerchantMarketRelevanceModel {
  final String id;
  final String merchantId;
  final String marketEventId;
  final String relevanceStatus; // POTENTIALLY_RELEVANT, REQUIRES_MORE_CONTEXT, NOT_RELEVANT
  final List<String> reasonCodes;
  final String? explanation;
  final Map<String, dynamic> contextSnapshot;
  final DateTime detectedAt;
  final MarketEventModel? marketEvent;

  const MerchantMarketRelevanceModel({
    required this.id,
    required this.merchantId,
    required this.marketEventId,
    required this.relevanceStatus,
    required this.reasonCodes,
    this.explanation,
    required this.contextSnapshot,
    required this.detectedAt,
    this.marketEvent,
  });

  factory MerchantMarketRelevanceModel.fromJson(Map<String, dynamic> json) {
    final reasons = (json['reason_codes'] as List? ?? []).map((r) => r.toString()).toList();
    return MerchantMarketRelevanceModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      marketEventId: json['market_event_id'],
      relevanceStatus: json['relevance_status'] ?? 'NOT_RELEVANT',
      reasonCodes: reasons,
      explanation: json['explanation'],
      contextSnapshot: json['context_snapshot'] ?? {},
      detectedAt: DateTime.parse(json['detected_at']),
      marketEvent: json['market_event'] != null ? MarketEventModel.fromJson(json['market_event']) : null,
    );
  }
}
