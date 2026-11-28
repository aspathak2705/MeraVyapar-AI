import 'procurement_models.dart';

class NegotiationOpportunity {
  final String title;
  final String description;
  final String evidenceSource; // 'HISTORICAL_PURCHASE', 'ALTERNATIVE_QUOTE', 'COMMERCIAL_TERMS'

  const NegotiationOpportunity({
    required this.title,
    required this.description,
    required this.evidenceSource,
  });
}

class NegotiationInsightResult {
  final SupplierQuotationModel currentQuote;
  final List<NegotiationOpportunity> opportunities;
  final int? suggestedCounterofferPaise;
  final String counterofferRationale;
  final String draftMessageEnglish;
  final String draftMessageHindi;
  final bool hasSufficientEvidence;

  const NegotiationInsightResult({
    required this.currentQuote,
    required this.opportunities,
    this.suggestedCounterofferPaise,
    required this.counterofferRationale,
    required this.draftMessageEnglish,
    required this.draftMessageHindi,
    required this.hasSufficientEvidence,
  });

  double? get suggestedCounterofferInr =>
      suggestedCounterofferPaise != null ? suggestedCounterofferPaise! / 100.0 : null;
}

/// Deterministic, evidence-based negotiation copilot.
/// Generates counteroffers and message drafts grounded strictly in real purchase history and alternative quotations.
class NegotiationIntelligenceEngine {
  static NegotiationInsightResult generateInsights({
    required SupplierQuotationModel currentQuote,
    List<SupplierQuotationModel> alternativeQuotes = const [],
    SupplierMemoryModel? supplierMemory,
  }) {
    final opportunities = <NegotiationOpportunity>[];
    int? suggestedPricePaise;
    String rationale = '';

    // 1. Evidence Check: Compare with Historical Purchase Price
    HistoricalItemPrice? matchingHistory;
    if (supplierMemory != null && supplierMemory.hasHistory) {
      for (final hp in supplierMemory.recentPurchases) {
        if (hp.itemName.trim().toLowerCase() == currentQuote.itemName.trim().toLowerCase()) {
          matchingHistory = hp;
          break;
        }
      }
    }

    if (matchingHistory != null) {
      final priceDiffPaise = currentQuote.unitPriceMinorUnits - matchingHistory.unitPriceMinorUnits;
      if (priceDiffPaise > 0) {
        opportunities.add(
          NegotiationOpportunity(
            title: 'Quote exceeds historical purchase price',
            description:
                'Quoted at ₹${currentQuote.unitPriceInr.toStringAsFixed(2)}/${currentQuote.unit}, which is ₹${(priceDiffPaise / 100.0).toStringAsFixed(2)} higher than previous verified purchase (₹${matchingHistory.unitPriceInr.toStringAsFixed(2)}/${matchingHistory.unit}).',
            evidenceSource: 'HISTORICAL_PURCHASE',
          ),
        );
        suggestedPricePaise = matchingHistory.unitPriceMinorUnits;
        rationale =
            'Grounded in your previous verified purchase of ₹${matchingHistory.unitPriceInr.toStringAsFixed(2)}/${matchingHistory.unit}.';
      } else if (priceDiffPaise == 0) {
        opportunities.add(
          NegotiationOpportunity(
            title: 'Price matches historical baseline',
            description:
                'Unit price identical to previous purchase (₹${matchingHistory.unitPriceInr.toStringAsFixed(2)}/${matchingHistory.unit}). Consider negotiating on freight or payment terms.',
            evidenceSource: 'HISTORICAL_PURCHASE',
          ),
        );
      }
    }

    // 2. Evidence Check: Compare with Alternative Quotes
    SupplierQuotationModel? lowerAlt;
    for (final alt in alternativeQuotes) {
      if (alt.id != currentQuote.id &&
          alt.unit.trim().toLowerCase() == currentQuote.unit.trim().toLowerCase() &&
          alt.unitPriceMinorUnits < currentQuote.unitPriceMinorUnits) {
        if (lowerAlt == null || alt.unitPriceMinorUnits < lowerAlt.unitPriceMinorUnits) {
          lowerAlt = alt;
        }
      }
    }

    if (lowerAlt != null) {
      final altDiffPaise = currentQuote.unitPriceMinorUnits - lowerAlt.unitPriceMinorUnits;
      opportunities.add(
        NegotiationOpportunity(
          title: 'Lower alternative quote available',
          description:
              '${lowerAlt.supplierName} quoted ₹${lowerAlt.unitPriceInr.toStringAsFixed(2)}/${lowerAlt.unit} (saves ₹${(altDiffPaise / 100.0).toStringAsFixed(2)}/unit).',
          evidenceSource: 'ALTERNATIVE_QUOTE',
        ),
      );

      // If no historical price set counteroffer to matching the competitor or slightly below
      if (suggestedPricePaise == null) {
        suggestedPricePaise = lowerAlt.unitPriceMinorUnits;
        rationale = 'Grounded in competing verified quote from ${lowerAlt.supplierName}.';
      }
    }

    // 3. Commercial Terms Check
    if (currentQuote.freightMinorUnits > 0) {
      opportunities.add(
        NegotiationOpportunity(
          title: 'Freight charges negotiable',
          description:
              'Quote includes separate freight of ₹${currentQuote.freightInr.toStringAsFixed(2)}. Ask for supplier-absorbed delivery or combined batch shipment.',
          evidenceSource: 'COMMERCIAL_TERMS',
        ),
      );
    }

    if (currentQuote.paymentTerms == 'ADVANCE_100_PERCENT' ||
        currentQuote.paymentTerms.contains('IMMEDIATE')) {
      opportunities.add(
        NegotiationOpportunity(
          title: 'Strict payment terms',
          description: 'Quoted on 100% advance. Request standard 15-30 day trade credit or 50% dispatch terms.',
          evidenceSource: 'COMMERCIAL_TERMS',
        ),
      );
    }

    final hasEvidence = matchingHistory != null || lowerAlt != null;
    if (!hasEvidence) {
      rationale = 'No historical purchase or lower alternative quote found for direct price benchmarking.';
    }

    // 4. Construct Authentic Draft Messages
    final targetPriceStr = suggestedPricePaise != null
        ? '₹${(suggestedPricePaise / 100.0).toStringAsFixed(2)}'
        : 'a revised competitive price';

    final enDraft = StringBuffer()
      ..write('Dear ${currentQuote.supplierName},\n\n')
      ..write(
          'Thank you for the quotation for ${currentQuote.quantity} ${currentQuote.unit} of ${currentQuote.itemName}${currentQuote.specification != null ? ' (${currentQuote.specification})' : ''}.\n')
      ..write('We reviewed your offer of ₹${currentQuote.unitPriceInr.toStringAsFixed(2)}/${currentQuote.unit}. ');

    if (matchingHistory != null) {
      enDraft.write(
          'Our previous purchase for this item was at ₹${matchingHistory.unitPriceInr.toStringAsFixed(2)}/${matchingHistory.unit}. ');
    } else if (lowerAlt != null) {
      enDraft.write('We have received competitive quotations in the market at $targetPriceStr/${currentQuote.unit}. ');
    }

    enDraft.write(
        'We would like to finalize the purchase order with you at $targetPriceStr/${currentQuote.unit}');
    if (currentQuote.freightMinorUnits > 0) {
      enDraft.write(' inclusive of delivery');
    }
    enDraft.write('.\n\nPlease confirm so we can release the purchase order.\n\nBest regards.');

    final hiDraft = StringBuffer()
      ..write('नमस्ते ${currentQuote.supplierName} जी,\n\n')
      ..write(
          '${currentQuote.itemName} के ${currentQuote.quantity} ${currentQuote.unit} के कोटेशन के लिए धन्यवाद। ')
      ..write('आपका दर ₹${currentQuote.unitPriceInr.toStringAsFixed(2)}/${currentQuote.unit} प्राप्त हुआ। ');

    if (matchingHistory != null) {
      hiDraft.write(
          'हमारी पिछली खरीद ₹${matchingHistory.unitPriceInr.toStringAsFixed(2)}/${matchingHistory.unit} पर हुई थी। ');
    } else if (lowerAlt != null) {
      hiDraft.write('मार्केट में हमें $targetPriceStr/${currentQuote.unit} का प्रतिस्पर्धी भाव मिला है। ');
    }

    hiDraft.write(
        'यदि आप हमें $targetPriceStr/${currentQuote.unit} का भाव दे सकें, तो हम तुरंत ऑर्डर फाइनल करना चाहते हैं।\n\nकृपया पुष्टि करें।\nधन्यवाद।');

    return NegotiationInsightResult(
      currentQuote: currentQuote,
      opportunities: opportunities,
      suggestedCounterofferPaise: suggestedPricePaise,
      counterofferRationale: rationale,
      draftMessageEnglish: enDraft.toString(),
      draftMessageHindi: hiDraft.toString(),
      hasSufficientEvidence: hasEvidence,
    );
  }
}
