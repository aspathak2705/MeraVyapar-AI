import 'package:flutter/material.dart';
import '../domain/receivable_model.dart';

class ReceivableDetailScreen extends StatelessWidget {
  final ReceivableModel receivable;
  final VoidCallback onReviewFollowUp;

  const ReceivableDetailScreen({
    super.key,
    required this.receivable,
    required this.onReviewFollowUp,
  });

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final cpName = receivable.counterpartyName ?? 'Counterparty';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receivable Detail'),
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
                        cpName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expected Amount: ₹${receivable.amount}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 8),
                      Text('Due Date: ${_formatDate(receivable.dueAt)}'),
                      Text('State: ${receivable.state}'),
                      Text('Priority Bucket: ${receivable.priority}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Prioritization Reasons & Provenance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Source Promise ID: ${receivable.sourcePaymentPromiseId}'),
                      const SizedBox(height: 8),
                      const Text('Reason Codes:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...receivable.reasonCodes.map((rc) => Text('• $rc')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.rate_review),
                label: const Text('Review Follow-Up Context'),
                onPressed: onReviewFollowUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
