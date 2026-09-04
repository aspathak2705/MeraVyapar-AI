class InsightSourceReferenceModel {
  final String entityType;
  final String entityId;
  final String? label;

  const InsightSourceReferenceModel({
    required this.entityType,
    required this.entityId,
    this.label,
  });

  factory InsightSourceReferenceModel.fromJson(Map<String, dynamic> json) {
    return InsightSourceReferenceModel(
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      label: json['label'],
    );
  }
}

class KeyFactItemModel {
  final String label;
  final String value;
  final String? sourceReference;

  const KeyFactItemModel({
    required this.label,
    required this.value,
    this.sourceReference,
  });

  factory KeyFactItemModel.fromJson(Map<String, dynamic> json) {
    return KeyFactItemModel(
      label: json['label'] ?? '',
      value: json['value'] ?? '',
      sourceReference: json['source_reference'],
    );
  }
}

class GroundedInsightModel {
  final String summary;
  final String whyItMatters;
  final List<KeyFactItemModel> keyFacts;
  final List<String> suggestedActions;
  final List<String> limitations;
  final List<InsightSourceReferenceModel> sourceReferences;
  final bool isAiGenerated;
  final String status;

  const GroundedInsightModel({
    required this.summary,
    required this.whyItMatters,
    required this.keyFacts,
    required this.suggestedActions,
    required this.limitations,
    required this.sourceReferences,
    required this.isAiGenerated,
    required this.status,
  });

  factory GroundedInsightModel.fromJson(Map<String, dynamic> json) {
    final facts = (json['key_facts'] as List? ?? [])
        .map((f) => KeyFactItemModel.fromJson(f))
        .toList();
    final actions = (json['suggested_actions'] as List? ?? [])
        .map((a) => a.toString())
        .toList();
    final limits = (json['limitations'] as List? ?? [])
        .map((l) => l.toString())
        .toList();
    final sources = (json['source_references'] as List? ?? [])
        .map((s) => InsightSourceReferenceModel.fromJson(s))
        .toList();

    return GroundedInsightModel(
      summary: json['summary'] ?? '',
      whyItMatters: json['why_it_matters'] ?? '',
      keyFacts: facts,
      suggestedActions: actions,
      limitations: limits,
      sourceReferences: sources,
      isAiGenerated: json['is_ai_generated'] ?? true,
      status: json['status'] ?? 'CURRENT',
    );
  }
}

class FinancialQueryResultModel {
  final String intentCategory;
  final bool isAllowed;
  final String? scopeMessage;
  final GroundedInsightModel? insight;

  const FinancialQueryResultModel({
    required this.intentCategory,
    required this.isAllowed,
    this.scopeMessage,
    this.insight,
  });

  factory FinancialQueryResultModel.fromJson(Map<String, dynamic> json) {
    return FinancialQueryResultModel(
      intentCategory: json['intent_category'] ?? 'UNKNOWN',
      isAllowed: json['is_allowed'] ?? false,
      scopeMessage: json['scope_message'],
      insight: json['insight'] != null
          ? GroundedInsightModel.fromJson(json['insight'])
          : null,
    );
  }
}
