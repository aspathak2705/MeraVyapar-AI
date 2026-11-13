/// Supported Procurement Voice Intents
enum ProcurementVoiceIntent {
  createPurchaseRequest,
  addSupplier,
  captureSupplierQuotation,
  compareSupplierQuotes,
  querySupplierHistory,
  queryUpcomingSupplierPayments,
  generateNegotiationDraft,
  recordPurchaseOutcome,
  unknown,
}

/// Representation of a Merchant Purchase Request
class PurchaseRequestModel {
  final String id;
  final String merchantId;
  final String title;
  final String itemName;
  final double quantity;
  final String unit;
  final String? gradeSpec;
  final String? dimensions;
  final String? deliveryTimeline;
  final String status; // OPEN, FULFILLED, CANCELLED
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseRequestModel({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.gradeSpec,
    this.dimensions,
    this.deliveryTimeline,
    this.status = 'OPEN',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'merchant_id': merchantId,
        'title': title,
        'item_name': itemName,
        'quantity': quantity,
        'unit': unit,
        'grade_spec': gradeSpec,
        'dimensions': dimensions,
        'delivery_timeline': deliveryTimeline,
        'status': status,
        'notes': notes,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory PurchaseRequestModel.fromMap(Map<String, dynamic> map) {
    return PurchaseRequestModel(
      id: map['id'] as String,
      merchantId: map['merchant_id'] as String,
      title: map['title'] as String,
      itemName: map['item_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      gradeSpec: map['grade_spec'] as String?,
      dimensions: map['dimensions'] as String?,
      deliveryTimeline: map['delivery_timeline'] as String?,
      status: map['status'] as String? ?? 'OPEN',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Representation of a Vendor / Supplier Profile
class SupplierModel {
  final String id;
  final String merchantId;
  final String name;
  final String? contactPerson;
  final String? phoneNumber;
  final String? email;
  final String? category;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupplierModel({
    required this.id,
    required this.merchantId,
    required this.name,
    this.contactPerson,
    this.phoneNumber,
    this.email,
    this.category,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'merchant_id': merchantId,
        'name': name,
        'contact_person': contactPerson,
        'phone_number': phoneNumber,
        'email': email,
        'category': category,
        'notes': notes,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] as String,
      merchantId: map['merchant_id'] as String,
      name: map['name'] as String,
      contactPerson: map['contact_person'] as String?,
      phoneNumber: map['phone_number'] as String?,
      email: map['email'] as String?,
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// Structured Supplier Quotation with exact integer paise accounting
class SupplierQuotationModel {
  final String id;
  final String merchantId;
  final String? purchaseRequestId;
  final String supplierId;
  final String supplierName;
  final String itemName;
  final String? specification;
  final double quantity;
  final String unit;
  final int unitPriceMinorUnits; // in paise (e.g., 21000 for ₹210.00)
  final double gstRatePercent;   // e.g., 18.0
  final int freightMinorUnits;    // in paise
  final int otherChargesMinorUnits;
  final int totalLandedCostMinorUnits;
  final int deliveryDays;
  final String paymentTerms;
  final String? validUntil;
  final bool isAccepted;
  final String? notes;
  final DateTime createdAt;

  const SupplierQuotationModel({
    required this.id,
    required this.merchantId,
    this.purchaseRequestId,
    required this.supplierId,
    required this.supplierName,
    required this.itemName,
    this.specification,
    required this.quantity,
    required this.unit,
    required this.unitPriceMinorUnits,
    this.gstRatePercent = 18.0,
    this.freightMinorUnits = 0,
    this.otherChargesMinorUnits = 0,
    required this.totalLandedCostMinorUnits,
    this.deliveryDays = 7,
    this.paymentTerms = 'CREDIT_30_DAYS',
    this.validUntil,
    this.isAccepted = false,
    this.notes,
    required this.createdAt,
  });

  double get unitPriceInr => unitPriceMinorUnits / 100.0;
  double get totalLandedCostInr => totalLandedCostMinorUnits / 100.0;
  double get freightInr => freightMinorUnits / 100.0;

  /// Deterministically calculate total landed cost in exact paise
  static int calculateLandedCostPaise({
    required double quantity,
    required int unitPricePaise,
    required double gstPercent,
    required int freightPaise,
    required int otherChargesPaise,
  }) {
    final baseCost = (quantity * unitPricePaise).round();
    final gstAmount = (baseCost * (gstPercent / 100.0)).round();
    return baseCost + gstAmount + freightPaise + otherChargesPaise;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'merchant_id': merchantId,
        'purchase_request_id': purchaseRequestId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'item_name': itemName,
        'specification': specification,
        'quantity': quantity,
        'unit': unit,
        'unit_price_minor_units': unitPriceMinorUnits,
        'gst_rate_percent': gstRatePercent,
        'freight_minor_units': freightMinorUnits,
        'other_charges_minor_units': otherChargesMinorUnits,
        'total_landed_cost_minor_units': totalLandedCostMinorUnits,
        'delivery_days': deliveryDays,
        'payment_terms': paymentTerms,
        'valid_until': validUntil,
        'is_accepted': isAccepted ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory SupplierQuotationModel.fromMap(Map<String, dynamic> map) {
    return SupplierQuotationModel(
      id: map['id'] as String,
      merchantId: map['merchant_id'] as String,
      purchaseRequestId: map['purchase_request_id'] as String?,
      supplierId: map['supplier_id'] as String,
      supplierName: map['supplier_name'] as String,
      itemName: map['item_name'] as String,
      specification: map['specification'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      unitPriceMinorUnits: map['unit_price_minor_units'] as int,
      gstRatePercent: (map['gst_rate_percent'] as num).toDouble(),
      freightMinorUnits: map['freight_minor_units'] as int? ?? 0,
      otherChargesMinorUnits: map['other_charges_minor_units'] as int? ?? 0,
      totalLandedCostMinorUnits: map['total_landed_cost_minor_units'] as int,
      deliveryDays: map['delivery_days'] as int? ?? 7,
      paymentTerms: map['payment_terms'] as String? ?? 'CREDIT_30_DAYS',
      validUntil: map['valid_until'] as String?,
      isAccepted: (map['is_accepted'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Outgoing Supplier Payment Obligation integrated into cashflow
class SupplierObligationModel {
  final String id;
  final String merchantId;
  final String purchaseOrderId;
  final String supplierId;
  final String supplierName;
  final int totalObligationMinorUnits;
  final int settledMinorUnits;
  final int outstandingMinorUnits;
  final DateTime dueDate;
  final String status; // PENDING, PARTIALLY_SETTLED, FULFILLED
  final DateTime createdAt;
  final DateTime? settledAt;

  const SupplierObligationModel({
    required this.id,
    required this.merchantId,
    required this.purchaseOrderId,
    required this.supplierId,
    required this.supplierName,
    required this.totalObligationMinorUnits,
    required this.settledMinorUnits,
    required this.outstandingMinorUnits,
    required this.dueDate,
    this.status = 'PENDING',
    required this.createdAt,
    this.settledAt,
  });

  double get totalObligationInr => totalObligationMinorUnits / 100.0;
  double get outstandingInr => outstandingMinorUnits / 100.0;
  double get settledInr => settledMinorUnits / 100.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'merchant_id': merchantId,
        'purchase_order_id': purchaseOrderId,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'total_obligation_minor_units': totalObligationMinorUnits,
        'settled_minor_units': settledMinorUnits,
        'outstanding_minor_units': outstandingMinorUnits,
        'due_date': dueDate.toUtc().toIso8601String(),
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
        'settled_at': settledAt?.toUtc().toIso8601String(),
      };

  factory SupplierObligationModel.fromMap(Map<String, dynamic> map) {
    return SupplierObligationModel(
      id: map['id'] as String,
      merchantId: map['merchant_id'] as String,
      purchaseOrderId: map['purchase_order_id'] as String,
      supplierId: map['supplier_id'] as String,
      supplierName: map['supplier_name'] as String,
      totalObligationMinorUnits: map['total_obligation_minor_units'] as int,
      settledMinorUnits: map['settled_minor_units'] as int? ?? 0,
      outstandingMinorUnits: map['outstanding_minor_units'] as int,
      dueDate: DateTime.parse(map['due_date'] as String),
      status: map['status'] as String? ?? 'PENDING',
      createdAt: DateTime.parse(map['created_at'] as String),
      settledAt: map['settled_at'] != null ? DateTime.parse(map['settled_at'] as String) : null,
    );
  }
}
