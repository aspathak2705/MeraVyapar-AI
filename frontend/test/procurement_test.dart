import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/procurement/domain/procurement_models.dart';
import 'package:frontend/features/procurement/domain/quotation_comparison_engine.dart';

void main() {
  group('Procurement Models & Exact Integer Paise Landed Cost Formula', () {
    test('calculateLandedCostPaise computes exact landed cost with GST and freight', () {
      // 10 units at ₹100.00 (10000 paise each) = ₹1000.00 (100000 paise base)
      // 18% GST = ₹180.00 (18000 paise)
      // Freight = ₹50.00 (5000 paise)
      // Other = ₹20.00 (2000 paise)
      // Expected total = ₹1250.00 (125000 paise)
      final landedPaise = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 10.0,
        unitPricePaise: 10000,
        gstPercent: 18.0,
        freightPaise: 5000,
        otherChargesPaise: 2000,
      );

      expect(landedPaise, equals(125000));
    });

    test('calculateLandedCostPaise handles zero gst and zero additional charges', () {
      final landedPaise = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 4.0,
        unitPricePaise: 25000,
        gstPercent: 0.0,
        freightPaise: 0,
        otherChargesPaise: 0,
      );

      // 4 * 25000 = 100000 paise (₹1000.00)
      expect(landedPaise, equals(100000));
    });
  });

  group('Quotation Comparison Engine', () {
    test('compare returns empty recommendation when no quotes provided', () {
      final result = QuotationComparisonEngine.compare([]);
      expect(result.recommendedQuotationId, isNull);
      expect(result.items, isEmpty);
      expect(result.recommendationReason, contains('No quotations available'));
    });

    test('compare picks lower landed cost and flags trade-offs correctly', () {
      final quoteA = SupplierQuotationModel(
        id: 'q1',
        merchantId: 'm1',
        purchaseRequestId: 'req1',
        supplierId: 's1',
        supplierName: 'Alpha Supplies',
        itemName: 'Cement',
        quantity: 10.0,
        unit: 'bags',
        unitPriceMinorUnits: 10000,
        gstRatePercent: 18.0,
        freightMinorUnits: 5000,
        otherChargesMinorUnits: 0,
        totalLandedCostMinorUnits: 123000, // ₹1230.00
        paymentTerms: 'ADVANCE',
        deliveryDays: 5,
        isAccepted: false,
        createdAt: DateTime.now(),
      );

      final quoteB = SupplierQuotationModel(
        id: 'q2',
        merchantId: 'm1',
        purchaseRequestId: 'req1',
        supplierId: 's2',
        supplierName: 'Beta Wholesalers',
        itemName: 'Cement',
        quantity: 10.0,
        unit: 'bags',
        unitPriceMinorUnits: 9500,
        gstRatePercent: 18.0,
        freightMinorUnits: 2000,
        otherChargesMinorUnits: 0,
        totalLandedCostMinorUnits: 114100, // ₹1141.00 - cheaper landed
        paymentTerms: 'NET_15_DAYS',
        deliveryDays: 2,
        isAccepted: false,
        createdAt: DateTime.now(),
      );

      final result = QuotationComparisonEngine.compare([quoteA, quoteB]);

      expect(result.recommendedQuotationId, equals('q2'));
      expect(result.items.length, equals(2));
      expect(result.recommendationReason, contains('Beta Wholesalers'));
    });

    test('compare flags missing specifications and unstated freight', () {
      final incompleteQuote = SupplierQuotationModel(
        id: 'q3',
        merchantId: 'm1',
        purchaseRequestId: 'req1',
        supplierId: 's3',
        supplierName: 'Gamma Traders',
        itemName: 'Sand',
        quantity: 5.0,
        unit: 'trucks',
        unitPriceMinorUnits: 8000,
        gstRatePercent: 0.0,
        freightMinorUnits: 0,
        otherChargesMinorUnits: 0,
        totalLandedCostMinorUnits: 40000,
        paymentTerms: 'CASH',
        deliveryDays: 1,
        isAccepted: false,
        validUntil: null,
        specification: null,
        createdAt: DateTime.now(),
      );

      final result = QuotationComparisonEngine.compare([incompleteQuote]);
      expect(result.items.first.warnings, contains('Freight charges not explicitly itemized'));
    });
  });
}
