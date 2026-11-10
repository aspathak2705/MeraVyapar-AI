import 'package:flutter/material.dart';
import '../domain/merchant_market_relevance_model.dart';

class RelevantMarketSignalsScreen extends StatelessWidget {
  final List<MerchantMarketRelevanceModel> signals;
  final Function(MerchantMarketRelevanceModel signal) onSignalTap;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  const RelevantMarketSignalsScreen({
    super.key,
    required this.signals,
    required this.onSignalTap,
    required this.onRefresh,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('External Market Signals'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ],
      ),
      body: SafeArea(
        child: signals.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.travel_explore, size: 64, color: Color(0xFF64748B)),
                      SizedBox(height: 16),
                      Text(
                        'No Relevant Market Signals Right Now',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'External market intelligence is continuously evaluated against your declared business profile and context.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: signals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = signals[index];
                  final ev = item.marketEvent;

                  return Card(
                    child: ListTile(
                      onTap: () => onSignalTap(item),
                      leading: const Icon(Icons.public, color: Color(0xFF0284C7)),
                      title: Text(
                        ev?.title ?? 'External Market Signal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        item.explanation ?? ev?.summary ?? 'Potentially relevant market signal',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.relevanceStatus == 'POTENTIALLY_RELEVANT' ? 'POTENTIALLY RELEVANT' : 'MORE CONTEXT NEEDED',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
