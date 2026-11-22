import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/merchant_market_relevance_model.dart';

class MarketSignalDetailScreen extends StatelessWidget {
  final MerchantMarketRelevanceModel signal;
  final VoidCallback? onBack;
  final Function(MerchantMarketRelevanceModel signal)? onAnalyzeWithFinancials;

  const MarketSignalDetailScreen({
    super.key,
    required this.signal,
    this.onBack,
    this.onAnalyzeWithFinancials,
  });

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ev = signal.marketEvent;
    final src = ev?.source;
    final nature = ev?.evidenceNature ?? src?.evidenceNature ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.marketSignals ?? 'Market Signal Detail'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Headline Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ev?.title ?? 'External Market Signal',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ev?.summary ?? '',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('Event Type: ${ev?.eventType ?? "OTHER"}')),
                          if (ev?.price != null)
                            Chip(
                              backgroundColor: const Color(0xFFDCFCE7),
                              label: Text(
                                'Price: ${ev!.price!}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              ),
                            ),
                          if (ev?.rating != null)
                            Chip(
                              backgroundColor: const Color(0xFFFEF3C7),
                              avatar: const Icon(Icons.star, size: 14, color: Color(0xFFD97706)),
                              label: Text(
                                '${ev!.rating}${ev.reviews != null ? ' (${ev.reviews} reviews)' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ),
                          if (ev?.location != null)
                            Chip(
                              avatar: const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                              label: Text(ev!.location!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Evidence Nature & Safeguard Disclaimer Banner
              if (nature == 'OBSERVED_ONLINE_LISTING' || ev?.price != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.observedPriceDisclaimer ??
                              'Observed Online Listing: This price is observed from online retail listings. It is NOT a verified wholesale quotation. Wholesale rates typically require direct supplier negotiation.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )
              else if (nature == 'DISCOVERED_BUSINESS')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.travel_explore, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.unverifiedDiscoveryDisclaimer ??
                              'Discovered Online Business: Discovered via public search indexing. This business is not a verified trade counterparty. Perform trade due diligence before placing orders.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )
              else if (nature == 'MARKET_NEWS_REPORT')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.newspaper, color: Color(0xFFD97706), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'External Market News: Published by external media. Sourced for general industry awareness. Verify before taking operational or purchasing decisions.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Relevance Context
              const Text(
                'Why This May Matter To Your Business',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFFF0F9FF),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.explanation ?? 'This event matches specific tags in your business profile.',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0369A1), height: 1.4),
                      ),
                      if (signal.reasonCodes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text('Relevance Reasons:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ...signal.reasonCodes.map((rc) => Text('• $rc', style: const TextStyle(color: Color(0xFF334155)))),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Source Provenance
              const Text(
                'Source Provenance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Source Name: ${src?.sourceName ?? "External Feed"}'),
                      const SizedBox(height: 4),
                      Text('Provider: ${src?.providerName ?? "Trusted Market Intelligence"}'),
                      if (src?.sourceUrl != null && src!.sourceUrl.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SelectableText('Source URL: ${src.sourceUrl}', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                      ],
                      if (ev?.occurredAt != null) ...[
                        const SizedBox(height: 4),
                        Text('Published Date: ${_formatDate(ev!.occurredAt!)}'),
                      ],
                      if (ev?.occurredAt == null && ev?.rawOccurredAt != null && ev!.rawOccurredAt!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Published Date: ${ev.rawOccurredAt}'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // AI Market Signal Fusion Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.psychology_outlined),
                  label: Text(l10n?.analyzeImpact ?? 'Analyze Impact on My Business'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onAnalyzeWithFinancials != null
                      ? () => onAnalyzeWithFinancials!(signal)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
