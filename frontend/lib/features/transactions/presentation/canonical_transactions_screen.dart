import 'package:flutter/material.dart';
import '../domain/canonical_transaction_model.dart';

class CanonicalTransactionsScreen extends StatelessWidget {
  final List<CanonicalTransactionModel> transactions;
  final bool isLoading;
  final VoidCallback onRunReconciliation;
  final Function(CanonicalTransactionModel tx) onTransactionTap;

  const CanonicalTransactionsScreen({
    super.key,
    required this.transactions,
    this.isLoading = false,
    required this.onRunReconciliation,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconciled Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Run Reconciliation Pass',
            onPressed: onRunReconciliation,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.compare_arrows, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        const Text(
                          'No reconciled transactions yet.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add financial activity or run reconciliation to connect evidence into canonical financial records.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Run Reconciliation Pass'),
                          onPressed: onRunReconciliation,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isMoneyIn = tx.transactionType == 'MONEY_IN';
                    final status = tx.reconciliationStatus;

                    Color statusColor = const Color(0xFF64748B);
                    String statusText = 'Unresolved';
                    if (status == 'RECONCILED') {
                      statusColor = const Color(0xFF166534);
                      statusText = '✓ Reconciled';
                    } else if (status == 'REQUIRES_REVIEW') {
                      statusColor = const Color(0xFFD97706);
                      statusText = 'Needs Review';
                    }

                    return ListTile(
                      onTap: () => onTransactionTap(tx),
                      leading: CircleAvatar(
                        backgroundColor: isMoneyIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        child: Icon(
                          isMoneyIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isMoneyIn ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                      title: Text(
                        tx.counterpartyName ?? tx.description ?? 'Canonical Transaction',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Method: ${tx.paymentMode} • Linked Evidence: ${tx.candidateLinks.length}\nStatus: $statusText',
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                      trailing: tx.amount != null
                          ? Text(
                              '${isMoneyIn ? "+" : "-"} ₹${tx.amount}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isMoneyIn ? const Color(0xFF166534) : const Color(0xFF991B1B),
                              ),
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}
