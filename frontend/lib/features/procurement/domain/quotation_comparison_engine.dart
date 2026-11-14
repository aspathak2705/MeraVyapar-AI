import '../domain/procurement_models.dart';

class QuotationComparisonItem {
  final SupplierQuotationModel quotation;
  final bool isLowestPrice;
  final bool isFastestDelivery;
  final bool isSpecificationMatch;
  final bool isUnitCompatible;
  final bool isIncomplete;
  final List<String> advantages;
  final List<String> warnings;

  const QuotationComparisonItem({
    required this.quotation,
    required this.isLowestPrice,
    required this.isFastestDelivery,
    this.isSpecificationMatch = true,
    this.isUnitCompatible = true,
    this.isIncomplete = false,
    required this.advantages,
    required this.warnings,
  });
}

class QuotationComparisonResult {
  final List<QuotationComparisonItem> items;
  final String? recommendedQuotationId;
  final String recommendationReason;
  final String? lowestPriceQuotationId;
  final String? fastestDeliveryQuotationId;
  final bool hasIncompatibleUnits;
  final bool hasConflictingSpecs;

  const QuotationComparisonResult({
    required this.items,
    this.recommendedQuotationId,
    required this.recommendationReason,
    this.lowestPriceQuotationId,
    this.fastestDeliveryQuotationId,
    this.hasIncompatibleUnits = false,
    this.hasConflictingSpecs = false,
  });
}

/// Deterministic on-device engine for multi-attribute supplier quote comparison.
class QuotationComparisonEngine {
  /// Compare 2 or more quotations for the same purchase request.
  static QuotationComparisonResult compare(
    List<SupplierQuotationModel> quotes, {
    String? requiredUnit,
    String? requiredSpecification,
  }) {
    if (quotes.isEmpty) {
      return const QuotationComparisonResult(
        items: [],
        recommendationReason: 'No quotations available for comparison.',
      );
    }

    // 1. Detect unit compatibility
    final firstUnit = (requiredUnit ?? quotes.first.unit).trim().toLowerCase();
    final unitMismatchExists = quotes.any((q) => q.unit.trim().toLowerCase() != firstUnit);

    // 2. Detect specification conflicts
    final firstSpec = (requiredSpecification ?? quotes.first.specification ?? '').trim().toLowerCase();
    final specConflictExists = requiredSpecification != null &&
        requiredSpecification.trim().isNotEmpty &&
        quotes.any((q) =>
            q.specification != null &&
            q.specification!.trim().isNotEmpty &&
            !q.specification!.trim().toLowerCase().contains(firstSpec));

    if (quotes.length == 1) {
      final q = quotes.first;
      final warnings = <String>[];
      if (q.freightMinorUnits == 0) warnings.add('Freight charges not explicitly itemized');
      if (q.validUntil == null || q.validUntil!.isEmpty) warnings.add('Validity period unstated');
      if (q.specification == null || q.specification!.isEmpty) warnings.add('Specification details unverified');

      final isIncomplete = warnings.isNotEmpty;

      return QuotationComparisonResult(
        items: [
          QuotationComparisonItem(
            quotation: q,
            isLowestPrice: true,
            isFastestDelivery: true,
            isSpecificationMatch: true,
            isUnitCompatible: true,
            isIncomplete: isIncomplete,
            advantages: ['Single available quotation'],
            warnings: warnings,
          ),
        ],
        recommendedQuotationId: q.id,
        recommendationReason: 'Only one quotation submitted.',
        lowestPriceQuotationId: q.id,
        fastestDeliveryQuotationId: q.id,
        hasIncompatibleUnits: false,
        hasConflictingSpecs: false,
      );
    }

    // Determine minimum landed cost and fastest delivery days among unit-compatible quotes
    final comparableQuotes = unitMismatchExists
        ? quotes.where((q) => q.unit.trim().toLowerCase() == firstUnit).toList()
        : quotes;

    final minCost = comparableQuotes.isNotEmpty
        ? comparableQuotes.map((q) => q.totalLandedCostMinorUnits).reduce((a, b) => a < b ? a : b)
        : quotes.map((q) => q.totalLandedCostMinorUnits).reduce((a, b) => a < b ? a : b);

    final minDelivery = quotes.map((q) => q.deliveryDays).reduce((a, b) => a < b ? a : b);

    final comparedItems = <QuotationComparisonItem>[];
    String? lowestPriceId;
    String? fastestDeliveryId;

    for (final q in quotes) {
      final isUnitOk = q.unit.trim().toLowerCase() == firstUnit;
      final isLowest = isUnitOk && (q.totalLandedCostMinorUnits == minCost);
      final isFastest = q.deliveryDays == minDelivery;

      if (isLowest && lowestPriceId == null) lowestPriceId = q.id;
      if (isFastest && fastestDeliveryId == null) fastestDeliveryId = q.id;

      final advantages = <String>[];
      final warnings = <String>[];

      if (isLowest) {
        advantages.add('Lowest total landed cost (₹${q.totalLandedCostInr.toStringAsFixed(2)})');
      }
      if (isFastest) {
        advantages.add('Fastest delivery timeline (${q.deliveryDays} days)');
      }
      if (q.paymentTerms.contains('30') || q.paymentTerms.contains('CREDIT') || q.paymentTerms.contains('NET_')) {
        advantages.add('Flexible payment terms: ${q.paymentTerms}');
      }
      if (q.discountMinorUnits > 0) {
        advantages.add('Itemized discount of ₹${q.discountInr.toStringAsFixed(2)} applied');
      }

      // Check missing fields / warnings
      if (!isUnitOk) {
        warnings.add('Unit mismatch: quoted in "${q.unit}" vs expected "$firstUnit". Normalize before purchase.');
      }
      if (q.isGstInclusive) {
        warnings.add('Quote is GST-inclusive (base ₹${(q.totalLandedCostMinorUnits / 100.0).toStringAsFixed(2)})');
      }
      if (q.freightMinorUnits == 0) {
        warnings.add('Freight charges not explicitly itemized');
      }
      if (q.validUntil == null || q.validUntil!.isEmpty) {
        warnings.add('Validity period unstated');
      }
      if (q.specification == null || q.specification!.isEmpty) {
        warnings.add('Specification details unverified');
      } else if (requiredSpecification != null &&
          requiredSpecification.trim().isNotEmpty &&
          !q.specification!.trim().toLowerCase().contains(firstSpec)) {
        warnings.add('Specification differs: quoted "${q.specification}" vs required "$requiredSpecification"');
      }

      final isIncomplete = q.freightMinorUnits == 0 ||
          (q.validUntil == null || q.validUntil!.isEmpty) ||
          (q.specification == null || q.specification!.isEmpty) ||
          !isUnitOk;

      comparedItems.add(
        QuotationComparisonItem(
          quotation: q,
          isLowestPrice: isLowest,
          isFastestDelivery: isFastest,
          isSpecificationMatch: requiredSpecification == null ||
              q.specification == null ||
              q.specification!.trim().toLowerCase().contains(firstSpec),
          isUnitCompatible: isUnitOk,
          isIncomplete: isIncomplete,
          advantages: advantages,
          warnings: warnings,
        ),
      );
    }

    // Recommendation logic:
    // Only recommend a quote if unit is compatible and spec is matching.
    final eligibleQuotes = comparedItems.where((i) => i.isUnitCompatible && i.isSpecificationMatch).toList();
    final lowestEligible = eligibleQuotes.where((i) => i.isLowestPrice).toList();
    final recommended = lowestEligible.isNotEmpty
        ? lowestEligible.first
        : (eligibleQuotes.isNotEmpty ? eligibleQuotes.first : comparedItems.first);

    String reason;
    if (unitMismatchExists) {
      reason = 'Warning: Conflicting units detected across quotes. Review unit conversions before committing.';
    } else {
      final diffToNext = comparedItems.length > 1 && eligibleQuotes.length > 1
          ? (eligibleQuotes[1].quotation.totalLandedCostInr - eligibleQuotes[0].quotation.totalLandedCostInr).abs()
          : 0.0;

      reason = '${recommended.quotation.supplierName} offers best commercial value with verified landed cost of ₹${recommended.quotation.totalLandedCostInr.toStringAsFixed(2)}.' +
          (diffToNext > 0 ? ' Saves ₹${diffToNext.toStringAsFixed(2)} vs next alternative.' : '') +
          (recommended.isIncomplete ? ' (Note: Incomplete details flagged for verification).' : '');
    }

    return QuotationComparisonResult(
      items: comparedItems,
      recommendedQuotationId: recommended.quotation.id,
      recommendationReason: reason,
      lowestPriceQuotationId: lowestPriceId,
      fastestDeliveryQuotationId: fastestDeliveryId,
      hasIncompatibleUnits: unitMismatchExists,
      hasConflictingSpecs: specConflictExists,
    );
  }
}
