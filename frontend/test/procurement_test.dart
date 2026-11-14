import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/procurement/domain/procurement_models.dart';
import 'package:frontend/features/procurement/domain/quotation_comparison_engine.dart';

void main() {
  group('Financial Precision & Exact Integer Paise Landed Cost Formula', () {
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

    test('calculateLandedCostPaise accurately handles fractional quantities without floating point drift', () {
      // 2.75 meters/kg at ₹345.50 (34550 paise)
      // Gross base = 2.75 * 34550 = 95012.5 -> rounded to 95013 paise
      // 12% GST = 95013 * 0.12 = 11401.56 -> rounded to 11402 paise
      // Freight = 1500 paise
      // Total = 95013 + 11402 + 1500 = 107915 paise
      final landedPaise = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 2.75,
        unitPricePaise: 34550,
        gstPercent: 12.0,
        freightPaise: 1500,
        otherChargesPaise: 0,
      );

      expect(landedPaise, equals(107915));
    });

    test('calculateLandedCostPaise handles GST-inclusive quotes correctly', () {
      // 10 units at ₹118.00 GST-inclusive (11800 paise each) = 118000 paise gross
      // 18% GST inclusive base = 118000 / 1.18 = 100000 paise, Tax = 18000 paise
      // Freight = 2000 paise
      // Total = 118000 + 2000 = 120000 paise
      final landedPaise = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 10.0,
        unitPricePaise: 11800,
        isGstInclusive: true,
        gstPercent: 18.0,
        freightPaise: 2000,
        otherChargesPaise: 0,
      );

      expect(landedPaise, equals(120000));
    });

    test('calculateLandedCostPaise applies discounts before tax', () {
      // 10 units at ₹100.00 (100000 paise base)
      // Discount = ₹100.00 (10000 paise)
      // Taxable subtotal = 90000 paise
      // 18% GST on 90000 = 16200 paise
      // Total = 90000 + 16200 = 106200 paise
      final landedPaise = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 10.0,
        unitPricePaise: 10000,
        discountPaise: 10000,
        gstPercent: 18.0,
        freightPaise: 0,
        otherChargesPaise: 0,
      );

      expect(landedPaise, equals(106200));
    });

    test('calculateLandedCostPaise rejects negative amounts and prevents invalid inputs', () {
      expect(
        () => SupplierQuotationModel.calculateLandedCostPaise(
          quantity: 10.0,
          unitPricePaise: -100,
          gstPercent: 18.0,
          freightPaise: 0,
          otherChargesPaise: 0,
        ),
        throwsArgumentError,
      );

      // Zero quantity returns zero total
      final zeroQty = SupplierQuotationModel.calculateLandedCostPaise(
        quantity: 0.0,
        unitPricePaise: 10000,
        gstPercent: 18.0,
        freightPaise: 0,
        otherChargesPaise: 0,
      );
      expect(zeroQty, equals(0));
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
      expect(result.lowestPriceQuotationId, equals('q2'));
      expect(result.fastestDeliveryQuotationId, equals('q2'));
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
      expect(result.items.first.warnings, contains('Specification details unverified'));
      expect(result.items.first.isIncomplete, isTrue);
    });

    test('compare warns when quotations have conflicting units', () {
      final quoteBags = SupplierQuotationModel(
        id: 'q4',
        merchantId: 'm1',
        purchaseRequestId: 'req2',
        supplierId: 's4',
        supplierName: 'Bags Supplier',
        itemName: 'Flour',
        quantity: 10.0,
        unit: 'bags',
        unitPriceMinorUnits: 50000,
        totalLandedCostMinorUnits: 500000,
        createdAt: DateTime.now(),
      );

      final quoteKg = SupplierQuotationModel(
        id: 'q5',
        merchantId: 'm1',
        purchaseRequestId: 'req2',
        supplierId: 's5',
        supplierName: 'Kg Supplier',
        itemName: 'Flour',
        quantity: 500.0,
        unit: 'kg',
        unitPriceMinorUnits: 900,
        totalLandedCostMinorUnits: 450000,
        createdAt: DateTime.now(),
      );

      final result = QuotationComparisonEngine.compare([quoteBags, quoteKg], requiredUnit: 'bags');
      expect(result.hasIncompatibleUnits, isTrue);
      expect(result.recommendationReason, contains('Conflicting units'));
      expect(result.items.any((i) => !i.isUnitCompatible), isTrue);
    });
  });
}
