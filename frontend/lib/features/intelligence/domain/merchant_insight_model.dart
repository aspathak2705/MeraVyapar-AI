class ExternalSignalDetailModel {
  final String evidenceId;
  final String? sourceName;
  final String? engine;
  final String? title;
  final String? snippet;
  final String? sourceUrl;
  final String? price;
  final double? rating;
  final String? location;
  final String? claim;

  const ExternalSignalDetailModel({
    required this.evidenceId,
    this.sourceName,
    this.engine,
    this.title,
    this.snippet,
    this.sourceUrl,
    this.price,
    this.rating,
    this.location,
    this.claim,
  });

  factory ExternalSignalDetailModel.fromJson(Map<String, dynamic> json) {
    return ExternalSignalDetailModel(
      evidenceId: json['evidence_id'] ?? '',
      sourceName: json['source_name'],
      engine: json['engine'],
      title: json['title'],
      snippet: json['snippet'],
      sourceUrl: json['source_url'],
      price: json['price'],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      location: json['location'],
      claim: json['claim'],
    );
  }
}

class InternalFactDetailModel {
  final String factId;
  final String label;
  final String value;
  final String metricName;
  final String? currentValue;
  final String? comparisonValue;
  final String? percentageChange;

  const InternalFactDetailModel({
    required this.factId,
    required this.label,
    required this.value,
    required this.metricName,
    this.currentValue,
    this.comparisonValue,
    this.percentageChange,
  });

  factory InternalFactDetailModel.fromJson(Map<String, dynamic> json) {
    return InternalFactDetailModel(
      factId: json['fact_id'] ?? '',
      label: json['label'] ?? '',
      value: json['value'] ?? '',
      metricName: json['metric_name'] ?? '',
      currentValue: json['current_value'],
      comparisonValue: json['comparison_value'],
      percentageChange: json['percentage_change'],
    );
  }
}

class MerchantInsightItemModel {
  final String id;
  final String insightType;
  final String title;
  final String summary;
  final List<InternalFactDetailModel> financialFacts;
  final List<ExternalSignalDetailModel> externalSignals;
  final String interpretation;
  final String groundingStatus;
  final List<String> evidenceReferences;
  final List<String> limitations;
  final String? focusEntityId;
  final DateTime generatedAt;
  final String status;

  const MerchantInsightItemModel({
    required this.id,
    required this.insightType,
    required this.title,
    required this.summary,
    required this.financialFacts,
    required this.externalSignals,
    required this.interpretation,
    required this.groundingStatus,
    required this.evidenceReferences,
    required this.limitations,
    this.focusEntityId,
    required this.generatedAt,
    required this.status,
  });

  factory MerchantInsightItemModel.fromJson(Map<String, dynamic> json) {
    final facts = (json['financial_facts'] as List? ?? [])
        .map((f) => InternalFactDetailModel.fromJson(f))
        .toList();
    final signals = (json['external_signals'] as List? ?? [])
        .map((s) => ExternalSignalDetailModel.fromJson(s))
        .toList();
    final refs = (json['evidence_references'] as List? ?? [])
        .map((r) => r.toString())
        .toList();
    final limits = (json['limitations'] as List? ?? [])
        .map((l) => l.toString())
        .toList();

    return MerchantInsightItemModel(
      id: json['id'] ?? '',
      insightType: json['insight_type'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      financialFacts: facts,
      externalSignals: signals,
      interpretation: json['interpretation'] ?? '',
      groundingStatus: json['grounding_status'] ?? 'SUPPORTED',
      evidenceReferences: refs,
      limitations: limits,
      focusEntityId: json['focus_entity_id'],
      generatedAt: DateTime.tryParse(json['generated_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'CURRENT',
    );
  }
}
