import 'package:flutter/material.dart';
import '../../../core/money/money.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/canonical_transaction_model.dart';

class CanonicalTransactionDetailScreen extends StatelessWidget {
  final CanonicalTransactionModel transaction;
  final VoidCallback? onBack;

  const CanonicalTransactionDetailScreen({
    super.key,
    required this.transaction,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMoneyIn = transaction.transactionType == 'MONEY_IN';
    final status = transaction.reconciliationStatus;
    final formattedAmt = transaction.amount != null
        ? '${isMoneyIn ? "+" : "-"} ${Money.formatInr(Money.parseInrToPaise(transaction.amount!))}'
        : null;

    final isReconciled = status == 'RECONCILED';
    final statusText = isReconciled
        ? (l10n?.reconciledStatus ?? 'Reconciled')
        : (status == 'REQUIRES_REVIEW' ? (l10n?.needsReviewStatus ?? 'Needs Review') : (l10n?.unresolvedStatus ?? status));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.transactionDetailProvenance ?? 'Transaction Detail & Provenance'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n?.back ?? 'Back',
                onPressed: onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            transaction.counterpartyName ?? (l10n?.counterparty ?? 'Canonical Record'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isReconciled
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isReconciled
                                    ? const Color(0xFF166534)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (formattedAmt != null)
                        Text(
                          formattedAmt,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isMoneyIn ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('${l10n?.paymentMethod ?? 'Payment Mode'}: ${transaction.paymentMode}', style: const TextStyle(color: Color(0xFF64748B))),
                      if (transaction.transactionReference != null)
                        Text('${l10n?.reference ?? 'Reference'}: ${transaction.transactionReference}', style: const TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.evidenceProvenanceChain ?? 'Evidence Provenance Chain',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Canonical transactions map directly to underlying evidence candidates without overwriting original records.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (transaction.candidateLinks.isEmpty)
                const Text('No candidate links recorded.', style: TextStyle(color: Color(0xFF94A3B8)))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transaction.candidateLinks.length,
                  itemBuilder: (context, index) {
                    final link = transaction.candidateLinks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.link, color: Color(0xFF2563EB)),
                        title: Text('Candidate ID: ${link.transactionCandidateId}'),
                        subtitle: Text('Relationship: ${link.relationshipType} • Linked By: ${link.linkedBy}'),
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
