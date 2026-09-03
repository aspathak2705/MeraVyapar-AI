class CounterpartyAliasModel {
  final String id;
  final String aliasValue;
  final String normalizedAlias;
  final String source;

  const CounterpartyAliasModel({
    required this.id,
    required this.aliasValue,
    required this.normalizedAlias,
    required this.source,
  });

  factory CounterpartyAliasModel.fromJson(Map<String, dynamic> json) {
    return CounterpartyAliasModel(
      id: json['id'],
      aliasValue: json['alias_value'],
      normalizedAlias: json['normalized_alias'],
      source: json['source'] ?? 'EXACT_MATCH',
    );
  }
}

class RelationshipProfileModel {
  final String relationshipType;
  final String relationshipStatus;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int transactionCount;

  const RelationshipProfileModel({
    required this.relationshipType,
    required this.relationshipStatus,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.transactionCount,
  });

  factory RelationshipProfileModel.fromJson(Map<String, dynamic> json) {
    return RelationshipProfileModel(
      relationshipType: json['relationship_type'] ?? 'UNKNOWN',
      relationshipStatus: json['relationship_status'] ?? 'OBSERVED',
      firstSeenAt: DateTime.parse(json['first_seen_at']),
      lastSeenAt: DateTime.parse(json['last_seen_at']),
      transactionCount: json['transaction_count'] ?? 0,
    );
  }
}

class FinancialRelationshipEventModel {
  final String id;
  final String eventType;
  final String? canonicalTransactionId;
  final String? paymentPromiseId;
  final DateTime occurredAt;
  final Map<String, dynamic> metadataInfo;

  const FinancialRelationshipEventModel({
    required this.id,
    required this.eventType,
    this.canonicalTransactionId,
    this.paymentPromiseId,
    required this.occurredAt,
    required this.metadataInfo,
  });

  factory FinancialRelationshipEventModel.fromJson(Map<String, dynamic> json) {
    return FinancialRelationshipEventModel(
      id: json['id'],
      eventType: json['event_type'],
      canonicalTransactionId: json['canonical_transaction_id'],
      paymentPromiseId: json['payment_promise_id'],
      occurredAt: DateTime.parse(json['occurred_at']),
      metadataInfo: json['metadata_info'] ?? {},
    );
  }
}

class CounterpartyModel {
  final String id;
  final String merchantId;
  final String displayName;
  final String normalizedName;
  final String relationshipType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CounterpartyAliasModel> aliases;
  final RelationshipProfileModel? relationshipProfile;

  const CounterpartyModel({
    required this.id,
    required this.merchantId,
    required this.displayName,
    required this.normalizedName,
    required this.relationshipType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.aliases,
    this.relationshipProfile,
  });

  factory CounterpartyModel.fromJson(Map<String, dynamic> json) {
    final aliasList = json['aliases'] as List? ?? [];
    return CounterpartyModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      displayName: json['display_name'],
      normalizedName: json['normalized_name'],
      relationshipType: json['relationship_type'] ?? 'UNKNOWN',
      status: json['status'] ?? 'ACTIVE',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      aliases: aliasList.map((a) => CounterpartyAliasModel.fromJson(a)).toList(),
      relationshipProfile: json['relationship_profile'] != null
          ? RelationshipProfileModel.fromJson(json['relationship_profile'])
          : null,
    );
  }
}
