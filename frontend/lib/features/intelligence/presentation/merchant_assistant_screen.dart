import 'package:flutter/material.dart';
import '../domain/grounded_insight_model.dart';

class MerchantAssistantScreen extends StatefulWidget {
  final Function(String question) onQuerySubmit;
  final bool isLoading;
  final FinancialQueryResultModel? lastResult;

  const MerchantAssistantScreen({
    super.key,
    required this.onQuerySubmit,
    this.isLoading = false,
    this.lastResult,
  });

  @override
  State<MerchantAssistantScreen> createState() => _MerchantAssistantScreenState();
}

class _MerchantAssistantScreenState extends State<MerchantAssistantScreen> {
  final _queryController = TextEditingController();

  final List<String> _suggestedPrompts = [
    'What needs my attention?',
    'Why is this payment overdue?',
    'Show pending receivables',
    'Tell me about my customer relationships',
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submitQuery(String q) {
    if (q.trim().isEmpty) return;
    widget.onQuerySubmit(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.lastResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Financial Assistant'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask About Your Business Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Grounded financial queries regarding explicit evidence, receivables, promises, and counterparties.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: 'e.g. What needs my attention?',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _submitQuery(_queryController.text),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _submitQuery,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedPrompts.map((prompt) {
                  return ActionChip(
                    label: Text(prompt),
                    onPressed: () {
                      _queryController.text = prompt;
                      _submitQuery(prompt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (widget.isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (result != null) ...[
                if (!result.isAllowed) ...[
                  Card(
                    color: const Color(0xFFFFFBEB),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFD97706)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.scopeMessage ?? 'This query is out of scope.',
                              style: const TextStyle(color: Color(0xFF92400E), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (result.insight != null) ...[
                  _buildGroundedInsightCard(result.insight!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroundedInsightCard(GroundedInsightModel insight) {
    final isUnavailable = insight.status == 'LLM_INTELLIGENCE_UNAVAILABLE';
    final isRateLimited = insight.status == 'LLM_RATE_LIMITED';

    return Card(
      color: (isUnavailable || isRateLimited) ? const Color(0xFFF8FAFC) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUnavailable || isRateLimited) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRateLimited ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isRateLimited ? 'AI TEMPORARILY BUSY' : 'AI INTELLIGENCE UNAVAILABLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isRateLimited ? const Color(0xFF92400E) : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              insight.summary,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              insight.whyItMatters,
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            if (insight.keyFacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Key Facts:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...insight.keyFacts.map((kf) => Text('• ${kf.label}: ${kf.value}')),
            ],
            if (insight.suggestedActions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Suggested Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...insight.suggestedActions.map((act) => Text('• $act')),
            ],
            if (insight.sourceReferences.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Based On Grounded Evidence:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ...insight.sourceReferences.map((sr) => Text('• ${sr.label ?? sr.entityType}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
            ],
          ],
        ),
      ),
    );
  }
}
