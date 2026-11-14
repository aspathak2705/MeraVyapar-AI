import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../domain/canonical_transaction_model.dart';

class CanonicalTransactionsScreen extends StatelessWidget {
  final List<CanonicalTransactionModel> transactions;
  final bool isLoading;
  final VoidCallback onRunReconciliation;
  final Function(CanonicalTransactionModel tx) onTransactionTap;
  final VoidCallback? onBack;
  final VoidCallback? onAddTransaction;
  final VoidCallback? onImportStatement;

  const CanonicalTransactionsScreen({
    super.key,
    required this.transactions,
    this.isLoading = false,
    required this.onRunReconciliation,
    required this.onTransactionTap,
    this.onBack,
    this.onAddTransaction,
    this.onImportStatement,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passbook & Transactions'),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          tooltip: 'Back',
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (onImportStatement != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import Statement / History',
              onPressed: onImportStatement,
            ),
          IconButton(
            icon: const Icon(AppIcons.refresh),
            tooltip: 'Run Reconciliation Pass',
            onPressed: onRunReconciliation,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onImportStatement != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton.extended(
                heroTag: 'fab_import_statement',
                onPressed: onImportStatement,
                backgroundColor: AppColors.lightLavender,
                foregroundColor: AppColors.primaryPurple,
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                label: const Text('Import Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          if (onAddTransaction != null)
            FloatingActionButton.extended(
              heroTag: 'fab_add_entry',
              onPressed: onAddTransaction,
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.lightLavender,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                AppIcons.transactions,
                                size: 40,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Canonical Transactions Yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add financial evidence or reconcile captured receipts to build your private canonical ledger.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(AppIcons.refresh),
                              label: const Text('Run Reconciliation Pass'),
                              onPressed: onRunReconciliation,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isCredit = tx.transactionType == 'MONEY_IN' || tx.transactionType == 'CREDIT';
                    final status = tx.reconciliationStatus;

                    Color statusColor = AppColors.lightTextMuted;
                    String statusText = 'Unresolved';
                    if (status == 'RECONCILED') {
                      statusColor = AppColors.success;
                      statusText = '✓ Reconciled';
                    } else if (status == 'REQUIRES_REVIEW') {
                      statusColor = AppColors.warning;
                      statusText = 'Needs Review';
                    }

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () => onTransactionTap(tx),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCredit ? AppColors.successLight : AppColors.errorLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit ? AppIcons.inflow : AppIcons.outflow,
                            color: isCredit ? AppColors.success : AppColors.error,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx.counterpartyName ?? tx.description ?? 'Canonical Transaction',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            if (tx.isSimulated || tx.sourceProvider == 'SIMULATED_RAZORPAY') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEMO',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Method: ${tx.paymentMode} • Status: $statusText',
                            style: TextStyle(fontSize: 12, color: statusColor),
                          ),
                        ),
                        trailing: tx.amount != null
                            ? Text(
                                '${isCredit ? "+" : "-"} ₹${tx.amount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: -0.3,
                                  color: isCredit ? AppColors.success : AppColors.error,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
