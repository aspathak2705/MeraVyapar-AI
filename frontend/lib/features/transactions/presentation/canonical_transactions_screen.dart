import 'package:flutter/material.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.passbookAndTransactions ?? 'Passbook & Transactions'),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowBack),
          tooltip: l10n?.back ?? 'Back',
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (onImportStatement != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: l10n?.importStatement ?? 'Import Statement',
              onPressed: onImportStatement,
            ),
          IconButton(
            icon: const Icon(AppIcons.refresh),
            tooltip: l10n?.runReconciliationPass ?? 'Run Reconciliation Pass',
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
                            Text(
                              l10n?.noCanonicalTransactions ?? 'No Canonical Transactions Yet',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n?.noCanonicalTransactionsDesc ?? 'Add financial evidence or reconcile captured receipts to build your private canonical ledger.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                if (onAddTransaction != null)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: Text(l10n?.addEntry ?? 'Add Entry'),
                                    onPressed: onAddTransaction,
                                  ),
                                if (onImportStatement != null)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.file_upload_outlined),
                                    label: Text(l10n?.importStatement ?? 'Import Statement'),
                                    onPressed: onImportStatement,
                                  ),
                                TextButton.icon(
                                  icon: const Icon(AppIcons.refresh),
                                  label: Text(l10n?.runReconciliationPass ?? 'Run Reconciliation'),
                                  onPressed: onRunReconciliation,
                                ),
                              ],
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
                          final isCredit = tx.transactionType == 'MONEY_IN' ||
                              tx.transactionType == 'CREDIT';
                          final status = tx.reconciliationStatus;

                          Color statusColor = AppColors.lightTextMuted;
                          String statusText =
                              l10n?.unresolvedStatus ?? 'Unresolved';
                          if (status == 'RECONCILED') {
                            statusColor = AppColors.success;
                            statusText =
                                '✓ ${l10n?.reconciledStatus ?? 'Reconciled'}';
                          } else if (status == 'REQUIRES_REVIEW') {
                            statusColor = AppColors.warning;
                            statusText =
                                l10n?.needsReviewStatus ?? 'Needs Review';
                          }

                          final formattedAmt = tx.amount != null
                              ? '${isCredit ? "+" : "-"} ${Money.formatInr(Money.parseInrToPaise(tx.amount!))}'
                              : null;

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              onTap: () => onTransactionTap(tx),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isCredit
                                      ? AppColors.successLight
                                      : AppColors.errorLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit ? AppIcons.inflow : AppIcons.outflow,
                                  color: isCredit
                                      ? AppColors.success
                                      : AppColors.error,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tx.counterpartyName ??
                                    tx.description ??
                                    'Canonical Transaction',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${l10n?.paymentMethod ?? 'Method'}: ${tx.paymentMode} • ${l10n?.state ?? 'Status'}: $statusText',
                                  style: TextStyle(
                                      fontSize: 12, color: statusColor),
                                ),
                              ),
                              trailing: formattedAmt != null
                                  ? Text(
                                      formattedAmt,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        letterSpacing: -0.3,
                                        color: isCredit
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
      floatingActionButton: onAddTransaction != null
          ? FloatingActionButton(
              tooltip: l10n?.addEntry ?? 'Add Entry',
              onPressed: onAddTransaction,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
