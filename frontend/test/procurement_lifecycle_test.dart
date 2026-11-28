import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/core/database/local_database_schema.dart';
import 'package:frontend/features/procurement/data/local_procurement_repository.dart';
import 'package:frontend/features/procurement/domain/procurement_models.dart';
import 'package:frontend/features/procurement/domain/quotation_comparison_engine.dart';
import 'package:frontend/features/procurement/domain/negotiation_intelligence_engine.dart';
import 'package:frontend/features/procurement/domain/procurement_voice_assistant.dart';

class MockProcurementDatabaseDriver implements LocalDatabaseDriver {
  final Map<String, List<Map<String, dynamic>>> tables = {};

  @override
  Future<void> open(String path) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase().trim();
    if (lower.startsWith('create table')) {
      final name = _extractTableName(sql);
      tables.putIfAbsent(name, () => []);
      return;
    }

    if (lower.startsWith('insert into')) {
      final name = _extractTableName(sql);
      tables.putIfAbsent(name, () => []);
      if (arguments != null && arguments.isNotEmpty) {
        if (name == LocalDatabaseSchema.tablePurchaseRequests) {
          tables[name]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'title': arguments[2],
            'item_name': arguments[3],
            'quantity': arguments[4],
            'unit': arguments[5],
            'grade_spec': arguments[6],
            'dimensions': arguments[7],
            'delivery_timeline': arguments[8],
            'status': arguments[9],
            'notes': arguments[10],
            'created_at': arguments[11],
            'updated_at': arguments[12],
          });
        } else if (name == LocalDatabaseSchema.tableSuppliers) {
          tables[name]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'name': arguments[2],
            'contact_person': arguments[3],
            'phone_number': arguments[4],
            'email': arguments[5],
            'category': arguments[6],
            'notes': arguments[7],
            'created_at': arguments[8],
            'updated_at': arguments[9],
          });
        } else if (name == LocalDatabaseSchema.tableSupplierQuotations) {
          tables[name]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'purchase_request_id': arguments[2],
            'supplier_id': arguments[3],
            'supplier_name': arguments[4],
            'item_name': arguments[5],
            'specification': arguments[6],
            'quantity': arguments[7],
            'unit': arguments[8],
            'unit_price_minor_units': arguments[9],
            'gst_rate_percent': arguments[10],
            'freight_minor_units': arguments[11],
            'other_charges_minor_units': arguments[12],
            'total_landed_cost_minor_units': arguments[13],
            'delivery_days': arguments[14],
            'payment_terms': arguments[15],
            'valid_until': arguments[16],
            'is_accepted': arguments[17],
            'notes': arguments[18],
            'created_at': arguments[19],
          });
        } else if (name == LocalDatabaseSchema.tablePurchaseOrders) {
          tables[name]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'purchase_request_id': arguments[2],
            'quotation_id': arguments[3],
            'supplier_id': arguments[4],
            'supplier_name': arguments[5],
            'item_name': arguments[6],
            'quantity': arguments[7],
            'unit': arguments[8],
            'total_amount_minor_units': arguments[9],
            'status': arguments[10],
            'delivery_status': arguments[11],
            'quality_status': arguments[12],
            'created_at': arguments[13],
            'delivered_at': null,
          });
        } else if (name == LocalDatabaseSchema.tableSupplierObligations) {
          tables[name]!.add({
            'id': arguments[0],
            'merchant_id': arguments[1],
            'purchase_order_id': arguments[2],
            'supplier_id': arguments[3],
            'supplier_name': arguments[4],
            'total_obligation_minor_units': arguments[5],
            'settled_minor_units': arguments[6],
            'outstanding_minor_units': arguments[7],
            'due_date': arguments[8],
            'status': arguments[9],
            'created_at': arguments[10],
            'settled_at': null,
          });
        }
      }
      return;
    }

    if (lower.startsWith('update')) {
      final name = _extractTableName(sql);
      final list = tables[name] ?? [];
      if (arguments != null && arguments.isNotEmpty) {
        if (name == LocalDatabaseSchema.tableSupplierQuotations && lower.contains('is_accepted = 1')) {
          final id = arguments[0];
          for (final row in list) {
            if (row['id'] == id) row['is_accepted'] = 1;
          }
        } else if (name == LocalDatabaseSchema.tablePurchaseOrders) {
          final delStatus = arguments[0];
          final qualStatus = arguments[1];
          final delAt = arguments[2];
          final poId = arguments[3];
          for (final row in list) {
            if (row['id'] == poId) {
              row['delivery_status'] = delStatus;
              row['quality_status'] = qualStatus;
              row['delivered_at'] = delAt;
            }
          }
        } else if (name == LocalDatabaseSchema.tableSupplierObligations) {
          final setMin = arguments[0];
          final outMin = arguments[1];
          final st = arguments[2];
          final setAt = arguments[3];
          final obId = arguments[4];
          for (final row in list) {
            if (row['id'] == obId) {
              row['settled_minor_units'] = setMin;
              row['outstanding_minor_units'] = outMin;
              row['status'] = st;
              row['settled_at'] = setAt;
            }
          }
        }
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('pragma user_version')) {
      return [{'user_version': 7}];
    }
    final name = _extractTableName(sql);
    final rows = List<Map<String, dynamic>>.from(tables[name] ?? []);

    final normSql = sql.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    if (normSql.contains('left join')) {
      // Handle supplier memory join (po LEFT JOIN q)
      final poList = tables[LocalDatabaseSchema.tablePurchaseOrders] ?? [];
      final qList = tables[LocalDatabaseSchema.tableSupplierQuotations] ?? [];
      final result = <Map<String, dynamic>>[];
      for (final po in poList) {
        if (arguments != null && arguments.length >= 2) {
          if (po['merchant_id'] != arguments[0] || po['supplier_id'] != arguments[1]) {
            continue;
          }
        }
        final matchQ = qList.firstWhere(
          (q) => q['id'] == po['quotation_id'],
          orElse: () => <String, dynamic>{},
        );
        final joined = Map<String, dynamic>.from(po);
        joined['unit_price_minor_units'] = matchQ['unit_price_minor_units'];
        joined['specification'] = matchQ['specification'];
        joined['payment_terms'] = matchQ['payment_terms'];
        result.add(joined);
      }
      return result;
    }

    if (arguments != null && arguments.isNotEmpty) {
      if (normSql.contains('lower(name) = ?')) {
        return rows
            .where((r) =>
                r['merchant_id'] == arguments[0] &&
                (r['name'] as String).toLowerCase() == (arguments[1] as String).toLowerCase())
            .toList();
      }
      if (normSql.contains('purchase_request_id = ?')) {
        final matches = rows
            .where((r) => r['merchant_id'] == arguments[0] && r['purchase_request_id'] == arguments[1])
            .toList();
        if (normSql.contains('order by total_landed_cost_minor_units asc')) {
          matches.sort((a, b) =>
              (a['total_landed_cost_minor_units'] as int).compareTo(b['total_landed_cost_minor_units'] as int));
        }
        return matches;
      }
      if (normSql.contains('supplier_id = ?')) {
        return rows
            .where((r) => r['merchant_id'] == arguments[0] && r['supplier_id'] == arguments[1])
            .toList();
      }
      if (normSql.contains('where id = ? and merchant_id = ?')) {
        return rows
            .where((r) => r['id'] == arguments[0] && r['merchant_id'] == arguments[1])
            .toList();
      }
      if (normSql.contains('where id = ?')) {
        return rows.where((r) => r['id'] == arguments[0]).toList();
      }
      return rows.where((r) => r['merchant_id'] == arguments[0]).toList();
    }
    return rows;
  }

  @override
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action) async {
    await action(this);
  }

  String _extractTableName(String sql) {
    final parts = sql.trim().split(RegExp(r'\s+'));
    for (int i = 0; i < parts.length; i++) {
      final p = parts[i].toLowerCase();
      if ((p == 'into' || p == 'from' || p == 'table' || p == 'update') && i + 1 < parts.length) {
        var name = parts[i + 1].replaceAll('(', '').replaceAll(';', '').trim();
        if (name.toLowerCase() == 'if' && i + 3 < parts.length) {
          name = parts[i + 3].replaceAll('(', '').replaceAll(';', '').trim();
        }
        return name;
      }
    }
    return 'unknown';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockProcurementDatabaseDriver driver;
  late LocalProcurementRepository repo;
  const testMerchantId = 'merchant_procurement_test_001';

  setUp(() async {
    driver = MockProcurementDatabaseDriver();
    await LocalDatabaseService.instance.initialize(customDriver: driver);
    repo = LocalProcurementRepository(dbService: LocalDatabaseService.instance);
  });

  group('KharidSaathi End-to-End Procurement Lifecycle Audit', () {
    test('1. Voice Purchase Request & Specification Clarification', () {
      const voiceInput = 'Mujhe 500 kg stainless steel 304 sheets chahiye, next week tak delivery chahiye';
      final draft = ProcurementVoiceAssistant.parseRequirement(voiceInput);

      expect(draft.quantity, 500.0);
      expect(draft.unit, 'kg');
      expect(draft.gradeSpec, 'SS 304');
      expect(draft.deliveryTimeline, '7 days');
      // Sheet without dimensions/thickness must trigger clarification
      expect(draft.isReadyForConfirmation, isFalse);
      expect(draft.missingSpecifications, contains('thickness'));
      expect(draft.missingSpecifications, contains('dimensions'));
      expect(draft.clarificationQuestion, isNotNull);

      // Clarified input
      final clarified = ProcurementVoiceAssistant.parseRequirement('$voiceInput 2mm 8x4 ft');
      expect(clarified.thickness, '2mm');
      expect(clarified.dimensions, '8x4 ft');
      expect(clarified.isReadyForConfirmation, isTrue);
    });

    test('2. Total Landed Cost Calculation (Integer Paise, GST, Freight)', () {
      // 500 kg @ ₹210.00/kg (21000 paise) + 18% GST + ₹1500 freight (150000 paise)
      // Base = 500 * 21000 = 10,500,000 paise (₹105,000.00)
      // Tax = 10,500,000 * 0.18 = 1,890,000 paise (₹18,900.00)
      // Total = 10,500,000 + 1,890,000 + 150,000 = 12,540,000 paise (₹125,400.00)
      final landedCostPaise = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 500.0,
        unitPricePaise: 21000,
        gstPercent: 18.0,
        isGstInclusive: false,
        freightPaise: 150000,
        otherChargesPaise: 0,
      );
      expect(landedCostPaise, 12540000); // exact ₹125,400.00
    });

    test('3. End-to-End Procurement Lifecycle: Request -> Quotes -> Comparison -> PO -> Outcome -> Memory', () async {
      // Step A: Create Purchase Request
      final pr = await repo.createPurchaseRequest(
        merchantId: testMerchantId,
        title: 'Stainless Steel Sheets',
        itemName: 'Stainless Steel Sheets',
        quantity: 500.0,
        unit: 'kg',
        gradeSpec: 'SS 304',
        dimensions: '2mm 8x4 ft',
        deliveryTimeline: '7 days',
      );
      expect(pr.id, isNotEmpty);

      // Step B: Add Verified Suppliers
      final sup1 = await repo.createSupplier(
        merchantId: testMerchantId,
        name: 'Apex Steels Ltd',
        phoneNumber: '9876543210',
        category: 'Metals & Alloys',
      );
      final sup2 = await repo.createSupplier(
        merchantId: testMerchantId,
        name: 'Metro Metal Mart',
        phoneNumber: '9123456789',
        category: 'Metals & Alloys',
      );

      // Step C: Ingest Real Supplier Quotations
      // Quote 1 (Apex): ₹210/kg, 7-day lead, ₹1500 freight
      final q1 = await repo.createQuotation(
        merchantId: testMerchantId,
        purchaseRequestId: pr.id,
        supplierId: sup1.id,
        supplierName: sup1.name,
        itemName: pr.itemName,
        specification: 'SS 304 2mm 8x4 ft',
        quantity: 500.0,
        unit: 'kg',
        unitPriceMinorUnits: 21000,
        freightMinorUnits: 150000,
        gstRatePercent: 18.0,
        deliveryDays: 7,
      );

      // Quote 2 (Metro): ₹200/kg, 10-day lead, ₹2500 freight
      // Base: 500 * 200 = ₹100,000 + 18% = ₹118,000 + ₹2,500 = ₹120,500 (12,050,000 paise)
      final q2 = await repo.createQuotation(
        merchantId: testMerchantId,
        purchaseRequestId: pr.id,
        supplierId: sup2.id,
        supplierName: sup2.name,
        itemName: pr.itemName,
        specification: 'SS 304 2mm 8x4 ft',
        quantity: 500.0,
        unit: 'kg',
        unitPriceMinorUnits: 20000,
        freightMinorUnits: 250000,
        gstRatePercent: 18.0,
        deliveryDays: 10,
      );

      // Step D: Multi-Attribute Quotation Comparison & Recommendation
      final quotes = await repo.getQuotations(merchantId: testMerchantId, purchaseRequestId: pr.id);
      expect(quotes.length, 2);

      final memories = await repo.getSupplierMemoriesForQuotes(merchantId: testMerchantId, quotes: quotes);
      final comparison = QuotationComparisonEngine.compare(
        quotes,
        requiredSpecification: 'SS 304',
        requiredUnit: 'kg',
        supplierMemories: memories,
      );

      expect(comparison.items.length, 2);
      expect(comparison.hasIncompatibleUnits, isFalse);
      expect(comparison.hasConflictingSpecs, isFalse);
      // Metro Metal Mart has lower landed cost (₹120,500 vs ₹125,400)
      expect(comparison.recommendedQuotationId, q2.id);
      expect(comparison.recommendationReason, contains('Metro Metal Mart'));
      expect(comparison.recommendationReason, contains('Saves ₹4900.00'));

      // Step E: Negotiation Intelligence
      final negotiation = NegotiationIntelligenceEngine.generateInsights(
        currentQuote: q1,
        alternativeQuotes: quotes,
        supplierMemory: memories[sup1.id],
      );
      expect(negotiation.opportunities.isNotEmpty, isTrue);
      expect(negotiation.opportunities.first.evidenceSource, 'ALTERNATIVE_QUOTE');
      expect(negotiation.suggestedCounterofferPaise, 20000); // ₹200.00
      expect(negotiation.draftMessageEnglish, contains('Apex Steels Ltd'));
      expect(negotiation.draftMessageEnglish, contains('₹200.00/kg'));

      // Step F: Purchase Order Review, Approval & Obligation
      final obligation = await repo.approveQuotationAndCreateObligation(
        merchantId: testMerchantId,
        quotationId: q2.id,
        paymentDueDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(obligation.outstandingMinorUnits, q2.totalLandedCostMinorUnits);
      expect(obligation.status, 'PENDING');

      final pos = await repo.getPurchaseOrders(merchantId: testMerchantId);
      expect(pos.length, 1);
      final po = pos.first;
      expect(po.supplierName, 'Metro Metal Mart');
      expect(po.deliveryStatus, 'PENDING');

      // Step G: Record Purchase Outcome & Update Supplier Memory
      await repo.recordPurchaseOutcome(
        merchantId: testMerchantId,
        purchaseOrderId: po.id,
        deliveryStatus: 'DELIVERED_ON_TIME',
        qualityStatus: 'ACCEPTED_GOOD',
        deliveredAt: DateTime.now(),
      );

      // Verify Supplier Memory Updated with Verified Purchase Outcome
      final updatedMemory = await repo.getSupplierMemory(merchantId: testMerchantId, supplierId: sup2.id);
      expect(updatedMemory.hasHistory, isTrue);
      expect(updatedMemory.totalOrdersCompleted, 1);
      expect(updatedMemory.onTimeDeliveries, 1);
      expect(updatedMemory.onTimeRatePercent, 100.0);
      expect(updatedMemory.hasQualityIssues, isFalse);
      expect(updatedMemory.recentPurchases.first.unitPriceInr, 200.0);
    });
  });
}
