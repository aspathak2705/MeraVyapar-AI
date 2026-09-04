import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memory/presentation/financial_relationships_screen.dart';
import 'package:frontend/features/memory/presentation/payment_promises_screen.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('FinancialRelationshipsScreen renders empty state cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: FinancialRelationshipsScreen(
          counterparties: const [],
          onCounterpartyTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial Relationships'), findsOneWidget);
    expect(find.text('No Financial Counterparties Observed'), findsOneWidget);
  });

  testWidgets('PaymentPromisesScreen renders tab bar and empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: PaymentPromisesScreen(
          promises: const [],
          counterparties: const [],
          onCreatePromise: (_) {},
          onFulfillPromise: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Promises Memory'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Fulfilled'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });
}
