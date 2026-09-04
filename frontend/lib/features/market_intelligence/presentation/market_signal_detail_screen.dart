import 'package:flutter/material.dart';
import '../domain/merchant_market_relevance_model.dart';

class MarketSignalDetailScreen extends StatelessWidget {
  final MerchantMarketRelevanceModel signal;

  const MarketSignalDetailScreen({
    super.key,
    required this.signal,
  });

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final ev = signal.marketEvent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Signal Detail'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 12),
                      Chip(label: Text('Event Type: ${ev?.eventType ?? "OTHER"}')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Why This May Matter To Your Business',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
                      const Text('Relevance Reasons:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ...signal.reasonCodes.map((rc) => Text('• $rc', style: const TextStyle(color: Color(0xFF334155)))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Source Provenance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Source Name: ${ev?.source?.sourceName ?? "External Feed"}'),
                      Text('Provider: ${ev?.source?.providerName ?? "Trusted Market Intelligence"}'),
                      if (ev?.source?.sourceUrl != null && ev!.source!.sourceUrl.isNotEmpty)
                        Text('URL: ${ev.source!.sourceUrl}'),
                      if (ev?.occurredAt != null)
                        Text('Published Date: ${_formatDate(ev!.occurredAt)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
