import 'package:flutter/material.dart';
import '../domain/counterparty_model.dart';

class CounterpartyDetailScreen extends StatelessWidget {
  final CounterpartyModel counterparty;
  final List<FinancialRelationshipEventModel> timeline;

  const CounterpartyDetailScreen({
    super.key,
    required this.counterparty,
    required this.timeline,
  });

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final profile = counterparty.relationshipProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(counterparty.displayName),
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
                        counterparty.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Relationship Type: ${counterparty.relationshipType}'),
                      Text('Status: ${profile?.relationshipStatus ?? counterparty.status}'),
                      if (profile != null) ...[
                        Text('First Interaction: ${_formatDate(profile.firstSeenAt)}'),
                        Text('Last Interaction: ${_formatDate(profile.lastSeenAt)}'),
                        Text('Linked Transactions: ${profile.transactionCount}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Known Aliases',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              if (counterparty.aliases.isEmpty)
                const Text('No aliases registered', style: TextStyle(color: Color(0xFF64748B)))
              else
                Wrap(
                  spacing: 8,
                  children: counterparty.aliases.map((a) => Chip(label: Text(a.aliasValue))).toList(),
                ),
              const SizedBox(height: 24),
              const Text(
                'Relationship Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              if (timeline.isEmpty)
                const Text('No relationship timeline events recorded.', style: TextStyle(color: Color(0xFF64748B)))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: timeline.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ev = timeline[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_note, color: Color(0xFF2563EB)),
                        title: Text(ev.eventType, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_formatDate(ev.occurredAt)),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
