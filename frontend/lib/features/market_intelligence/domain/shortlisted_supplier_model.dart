import 'package:uuid/uuid.dart';
import 'market_event_model.dart';

class ShortlistedSupplierModel {
  final String id;
  final String merchantId;
  final String businessName;
  final String? businessCategory;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? website;
  final double? rating;
  final int? reviewCount;
  final String? operatingHours;
  final String? sourceUrl;
  final String? notes;
  final DateTime createdAt;

  const ShortlistedSupplierModel({
    required this.id,
    required this.merchantId,
    required this.businessName,
    this.businessCategory,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.website,
    this.rating,
    this.reviewCount,
    this.operatingHours,
    this.sourceUrl,
    this.notes,
    required this.createdAt,
  });

  factory ShortlistedSupplierModel.fromMarketEvent(
    String merchantId,
    MarketEventModel event, {
    String? notes,
  }) {
    String? hoursStr;
    final rawHours = event.operatingHours;
    if (rawHours is Map) {
      hoursStr = rawHours.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    } else if (rawHours != null) {
      hoursStr = rawHours.toString();
    }

    return ShortlistedSupplierModel(
      id: const Uuid().v4(),
      merchantId: merchantId,
      businessName: event.title.isNotEmpty ? event.title : 'Discovered Business',
      businessCategory: event.category ?? event.sector ?? 'Wholesale & Supplier',
      address: event.location,
      latitude: event.latitude,
      longitude: event.longitude,
      phone: event.phone,
      website: event.website ?? event.source?.sourceUrl,
      rating: event.rating,
      reviewCount: event.reviews,
      operatingHours: hoursStr,
      sourceUrl: event.source?.sourceUrl,
      notes: notes,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'business_name': businessName,
      'business_category': businessCategory,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'website': website,
      'rating': rating,
      'review_count': reviewCount,
      'operating_hours': operatingHours,
      'source_url': sourceUrl,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ShortlistedSupplierModel.fromMap(Map<String, dynamic> map) {
    return ShortlistedSupplierModel(
      id: map['id']?.toString() ?? '',
      merchantId: map['merchant_id']?.toString() ?? '',
      businessName: map['business_name']?.toString() ?? '',
      businessCategory: map['business_category']?.toString(),
      address: map['address']?.toString(),
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      phone: map['phone']?.toString(),
      website: map['website']?.toString(),
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      reviewCount: map['review_count'] != null ? (map['review_count'] as num).toInt() : null,
      operatingHours: map['operating_hours']?.toString(),
      sourceUrl: map['source_url']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now().toUtc(),
    );
  }

  ShortlistedSupplierModel copyWith({
    String? businessName,
    String? businessCategory,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    String? website,
    double? rating,
    int? reviewCount,
    String? operatingHours,
    String? sourceUrl,
    String? notes,
  }) {
    return ShortlistedSupplierModel(
      id: id,
      merchantId: merchantId,
      businessName: businessName ?? this.businessName,
      businessCategory: businessCategory ?? this.businessCategory,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      operatingHours: operatingHours ?? this.operatingHours,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
