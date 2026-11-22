import 'package:flutter/material.dart';
import '../../../../core/money/money.dart';
import '../../../../core/localization/app_date_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../domain/receivable_model.dart';

class ReceivableDetailScreen extends StatelessWidget {
  final ReceivableModel receivable;
  final VoidCallback onReviewFollowUp;
  final VoidCallback? onCreateReminderDraft;
  final VoidCallback? onBack;

  const ReceivableDetailScreen({
    super.key,
    required this.receivable,
    required this.onReviewFollowUp,
    this.onCreateReminderDraft,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cpName = receivable.counterpartyName ?? (l10n?.counterparty ?? 'Counterparty');
    final formattedAmt = Money.formatInr(Money.parseInrToPaise(receivable.amount));
    final formattedDate = AppDateFormatter.formatDateWithContext(context, receivable.dueAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.receivableDetailTitle ?? 'Receivable Detail'),
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
                        '${l10n?.expectedAmount ?? 'Expected Amount'}: $formattedAmt',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 8),
                      Text('${l10n?.dueDate ?? 'Due Date'}: $formattedDate'),
                      Text('${l10n?.state ?? 'State'}: ${receivable.state}'),
                      Text('${l10n?.priorityBucket ?? 'Priority Bucket'}: ${receivable.priority}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.prioritizationReasons ?? 'Prioritization Reasons & Provenance',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n?.sourcePromiseId ?? 'Source Promise ID'}: ${receivable.sourcePaymentPromiseId}'),
                      const SizedBox(height: 8),
                      Text(l10n?.reasonCodes ?? 'Reason Codes:', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...receivable.reasonCodes.map((rc) => Text('• $rc')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (onCreateReminderDraft != null) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: Text(l10n?.createPaymentReminderDraft ?? 'Create Payment Reminder Draft'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onCreateReminderDraft,
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.rate_review),
                label: Text(l10n?.reviewFollowUpContext ?? 'Review Follow-Up Context'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: onReviewFollowUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
