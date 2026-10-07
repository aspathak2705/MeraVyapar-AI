import 'package:flutter/material.dart';
import '../domain/merchant_insight_model.dart';

class InsightDetailScreen extends StatelessWidget {
  final MerchantInsightItemModel insight;

  const InsightDetailScreen({
    super.key,
    required this.insight,
  });

  Color _getBadgeColor(String status) {
    switch (status) {
      case 'STRONGLY_SUPPORTED':
      case 'SUPPORTED':
        return const Color(0xFF15803D);
      case 'POTENTIAL_CONNECTION':
        return const Color(0xFFD97706);
      case 'INSUFFICIENT_EVIDENCE':
        return const Color(0xFF64748B);
      case 'CONFLICTING_EVIDENCE':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getBadgeColor(insight.groundingStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insight & Evidence'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & Grounding Badge
              Text(
                insight.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'GROUNDING: ${insight.groundingStatus}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Overview Summary
              Text(
                insight.summary,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 1: Internal Financial Facts
              const Text(
                'YOUR FINANCIAL DATA (VERIFIED FACTS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (insight.financialFacts.isEmpty)
                const Text('No detailed metric breakdowns attached.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
              else
                ...insight.financialFacts.map((fact) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(fact.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(
                              fact.value,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 24),

              // SECTION 2: External Market Signals (Observed Evidence)
              const Text(
                'EXTERNAL MARKET EVIDENCE (OBSERVED SIGNALS)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (insight.externalSignals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No external market evidence available for this event.',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 13),
                  ),
                )
              else
                ...insight.externalSignals.map((sig) => _buildExternalSignalCard(sig)),
              const SizedBox(height: 24),

              // SECTION 3: MeraVyapar AI Interpretation
              const Text(
                'MERAVYAPAR INTERPRETATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFDCFCE7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight.interpretation.isNotEmpty
                              ? insight.interpretation
                              : 'No external connection established.',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF166534), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 4: Limitations & Grounding Caveats
              if (insight.limitations.isNotEmpty) ...[
                const Text(
                  'LIMITATIONS & SCOPE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...insight.limitations.map(
                  (lim) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            lim,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExternalSignalCard(ExternalSignalDetailModel sig) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    sig.sourceName ?? 'Market Source',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ),
                if (sig.price != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Observed: ${sig.price}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sig.title ?? (sig.claim ?? 'Market Signal'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            if (sig.snippet != null && sig.snippet!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sig.snippet!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
            if (sig.location != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(sig.location!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
