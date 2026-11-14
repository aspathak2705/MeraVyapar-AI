class MerchantBusinessProfile {
  final String merchantId;
  final String businessName;
  final String businessCategory; // e.g. "Grocery & Kirana", "Textiles & Apparel", "Electronics"
  final String businessType; // "RETAIL", "WHOLESALE", "SERVICES", "MANUFACTURING"
  final String productsAndServices; // e.g. "Grains, Spices, Dairy, FMCG"
  final String city;
  final String state;
  final String customerType; // "B2C", "B2B", "HYBRID"
  final String salesChannels; // "OFFLINE_STORE", "WHATSAPP", "ONLINE", "HYBRID"
  final String mainProcurementCategories; // e.g. "Rice, Wheat, Edible Oils"
  final String turnoverRange; // "< 10L", "10L - 40L", "40L - 1.5Cr", "> 1.5Cr"
  final String businessGoals; // e.g. "Reduce supplier costs, collect receivables faster"
  final String updatedAt;

  const MerchantBusinessProfile({
    required this.merchantId,
    required this.businessName,
    this.businessCategory = 'Retail Kirana & FMCG',
    this.businessType = 'RETAIL',
    this.productsAndServices = 'Daily Essentials, Groceries & FMCG Goods',
    this.city = 'Pune',
    this.state = 'Maharashtra',
    this.customerType = 'B2C',
    this.salesChannels = 'OFFLINE_STORE',
    this.mainProcurementCategories = 'Grains, Spices, Packaged Goods',
    this.turnoverRange = '10L - 40L',
    this.businessGoals = 'Lower purchase costs, manage debtor follow-ups',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'merchant_id': merchantId,
      'business_name': businessName,
      'business_category': businessCategory,
      'business_type': businessType,
      'products_and_services': productsAndServices,
      'city': city,
      'state': state,
      'customer_type': customerType,
      'sales_channels': salesChannels,
      'main_procurement_categories': mainProcurementCategories,
      'turnover_range': turnoverRange,
      'business_goals': businessGoals,
      'updated_at': updatedAt,
    };
  }

  factory MerchantBusinessProfile.fromMap(Map<String, dynamic> map) {
    return MerchantBusinessProfile(
      merchantId: map['merchant_id'] as String,
      businessName: map['business_name'] as String? ?? 'My Business',
      businessCategory: map['business_category'] as String? ?? 'Retail Kirana & FMCG',
      businessType: map['business_type'] as String? ?? 'RETAIL',
      productsAndServices: map['products_and_services'] as String? ?? 'Daily Essentials, Groceries & FMCG Goods',
      city: map['city'] as String? ?? 'Pune',
      state: map['state'] as String? ?? 'Maharashtra',
      customerType: map['customer_type'] as String? ?? 'B2C',
      salesChannels: map['sales_channels'] as String? ?? 'OFFLINE_STORE',
      mainProcurementCategories: map['main_procurement_categories'] as String? ?? 'Grains, Spices, Packaged Goods',
      turnoverRange: map['turnover_range'] as String? ?? '10L - 40L',
      businessGoals: map['business_goals'] as String? ?? 'Lower purchase costs, manage debtor follow-ups',
      updatedAt: map['updated_at'] as String? ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}
