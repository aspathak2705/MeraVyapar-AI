import 'package:flutter/material.dart';
import '../domain/receivable_model.dart';

class ReceivablesScreen extends StatelessWidget {
  final List<ReceivableModel> receivables;
  final Function(ReceivableModel item) onReceivableTap;

  const ReceivablesScreen({
    super.key,
    required this.receivables,
    required this.onReceivableTap,
  });

  String _formatDate(DateTime dt) {
    return dt.toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final highPriority = receivables.where((r) => r.priority == 'HIGH').toList();
    final mediumPriority = receivables.where((r) => r.priority == 'MEDIUM').toList();
    final lowPriority = receivables.where((r) => r.priority == 'LOW').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prioritized Receivables'),
      ),
      body: SafeArea(
        child: receivables.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.monetization_on_outlined, size: 64, color: Color(0xFF94A3B8)),
                      SizedBox(height: 16),
                      Text(
                        'No Outstanding Receivables',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Receivables originate strictly from explicit incoming payment promises. None are currently pending.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highPriority.isNotEmpty) ...[
                      _buildSectionHeader('HIGH PRIORITY', const Color(0xFF991B1B)),
                      ...highPriority.map((r) => _buildReceivableCard(r)),
                      const SizedBox(height: 16),
                    ],
                    if (mediumPriority.isNotEmpty) ...[
                      _buildSectionHeader('MEDIUM PRIORITY', const Color(0xFFD97706)),
                      ...mediumPriority.map((r) => _buildReceivableCard(r)),
                      const SizedBox(height: 16),
                    ],
                    if (lowPriority.isNotEmpty) ...[
                      _buildSectionHeader('LOW PRIORITY', const Color(0xFF1E40AF)),
                      ...lowPriority.map((r) => _buildReceivableCard(r)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildReceivableCard(ReceivableModel r) {
    final cpName = r.counterpartyName ?? 'Counterparty';
    final isOverdue = r.state == 'OVERDUE';

    return Card(
      child: ListTile(
        onTap: () => onReceivableTap(r),
        leading: Icon(
          Icons.arrow_downward,
          color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF166534),
        ),
        title: Text(cpName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Due: ${_formatDate(r.dueAt)} • State: ${r.state}'),
        trailing: Text(
          '₹${r.amount}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF166534),
          ),
        ),
      ),
    );
  }
}
