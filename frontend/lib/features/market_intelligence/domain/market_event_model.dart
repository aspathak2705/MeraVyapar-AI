DateTime? parseFlexibleDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final text = raw.trim();

  // 1. Direct parse for ISO8601 / RFC formats
  final direct = DateTime.tryParse(text);
  if (direct != null) return direct;

  // 2. Relative date calculation
  final now = DateTime.now().toUtc();
  final lower = text.toLowerCase();

  if (lower == 'yesterday') {
    return now.subtract(const Duration(days: 1));
  }
  if (lower == 'today' || lower == 'just now') {
    return now;
  }

  // Minutes ago: e.g. "15 minutes ago", "10 mins ago"
  final minMatch = RegExp(r'^(\d+)\s*(?:minutes?|mins?|m)\s+ago$').firstMatch(lower);
  if (minMatch != null) {
    final mins = int.tryParse(minMatch.group(1)!);
    if (mins != null) return now.subtract(Duration(minutes: mins));
  }

  // Hours ago: e.g. "2 hours ago", "1 hr ago", "3h ago"
  final hrMatch = RegExp(r'^(\d+)\s*(?:hours?|hrs?|h)\s+ago$').firstMatch(lower);
  if (hrMatch != null) {
    final hrs = int.tryParse(hrMatch.group(1)!);
    if (hrs != null) return now.subtract(Duration(hours: hrs));
  }

  // Days ago: e.g. "3 days ago", "1 day ago"
  final dayMatch = RegExp(r'^(\d+)\s*(?:days?|d)\s+ago$').firstMatch(lower);
  if (dayMatch != null) {
    final days = int.tryParse(dayMatch.group(1)!);
    if (days != null) return now.subtract(Duration(days: days));
  }

  // Weeks ago: e.g. "2 weeks ago"
  final weekMatch = RegExp(r'^(\d+)\s*(?:weeks?|w)\s+ago$').firstMatch(lower);
  if (weekMatch != null) {
    final weeks = int.tryParse(weekMatch.group(1)!);
    if (weeks != null) return now.subtract(Duration(days: weeks * 7));
  }

  // Months ago: e.g. "1 month ago"
  final monthMatch = RegExp(r'^(\d+)\s*(?:months?|mo)\s+ago$').firstMatch(lower);
  if (monthMatch != null) {
    final months = int.tryParse(monthMatch.group(1)!);
    if (months != null) return now.subtract(Duration(days: months * 30));
  }

  // 3. Unknown/unsupported relative format: return null (never fabricate current timestamp)
  return null;
}

class MarketSourceModel {
  final String id;
  final String providerName;
  final String sourceName;
  final String sourceUrl;
  final String title;
  final DateTime? publishedAt;
  final String? rawPublishedAt;
  final String? price;
  final double? rating;
  final int? reviews;
  final String? location;
  final String? engine;
  final String? evidenceNature;
  final String? verificationStatus;
  final Map<String, dynamic>? metrics;

  const MarketSourceModel({
    required this.id,
    required this.providerName,
    required this.sourceName,
    required this.sourceUrl,
    required this.title,
    this.publishedAt,
    this.rawPublishedAt,
    this.price,
    this.rating,
    this.reviews,
    this.location,
    this.engine,
    this.evidenceNature,
    this.verificationStatus,
    this.metrics,
  });

  factory MarketSourceModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['published_at']?.toString();
    final rawMetrics = json['metrics'];
    return MarketSourceModel(
      id: json['id']?.toString() ?? '',
      providerName: json['provider_name'] ?? 'External Feed',
      sourceName: json['source_name'] ?? 'News Source',
      sourceUrl: json['source_url'] ?? '',
      title: json['title'] ?? '',
      publishedAt: parseFlexibleDate(rawDate),
      rawPublishedAt: rawDate,
      price: json['price']?.toString(),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      reviews: json['reviews'] != null ? (json['reviews'] as num).toInt() : null,
      location: json['location']?.toString(),
      engine: json['engine']?.toString(),
      evidenceNature: json['evidence_nature']?.toString(),
      verificationStatus: json['verification_status']?.toString(),
      metrics: rawMetrics is Map ? Map<String, dynamic>.from(rawMetrics) : null,
    );
  }

  double? get latitude {
    if (metrics != null) {
      if (metrics!['latitude'] != null) return (metrics!['latitude'] as num).toDouble();
      final gps = metrics!['gps_coordinates'];
      if (gps is Map && gps['latitude'] != null) return (gps['latitude'] as num).toDouble();
    }
    return null;
  }

  double? get longitude {
    if (metrics != null) {
      if (metrics!['longitude'] != null) return (metrics!['longitude'] as num).toDouble();
      final gps = metrics!['gps_coordinates'];
      if (gps is Map && gps['longitude'] != null) return (gps['longitude'] as num).toDouble();
    }
    return null;
  }

  String? get phone => metrics?['phone']?.toString();
  String? get website => metrics?['website']?.toString() ?? (sourceUrl.isNotEmpty ? sourceUrl : null);
  String? get placeId => metrics?['place_id']?.toString() ?? metrics?['data_id']?.toString();
  dynamic get operatingHours => metrics?['operating_hours'];
  String? get category => metrics?['type']?.toString();
}

class MarketEventModel {
  final String id;
  final String eventType;
  final String title;
  final String summary;
  final String? geography;
  final String? sector;
  final List<String> affectedDomains;
  final DateTime? occurredAt;
  final String? rawOccurredAt;
  final MarketSourceModel? source;
  final String? price;
  final double? rating;
  final int? reviews;
  final String? location;
  final String? engine;
  final String? evidenceNature;
  final Map<String, dynamic>? metrics;

  const MarketEventModel({
    required this.id,
    required this.eventType,
    required this.title,
    required this.summary,
    this.geography,
    this.sector,
    required this.affectedDomains,
    this.occurredAt,
    this.rawOccurredAt,
    this.source,
    this.price,
    this.rating,
    this.reviews,
    this.location,
    this.engine,
    this.evidenceNature,
    this.metrics,
  });

  factory MarketEventModel.fromJson(Map<String, dynamic> json) {
    final domains = (json['affected_domains'] as List? ?? []).map((d) => d.toString()).toList();
    final rawDate = json['occurred_at']?.toString();
    final rawMetrics = json['metrics'] ?? (json['source'] != null ? json['source']['metrics'] : null);
    return MarketEventModel(
      id: json['id']?.toString() ?? '',
      eventType: json['event_type'] ?? 'OTHER',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      geography: json['geography'],
      sector: json['sector'],
      affectedDomains: domains,
      occurredAt: parseFlexibleDate(rawDate),
      rawOccurredAt: rawDate,
      source: json['source'] != null ? MarketSourceModel.fromJson(json['source']) : null,
      price: json['price']?.toString() ?? (json['source'] != null ? json['source']['price']?.toString() : null),
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : (json['source']?['rating'] != null ? (json['source']['rating'] as num).toDouble() : null),
      reviews: json['reviews'] != null
          ? (json['reviews'] as num).toInt()
          : (json['source']?['reviews'] != null ? (json['source']['reviews'] as num).toInt() : null),
      location: json['location']?.toString() ?? (json['source'] != null ? json['source']['location']?.toString() : null),
      engine: json['engine']?.toString() ?? (json['source'] != null ? json['source']['engine']?.toString() : null),
      evidenceNature: json['evidence_nature']?.toString() ?? (json['source'] != null ? json['source']['evidence_nature']?.toString() : null),
      metrics: rawMetrics is Map ? Map<String, dynamic>.from(rawMetrics) : null,
    );
  }

  double? get latitude => source?.latitude ?? (metrics != null && metrics!['latitude'] != null ? (metrics!['latitude'] as num).toDouble() : null);
  double? get longitude => source?.longitude ?? (metrics != null && metrics!['longitude'] != null ? (metrics!['longitude'] as num).toDouble() : null);
  String? get phone => source?.phone ?? metrics?['phone']?.toString();
  String? get website => source?.website ?? metrics?['website']?.toString();
  String? get placeId => source?.placeId ?? metrics?['place_id']?.toString() ?? metrics?['data_id']?.toString();
  dynamic get operatingHours => source?.operatingHours ?? metrics?['operating_hours'];
  String? get category => source?.category ?? metrics?['type']?.toString();
}
