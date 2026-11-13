import '../domain/procurement_models.dart';

class QuotationComparisonItem {
  final SupplierQuotationModel quotation;
  final bool isLowestPrice;
  final bool isFastestDelivery;
  final List<String> advantages;
  final List<String> warnings;

  const QuotationComparisonItem({
    required this.quotation,
    required this.isLowestPrice,
    required this.isFastestDelivery,
    required this.advantages,
    required this.warnings,
  });
}

class QuotationComparisonResult {
  final List<QuotationComparisonItem> items;
  final String? recommendedQuotationId;
  final String recommendationReason;

  const QuotationComparisonResult({
    required this.items,
    this.recommendedQuotationId,
    required this.recommendationReason,
  });
}

/// Deterministic on-device engine for multi-attribute supplier quote comparison.
class QuotationComparisonEngine {
  /// Compare 2 or more quotations for the same purchase request.
  static QuotationComparisonResult compare(List<SupplierQuotationModel> quotes) {
    if (quotes.isEmpty) {
      return const QuotationComparisonResult(
        items: [],
        recommendationReason: 'No quotations available for comparison.',
      );
    }

    if (quotes.length == 1) {
      final q = quotes.first;
      return QuotationComparisonResult(
        items: [
          QuotationComparisonItem(
            quotation: q,
            isLowestPrice: true,
            isFastestDelivery: true,
            advantages: ['Single available quotation'],
            warnings: q.freightMinorUnits == 0 ? ['Freight charges not explicitly itemized'] : [],
          ),
        ],
        recommendedQuotationId: q.id,
        recommendationReason: 'Only one quotation submitted.',
      );
    }

    // Determine minimum landed cost and fastest delivery days
    final minCost = quotes.map((q) => q.totalLandedCostMinorUnits).reduce((a, b) => a < b ? a : b);
    final minDelivery = quotes.map((q) => q.deliveryDays).reduce((a, b) => a < b ? a : b);

    final comparedItems = <QuotationComparisonItem>[];

    for (final q in quotes) {
      final isLowest = q.totalLandedCostMinorUnits == minCost;
      final isFastest = q.deliveryDays == minDelivery;
      final advantages = <String>[];
      final warnings = <String>[];

      if (isLowest) {
        advantages.add('Lowest total landed cost (₹${q.totalLandedCostInr.toStringAsFixed(2)})');
      }
      if (isFastest) {
        advantages.add('Fastest delivery timeline (${q.deliveryDays} days)');
      }
      if (q.paymentTerms.contains('30') || q.paymentTerms.contains('CREDIT')) {
        advantages.add('Flexible payment terms: ${q.paymentTerms}');
      }

      // Check missing fields / warnings
      if (q.freightMinorUnits == 0) {
        warnings.add('Freight not explicitly itemized (verify if included)');
      }
      if (q.validUntil == null || q.validUntil!.isEmpty) {
        warnings.add('Validity period unstated');
      }
      if (q.specification == null || q.specification!.isEmpty) {
        warnings.add('Specification details unverified');
      }

      comparedItems.add(
        QuotationComparisonItem(
          quotation: q,
          isLowestPrice: isLowest,
          isFastestDelivery: isFastest,
          advantages: advantages,
          warnings: warnings,
        ),
      );
    }

    // Recommendation logic: Lowest landed cost with reasonable delivery
    final lowestQuotes = comparedItems.where((i) => i.isLowestPrice).toList();
    final recommended = lowestQuotes.isNotEmpty ? lowestQuotes.first : comparedItems.first;

    final diffToNext = comparedItems.length > 1
        ? (comparedItems[1].quotation.totalLandedCostInr - comparedItems[0].quotation.totalLandedCostInr).abs()
        : 0.0;

    final reason = '${recommended.quotation.supplierName} offers best commercial value with landed cost of ₹${recommended.quotation.totalLandedCostInr.toStringAsFixed(2)}.' +
        (diffToNext > 0 ? ' Saves ₹${diffToNext.toStringAsFixed(2)} vs next alternative.' : '');

    return QuotationComparisonResult(
      items: comparedItems,
      recommendedQuotationId: recommended.quotation.id,
      recommendationReason: reason,
    );
  }
}
