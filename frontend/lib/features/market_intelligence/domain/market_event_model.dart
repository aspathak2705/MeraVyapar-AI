class MarketSourceModel {
  final String id;
  final String providerName;
  final String sourceName;
  final String sourceUrl;
  final String title;
  final DateTime publishedAt;

  const MarketSourceModel({
    required this.id,
    required this.providerName,
    required this.sourceName,
    required this.sourceUrl,
    required this.title,
    required this.publishedAt,
  });

  factory MarketSourceModel.fromJson(Map<String, dynamic> json) {
    return MarketSourceModel(
      id: json['id'],
      providerName: json['provider_name'] ?? 'External Feed',
      sourceName: json['source_name'] ?? 'News Source',
      sourceUrl: json['source_url'] ?? '',
      title: json['title'] ?? '',
      publishedAt: DateTime.parse(json['published_at']),
    );
  }
}

class MarketEventModel {
  final String id;
  final String eventType;
  final String title;
  final String summary;
  final String? geography;
  final String? sector;
  final List<String> affectedDomains;
  final DateTime occurredAt;
  final MarketSourceModel? source;

  const MarketEventModel({
    required this.id,
    required this.eventType,
    required this.title,
    required this.summary,
    this.geography,
    this.sector,
    required this.affectedDomains,
    required this.occurredAt,
    this.source,
  });

  factory MarketEventModel.fromJson(Map<String, dynamic> json) {
    final domains = (json['affected_domains'] as List? ?? []).map((d) => d.toString()).toList();
    return MarketEventModel(
      id: json['id'],
      eventType: json['event_type'] ?? 'OTHER',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      geography: json['geography'],
      sector: json['sector'],
      affectedDomains: domains,
      occurredAt: DateTime.parse(json['occurred_at']),
      source: json['source'] != null ? MarketSourceModel.fromJson(json['source']) : null,
    );
  }
}
