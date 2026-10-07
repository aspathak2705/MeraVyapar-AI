import 'package:flutter/material.dart';
import '../domain/merchant_insight_model.dart';
import 'insight_detail_screen.dart';

class MerchantInsightCard extends StatelessWidget {
  final MerchantInsightItemModel insight;
  final VoidCallback? onTap;

  const MerchantInsightCard({
    super.key,
    required this.insight,
    this.onTap,
  });

  Color _getGroundingBadgeColor(String status) {
    switch (status) {
      case 'STRONGLY_SUPPORTED':
      case 'SUPPORTED':
        return const Color(0xFF15803D); // Green
      case 'POTENTIAL_CONNECTION':
        return const Color(0xFFD97706); // Amber
      case 'INSUFFICIENT_EVIDENCE':
        return const Color(0xFF64748B); // Slate
      case 'CONFLICTING_EVIDENCE':
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF475569);
    }
  }

  String _formatGroundingLabel(String status) {
    switch (status) {
      case 'STRONGLY_SUPPORTED':
        return 'Strong Market Evidence';
      case 'SUPPORTED':
        return 'Supported by Market Evidence';
      case 'POTENTIAL_CONNECTION':
        return 'Potential Market Connection';
      case 'INSUFFICIENT_EVIDENCE':
        return 'Insufficient External Evidence';
      case 'CONFLICTING_EVIDENCE':
        return 'Mixed Market Signals';
      case 'AI_INSIGHT_UNAVAILABLE':
        return 'Market Explanation Unavailable';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getGroundingBadgeColor(insight.groundingStatus);
    final badgeLabel = _formatGroundingLabel(insight.groundingStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => InsightDetailScreen(insight: insight),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Tag & Grounding Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FINANCIAL INTELLIGENCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title (Level 1: What happened)
              Text(
                insight.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              // Summary
              Text(
                insight.summary,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF334155),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),

              // Internal Fact Pills (if available)
              if (insight.financialFacts.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: insight.financialFacts.take(2).map((fact) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${fact.label}: ${fact.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Evidence Count & Action Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.travel_explore, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        insight.evidenceReferences.isNotEmpty
                            ? '${insight.evidenceReferences.length} external source${insight.evidenceReferences.length > 1 ? 's' : ''}'
                            : 'No external sources',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Row(
                    children: const [
                      Text(
                        'View evidence',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
