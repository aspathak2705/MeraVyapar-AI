import 'package:flutter/material.dart';

class CashFlowInsightScreen extends StatelessWidget {
  final String status;
  final String? message;
  final double? baselineNet;
  final List<dynamic> scenarios;
  final List<String> limitations;

  const CashFlowInsightScreen({
    super.key,
    required this.status,
    this.message,
    this.baselineNet,
    this.scenarios = const [],
    this.limitations = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isInsufficient = status == 'FORECAST_INSUFFICIENT_DATA';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow Outlook'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isInsufficient) ...[
                Card(
                  color: const Color(0xFFFFFBEB),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            message ?? 'More financial history is needed to generate a meaningful cash-flow outlook.',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF92400E), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  '7-Day Cash Flow Outlook',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Baseline expected net cash flow: ₹${baselineNet?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Scenarios & Stress Tests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...scenarios.map((sc) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: ListTile(
                      title: Text(sc['title'] ?? sc['scenario_type'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(sc['description'] ?? ''),
                      trailing: Text(
                        '₹${sc['net_cashflow']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  );
                }),
              ],
              if (limitations.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Limitations & Assumptions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                ...limitations.map((lim) => Text('• $lim', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
