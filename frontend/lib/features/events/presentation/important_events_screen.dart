import 'package:flutter/material.dart';
import '../domain/financial_event_model.dart';

class ImportantEventsScreen extends StatelessWidget {
  final List<FinancialEventModel> events;
  final VoidCallback onRunEvaluation;
  final Function(FinancialEventModel event) onEventTap;

  const ImportantEventsScreen({
    super.key,
    required this.events,
    required this.onRunEvaluation,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Things Needing Your Attention'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Evaluate Events',
            onPressed: onRunEvaluation,
          ),
        ],
      ),
      body: SafeArea(
        child: events.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF166534)),
                      SizedBox(height: 16),
                      Text(
                        'No Important Financial Events Right Now',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No attention events detected from currently available financial evidence and promises.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ev = events[index];
                  final isAttention = ev.severity == 'ATTENTION' || ev.severity == 'URGENT';

                  return Card(
                    color: isAttention ? const Color(0xFFFEF2F2) : Colors.white,
                    child: ListTile(
                      onTap: () => onEventTap(ev),
                      leading: Icon(
                        isAttention ? Icons.warning_amber_rounded : Icons.info_outline,
                        color: isAttention ? const Color(0xFF991B1B) : const Color(0xFF2563EB),
                      ),
                      title: Text(
                        ev.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      subtitle: Text(
                        ev.summary,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAttention ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ev.severity,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAttention ? const Color(0xFF991B1B) : const Color(0xFF1E40AF),
                          ),
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
