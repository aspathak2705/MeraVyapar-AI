import 'package:uuid/uuid.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../domain/procurement_models.dart';

class LocalProcurementRepository {
  final LocalDatabaseService _dbService;

  LocalProcurementRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  // -------------------------------------------------------------
  // Suppliers
  // -------------------------------------------------------------
  Future<List<SupplierModel>> getSuppliers({required String merchantId}) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableSuppliers}
      WHERE merchant_id = ?
      ORDER BY name ASC
      ''',
      [merchantId],
    );
    return rows.map((r) => SupplierModel.fromMap(r)).toList();
  }

  Future<SupplierModel> createSupplier({
    required String merchantId,
    required String name,
    String? contactPerson,
    String? phoneNumber,
    String? email,
    String? category,
    String? notes,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    // Prevent accidental duplicate suppliers
    final existing = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableSuppliers}
      WHERE merchant_id = ? AND LOWER(name) = ?
      ''',
      [merchantId, name.trim().toLowerCase()],
    );
    if (existing.isNotEmpty) {
      return SupplierModel.fromMap(existing.first);
    }

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final supplier = SupplierModel(
      id: id,
      merchantId: merchantId,
      name: name.trim(),
      contactPerson: contactPerson,
      phoneNumber: phoneNumber,
      email: email,
      category: category,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableSuppliers} (
        id, merchant_id, name, contact_person, phone_number, email, category, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        supplier.id,
        supplier.merchantId,
        supplier.name,
        supplier.contactPerson,
        supplier.phoneNumber,
        supplier.email,
        supplier.category,
        supplier.notes,
        supplier.createdAt.toIso8601String(),
        supplier.updatedAt.toIso8601String(),
      ],
    );

    return supplier;
  }

  // -------------------------------------------------------------
  // Purchase Requests
  // -------------------------------------------------------------
  Future<List<PurchaseRequestModel>> getPurchaseRequests({required String merchantId}) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tablePurchaseRequests}
      WHERE merchant_id = ?
      ORDER BY created_at DESC
      ''',
      [merchantId],
    );
    return rows.map((r) => PurchaseRequestModel.fromMap(r)).toList();
  }

  Future<PurchaseRequestModel> createPurchaseRequest({
    required String merchantId,
    required String title,
    required String itemName,
    required double quantity,
    required String unit,
    String? gradeSpec,
    String? dimensions,
    String? deliveryTimeline,
    String? notes,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final pr = PurchaseRequestModel(
      id: id,
      merchantId: merchantId,
      title: title.trim(),
      itemName: itemName.trim(),
      quantity: quantity,
      unit: unit.trim(),
      gradeSpec: gradeSpec,
      dimensions: dimensions,
      deliveryTimeline: deliveryTimeline,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tablePurchaseRequests} (
        id, merchant_id, title, item_name, quantity, unit, grade_spec, dimensions, delivery_timeline, status, notes, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        pr.id,
        pr.merchantId,
        pr.title,
        pr.itemName,
        pr.quantity,
        pr.unit,
        pr.gradeSpec,
        pr.dimensions,
        pr.deliveryTimeline,
        pr.status,
        pr.notes,
        pr.createdAt.toIso8601String(),
        pr.updatedAt.toIso8601String(),
      ],
    );

    return pr;
  }

  // -------------------------------------------------------------
  // Supplier Quotations
  // -------------------------------------------------------------
  Future<List<SupplierQuotationModel>> getQuotations({
    required String merchantId,
    String? purchaseRequestId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    List<Map<String, dynamic>> rows;
    if (purchaseRequestId != null && purchaseRequestId.isNotEmpty) {
      rows = await driver.query(
        '''
        SELECT * FROM ${LocalDatabaseSchema.tableSupplierQuotations}
        WHERE merchant_id = ? AND purchase_request_id = ?
        ORDER BY total_landed_cost_minor_units ASC
        ''',
        [merchantId, purchaseRequestId],
      );
    } else {
      rows = await driver.query(
        '''
        SELECT * FROM ${LocalDatabaseSchema.tableSupplierQuotations}
        WHERE merchant_id = ?
        ORDER BY created_at DESC
        ''',
        [merchantId],
      );
    }
    return rows.map((r) => SupplierQuotationModel.fromMap(r)).toList();
  }

  Future<SupplierQuotationModel> createQuotation({
    required String merchantId,
    String? purchaseRequestId,
    required String supplierId,
    required String supplierName,
    required String itemName,
    String? specification,
    required double quantity,
    required String unit,
    required int unitPriceMinorUnits,
    double gstRatePercent = 18.0,
    int freightMinorUnits = 0,
    int otherChargesMinorUnits = 0,
    int deliveryDays = 7,
    String paymentTerms = 'CREDIT_30_DAYS',
    String? validUntil,
    String? notes,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final totalLanded = SupplierQuotationModel.calculateLandedCostPaise(
      quantity: quantity,
      unitPricePaise: unitPriceMinorUnits,
      gstPercent: gstRatePercent,
      freightPaise: freightMinorUnits,
      otherChargesPaise: otherChargesMinorUnits,
    );

    final quote = SupplierQuotationModel(
      id: id,
      merchantId: merchantId,
      purchaseRequestId: purchaseRequestId,
      supplierId: supplierId,
      supplierName: supplierName.trim(),
      itemName: itemName.trim(),
      specification: specification,
      quantity: quantity,
      unit: unit.trim(),
      unitPriceMinorUnits: unitPriceMinorUnits,
      gstRatePercent: gstRatePercent,
      freightMinorUnits: freightMinorUnits,
      otherChargesMinorUnits: otherChargesMinorUnits,
      totalLandedCostMinorUnits: totalLanded,
      deliveryDays: deliveryDays,
      paymentTerms: paymentTerms,
      validUntil: validUntil,
      notes: notes,
      createdAt: now,
    );

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableSupplierQuotations} (
        id, merchant_id, purchase_request_id, supplier_id, supplier_name, item_name,
        specification, quantity, unit, unit_price_minor_units, gst_rate_percent,
        freight_minor_units, other_charges_minor_units, total_landed_cost_minor_units,
        delivery_days, payment_terms, valid_until, is_accepted, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        quote.id,
        quote.merchantId,
        quote.purchaseRequestId,
        quote.supplierId,
        quote.supplierName,
        quote.itemName,
        quote.specification,
        quote.quantity,
        quote.unit,
        quote.unitPriceMinorUnits,
        quote.gstRatePercent,
        quote.freightMinorUnits,
        quote.otherChargesMinorUnits,
        quote.totalLandedCostMinorUnits,
        quote.deliveryDays,
        quote.paymentTerms,
        quote.validUntil,
        quote.isAccepted ? 1 : 0,
        quote.notes,
        quote.createdAt.toIso8601String(),
      ],
    );

    return quote;
  }

  // -------------------------------------------------------------
  // Purchase Approval & Supplier Obligation Creation
  // -------------------------------------------------------------
  Future<SupplierObligationModel> approveQuotationAndCreateObligation({
    required String merchantId,
    required String quotationId,
    required DateTime paymentDueDate,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final qRows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableSupplierQuotations}
      WHERE id = ? AND merchant_id = ?
      ''',
      [quotationId, merchantId],
    );
    if (qRows.isEmpty) throw StateError('Quotation not found: $quotationId');

    final quote = SupplierQuotationModel.fromMap(qRows.first);
    final now = DateTime.now().toUtc();

    final poId = const Uuid().v4();
    final obligationId = const Uuid().v4();

    // 1. Mark quotation as accepted
    await driver.execute(
      '''
      UPDATE ${LocalDatabaseSchema.tableSupplierQuotations}
      SET is_accepted = 1
      WHERE id = ?
      ''',
      [quotationId],
    );

    // 2. Create Purchase Order record
    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tablePurchaseOrders} (
        id, merchant_id, purchase_request_id, quotation_id, supplier_id,
        supplier_name, item_name, quantity, unit, total_amount_minor_units,
        status, delivery_status, quality_status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        poId,
        merchantId,
        quote.purchaseRequestId,
        quote.id,
        quote.supplierId,
        quote.supplierName,
        quote.itemName,
        quote.quantity,
        quote.unit,
        quote.totalLandedCostMinorUnits,
        'CONFIRMED',
        'PENDING',
        'PENDING',
        now.toIso8601String(),
      ],
    );

    // 3. Create Outgoing Supplier Obligation
    final obligation = SupplierObligationModel(
      id: obligationId,
      merchantId: merchantId,
      purchaseOrderId: poId,
      supplierId: quote.supplierId,
      supplierName: quote.supplierName,
      totalObligationMinorUnits: quote.totalLandedCostMinorUnits,
      settledMinorUnits: 0,
      outstandingMinorUnits: quote.totalLandedCostMinorUnits,
      dueDate: paymentDueDate,
      status: 'PENDING',
      createdAt: now,
    );

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tableSupplierObligations} (
        id, merchant_id, purchase_order_id, supplier_id, supplier_name,
        total_obligation_minor_units, settled_minor_units, outstanding_minor_units,
        due_date, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        obligation.id,
        obligation.merchantId,
        obligation.purchaseOrderId,
        obligation.supplierId,
        obligation.supplierName,
        obligation.totalObligationMinorUnits,
        obligation.settledMinorUnits,
        obligation.outstandingMinorUnits,
        obligation.dueDate.toIso8601String(),
        obligation.status,
        obligation.createdAt.toIso8601String(),
      ],
    );

    return obligation;
  }

  // -------------------------------------------------------------
  // Supplier Obligations
  // -------------------------------------------------------------
  Future<List<SupplierObligationModel>> getSupplierObligations({
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableSupplierObligations}
      WHERE merchant_id = ?
      ORDER BY due_date ASC
      ''',
      [merchantId],
    );
    return rows.map((r) => SupplierObligationModel.fromMap(r)).toList();
  }

  Future<void> settleSupplierObligation({
    required String merchantId,
    required String obligationId,
    required int settleAmountPaise,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableSupplierObligations}
      WHERE id = ? AND merchant_id = ?
      ''',
      [obligationId, merchantId],
    );
    if (rows.isEmpty) throw StateError('Obligation not found: $obligationId');

    final ob = SupplierObligationModel.fromMap(rows.first);
    final newSettled = ob.settledMinorUnits + settleAmountPaise;
    final newOutstanding = (ob.totalObligationMinorUnits - newSettled).clamp(0, ob.totalObligationMinorUnits);
    final isFull = newOutstanding == 0;
    final now = DateTime.now().toUtc();

    await driver.execute(
      '''
      UPDATE ${LocalDatabaseSchema.tableSupplierObligations}
      SET settled_minor_units = ?, outstanding_minor_units = ?, status = ?, settled_at = ?
      WHERE id = ?
      ''',
      [
        newSettled,
        newOutstanding,
        isFull ? 'FULFILLED' : 'PARTIALLY_SETTLED',
        isFull ? now.toIso8601String() : null,
        obligationId,
      ],
    );
  }
}
