import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/transactions/presentation/canonical_transactions_screen.dart';
import 'package:frontend/features/transactions/presentation/canonical_transaction_detail_screen.dart';
import 'package:frontend/features/transactions/domain/canonical_transaction_model.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('CanonicalTransactionsScreen renders empty state when no transactions exist', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: CanonicalTransactionsScreen(
          transactions: const [],
          onRunReconciliation: () {},
          onTransactionTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No reconciled transactions yet.'), findsOneWidget);
    expect(find.text('Run Reconciliation Pass'), findsOneWidget);
  });

  testWidgets('CanonicalTransactionDetailScreen renders provenance chain', (WidgetTester tester) async {
    const tx = CanonicalTransactionModel(
      id: 'tx-123',
      merchantId: 'm-1',
      amount: '5000.00',
      currency: 'INR',
      transactionType: 'MONEY_OUT',
      paymentMode: 'UPI',
      counterpartyName: 'ABC Traders',
      transactionReference: 'REF98765',
      reconciliationStatus: 'RECONCILED',
      candidateLinks: [
        CandidateLinkSummaryModel(
          id: 'link-1',
          transactionCandidateId: 'cand-1',
          relationshipType: 'PRIMARY',
          linkedAt: '2026-09-03T10:00:00Z',
          linkedBy: 'SYSTEM_RECONCILIATION',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const CanonicalTransactionDetailScreen(transaction: tx),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Traders'), findsOneWidget);
    expect(find.text('RECONCILED'), findsOneWidget);
    expect(find.text('Evidence Provenance Chain'), findsOneWidget);
  });
}
