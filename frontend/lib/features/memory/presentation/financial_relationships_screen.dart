import 'package:flutter/material.dart';
import '../domain/counterparty_model.dart';

class FinancialRelationshipsScreen extends StatelessWidget {
  final List<CounterpartyModel> counterparties;
  final Function(CounterpartyModel cp) onCounterpartyTap;

  const FinancialRelationshipsScreen({
    super.key,
    required this.counterparties,
    required this.onCounterpartyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Relationships'),
      ),
      body: SafeArea(
        child: counterparties.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.people_outline, size: 64, color: Color(0xFF94A3B8)),
                      SizedBox(height: 16),
                      Text(
                        'No Financial Counterparties Observed',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'As financial evidence and canonical transactions are recorded, merchant relationship profiles are built deterministically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: counterparties.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final cp = counterparties[index];
                  final profile = cp.relationshipProfile;

                  return Card(
                    child: ListTile(
                      onTap: () => onCounterpartyTap(cp),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          cp.displayName.isNotEmpty ? cp.displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ),
                      title: Text(
                        cp.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      subtitle: Text(
                        'Type: ${cp.relationshipType} • Transactions: ${profile?.transactionCount ?? 0}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (profile?.relationshipStatus == 'CONFIRMED') ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile?.relationshipStatus ?? 'OBSERVED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (profile?.relationshipStatus == 'CONFIRMED') ? const Color(0xFF166534) : const Color(0xFF475569),
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
