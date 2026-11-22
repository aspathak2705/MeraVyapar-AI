import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/counterparty_model.dart';

class FinancialRelationshipsScreen extends StatelessWidget {
  final List<CounterpartyModel> counterparties;
  final Function(CounterpartyModel cp) onCounterpartyTap;
  final VoidCallback? onBack;

  const FinancialRelationshipsScreen({
    super.key,
    required this.counterparties,
    required this.onCounterpartyTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.counterpartyRelationships ?? 'Financial Relationships'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: counterparties.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.noCounterpartiesObserved ?? 'No Financial Counterparties Observed',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n?.noCounterpartiesDesc ?? 'As financial evidence and canonical transactions are recorded, merchant relationship profiles are built deterministically.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
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
                  final isConfirmed = profile?.relationshipStatus == 'CONFIRMED';
                  final statusLabel = isConfirmed
                      ? (l10n?.confirmedStatus ?? 'CONFIRMED')
                      : (l10n?.observedStatus ?? 'OBSERVED');

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
                        '${l10n?.businessType ?? 'Type'}: ${cp.relationshipType} • ${l10n?.transactions ?? 'Transactions'}: ${profile?.transactionCount ?? 0}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConfirmed ? const Color(0xFF166534) : const Color(0xFF475569),
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
