import 'package:flutter/material.dart';
import '../domain/financial_event_model.dart';
import '../../intelligence/domain/grounded_insight_model.dart';

class EventDetailScreen extends StatelessWidget {
  final FinancialEventModel event;
  final VoidCallback onAcknowledge;
  final VoidCallback onDismiss;
  final VoidCallback? onExplainWithAI;
  final bool isExplaining;
  final GroundedInsightModel? aiInsight;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.onAcknowledge,
    required this.onDismiss,
    this.onExplainWithAI,
    this.isExplaining = false,
    this.aiInsight,
  });

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final reasonCode = event.metadataInfo['reason_code'] ?? 'SYSTEM_EVENT';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Detail & Provenance'),
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
                        event.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(event.summary, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Chip(label: Text('Severity: ${event.severity}')),
                          const SizedBox(width: 8),
                          Chip(label: Text('Status: ${event.status}')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (onExplainWithAI != null) ...[
                ElevatedButton.icon(
                  icon: isExplaining ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                  label: Text(isExplaining ? 'Generating Explanation...' : 'Understand This with AI'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
                  onPressed: isExplaining ? null : onExplainWithAI,
                ),
                const SizedBox(height: 16),
              ],
              if (aiInsight != null) ...[
                _buildGroundedInsightBox(aiInsight!),
                const SizedBox(height: 16),
              ],
              const Text(
                'Evidence Provenance & Reason',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reason Code: $reasonCode', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Source Entity Type: ${event.sourceEntityType}'),
                      if (event.sourceEntityId != null) Text('Source Entity ID: ${event.sourceEntityId}'),
                      Text('Detected At: ${_formatDate(event.detectedAt)}'),
                      Text('Occurred At: ${_formatDate(event.occurredAt)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAcknowledge,
                      child: const Text('Acknowledge'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF991B1B)),
                      onPressed: onDismiss,
                      child: const Text('Dismiss Event'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroundedInsightBox(GroundedInsightModel insight) {
    return Card(
      color: const Color(0xFFF0F9FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Color(0xFF0284C7), size: 18),
                SizedBox(width: 8),
                Text('AI Grounded Explanation', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
              ],
            ),
            const SizedBox(height: 8),
            Text(insight.summary, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(insight.whyItMatters, style: const TextStyle(color: Color(0xFF334155), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
