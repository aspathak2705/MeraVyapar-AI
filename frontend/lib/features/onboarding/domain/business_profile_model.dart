class BusinessProfileModel {
  final String? id;
  final String merchantId;
  final String businessName;
  final String? businessType;
  final String? phoneNumber;
  final String? city;
  final String? state;
  final bool onboardingCompleted;

  const BusinessProfileModel({
    this.id,
    required this.merchantId,
    required this.businessName,
    this.businessType,
    this.phoneNumber,
    this.city,
    this.state,
    this.onboardingCompleted = false,
  });

  factory BusinessProfileModel.fromJson(Map<String, dynamic> json) {
    return BusinessProfileModel(
      id: json['id'],
      merchantId: json['merchant_id'],
      businessName: json['business_name'],
      businessType: json['business_type'],
      phoneNumber: json['phone_number'],
      city: json['city'],
      state: json['state'],
      onboardingCompleted: json['onboarding_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'business_name': businessName,
      if (businessType != null) 'business_type': businessType,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
    };
  }
}
