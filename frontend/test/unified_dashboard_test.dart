import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/actions/domain/communication_action_model.dart';
import 'package:frontend/features/home/presentation/home_shell_screen.dart';
import 'package:frontend/features/intelligence/domain/local_financial_intelligence_engine.dart';
import 'package:frontend/features/intelligence/presentation/unified_financial_intelligence_screen.dart';
import 'package:frontend/features/onboarding/domain/merchant_business_profile.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/l10n/app_localizations_en.dart';
import 'package:frontend/l10n/app_localizations_hi.dart';
import 'package:frontend/l10n/app_localizations_mr.dart';

void main() {
  group('Unified Merchant Dashboard Localization Verification', () {
    test('verifies English dashboard keys', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.financialOverview, equals('Financial Overview'));
      expect(l10n.priorityActions, equals('Priority Actions & Insights'));
      expect(l10n.upcomingObligations, equals('Upcoming Obligations & Promises'));
      expect(l10n.reviewAndSend, equals('Review & Send'));
      expect(l10n.allObligationsSettled, equals('All obligations settled'));
      expect(l10n.shortlistedSuppliers, equals('Shortlisted Suppliers'));
    });

    test('verifies Hindi dashboard keys', () {
      final l10n = AppLocalizationsHi();
      expect(l10n.financialOverview, equals('वित्तीय अवलोकन'));
      expect(l10n.priorityActions, equals('प्राथमिकता कार्य व अंतर्दृष्टी'));
      expect(l10n.upcomingObligations, equals('आगामी देयता व वचने'));
      expect(l10n.reviewAndSend, equals('समीक्षा और भेजें'));
      expect(l10n.allObligationsSettled, equals('सभी देयताएं चुकता हैं'));
      expect(l10n.shortlistedSuppliers, equals('शॉर्टलिस्ट किए गए आपूर्तिकर्ता'));
    });

    test('verifies Marathi dashboard keys', () {
      final l10n = AppLocalizationsMr();
      expect(l10n.financialOverview, equals('आर्थिक आढावा'));
      expect(l10n.priorityActions, equals('प्राधान्य कृती आणि अंतर्दृष्टी'));
      expect(l10n.upcomingObligations, equals('आगामी दायित्वे आणि वचने'));
      expect(l10n.reviewAndSend, equals('तपासा आणि पाठवा'));
      expect(l10n.allObligationsSettled, equals('सर्व दायित्वे पूर्ण आहेत'));
      expect(l10n.shortlistedSuppliers, equals('शॉर्टलिस्ट केलेले पुरवठादार'));
    });
  });

  group('Unified Merchant Dashboard Widget Tests', () {
    testWidgets('renders all unified dashboard sections with genuine data', (tester) async {
      final testProfile = MerchantBusinessProfile(
        merchantId: 'test_m1',
        businessName: 'Sharma General Store',
        businessCategory: 'RETAIL',
        city: 'Pune',
        state: 'Maharashtra',
        updatedAt: DateTime.now().toIso8601String(),
      );

      final testPosition = const FinancialPositionMetrics(
        totalInflowsPaise: 5000000, // ₹50,000
        totalOutflowsPaise: 3000000, // ₹30,000
        netCashMovementPaise: 2000000, // ₹20,000
        totalReceivablesPaise: 1500000, // ₹15,000
        totalOverdueReceivablesPaise: 500000, // ₹5,000
        totalPayablesPaise: 800000, // ₹8,000
        transactionCount: 14,
        openPromiseCount: 3,
        overduePromiseCount: 1,
        counterpartyCount: 5,
        currency: 'INR',
        oldestTransactionDate: '2026-01-01',
        newestTransactionDate: '2026-11-22',
      );

      final testObligations = const DashboardObligationsSummary(
        openPromiseCount: 3,
        openPromiseTotalPaise: 1500000, // ₹15,000
        overduePromiseCount: 1,
        pendingPayableCount: 2,
        pendingPayableTotalPaise: 800000, // ₹8,000
      );

      final testDraft = CommunicationAction(
        id: 'act_1',
        merchantId: 'test_m1',
        actionType: ActionType.paymentReminder,
        channel: CommunicationChannel.whatsApp,
        status: ActionStatus.draft,
        draftContent: 'Namaste Ramesh ji, payment of ₹5,000 is overdue.',
        idempotencyKey: 'idemp_1',
        createdAt: DateTime.now(),
      );

      final testMarket = const DashboardMarketSummary(
        shortlistedCount: 4,
        category: 'RETAIL',
        city: 'Pune',
      );

      bool incomeTapped = false;
      bool expenseTapped = false;
      bool statementTapped = false;
      String? navigatedRoute;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardBusinessProfileProvider.overrideWith((ref) => Future.value(testProfile)),
            financialPositionMetricsProvider.overrideWith((ref) => Future.value(testPosition)),
            dashboardObligationsSummaryProvider.overrideWith((ref) => Future.value(testObligations)),
            dashboardPriorityActionsProvider.overrideWith((ref) => Future.value([testDraft])),
            dashboardMarketSummaryProvider.overrideWith((ref) => Future.value(testMarket)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeShellScreen(
              onAddPaymentReceived: () => incomeTapped = true,
              onAddExpense: () => expenseTapped = true,
              onImportStatement: () => statementTapped = true,
              onNavigateToRoute: (r) => navigatedRoute = r,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Business Profile Context Bar
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('RETAIL'), findsWidgets);
      expect(find.text('Pune, Maharashtra'), findsOneWidget);
      expect(find.text('Private Ledger'), findsWidgets);

      // 2. Verify Financial Overview Hero Card
      expect(find.text('14 txs'), findsOneWidget);
      expect(find.text('₹20,000'), findsOneWidget); // Net Cash Movement
      expect(find.text('₹50,000'), findsOneWidget); // Inflows
      expect(find.text('₹30,000'), findsOneWidget); // Outflows
      expect(find.text('₹15,000'), findsWidgets); // Receivables / Promises

      // 3. Verify Immediate Quick Actions
      expect(find.text('+ Money In'), findsOneWidget);
      expect(find.text('- Money Out'), findsOneWidget);
      expect(find.text('Import Statement'), findsOneWidget);

      await tester.tap(find.text('+ Money In'));
      expect(incomeTapped, isTrue);

      await tester.tap(find.text('- Money Out'));
      expect(expenseTapped, isTrue);

      await tester.tap(find.text('Import Statement'));
      expect(statementTapped, isTrue);

      // 4. Verify Priority Actions Card
      expect(find.text('Priority Actions & Insights'), findsOneWidget);
      expect(find.text('PAYMENT REMINDER'), findsOneWidget);
      expect(find.text('Namaste Ramesh ji, payment of ₹5,000 is overdue.'), findsOneWidget);
      expect(find.text('Review & Send'), findsOneWidget);

      // 5. Verify Upcoming Obligations Card
      expect(find.text('Upcoming Obligations & Promises'), findsOneWidget);
      expect(find.text('3 Open'), findsOneWidget);
      expect(find.text('1 Overdue'), findsOneWidget);
      expect(find.text('2 Pending Obligations'), findsOneWidget);
      expect(find.text('₹8,000'), findsOneWidget); // Payables total

      // 6. Verify VyaparPulse Market Intelligence Card
      expect(find.text('VyaparPulse Market Intelligence'), findsOneWidget);
      expect(find.text('RETAIL · Pune'), findsOneWidget);
      expect(find.text('4 Shortlisted Suppliers'), findsOneWidget);
      expect(find.text('Supplier Shortlist (4)'), findsOneWidget);

      // 7. Verify Financial Services Grid
      expect(find.text('Financial Services'), findsOneWidget);
      expect(find.text('KharidSaathi\nProcurement'), findsOneWidget);

      // Tap on Shortlist button to check navigation callback
      await tester.ensureVisible(find.text('Supplier Shortlist (4)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supplier Shortlist (4)'));
      expect(navigatedRoute, equals('/market/shortlist'));
    });

    testWidgets('renders empty/settled states when no drafts or obligations exist', (tester) async {
      final testProfile = MerchantBusinessProfile(
        merchantId: 'test_m2',
        businessName: 'Patel Enterprise',
        updatedAt: DateTime.now().toIso8601String(),
      );

      final zeroPosition = const FinancialPositionMetrics(
        totalInflowsPaise: 0,
        totalOutflowsPaise: 0,
        netCashMovementPaise: 0,
        totalReceivablesPaise: 0,
        totalOverdueReceivablesPaise: 0,
        totalPayablesPaise: 0,
        transactionCount: 0,
        openPromiseCount: 0,
        overduePromiseCount: 0,
        counterpartyCount: 0,
        currency: 'INR',
        oldestTransactionDate: '',
        newestTransactionDate: '',
      );

      final settledObligations = const DashboardObligationsSummary(
        openPromiseCount: 0,
        openPromiseTotalPaise: 0,
        overduePromiseCount: 0,
        pendingPayableCount: 0,
        pendingPayableTotalPaise: 0,
      );

      final emptyMarket = const DashboardMarketSummary(
        shortlistedCount: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardBusinessProfileProvider.overrideWith((ref) => Future.value(testProfile)),
            financialPositionMetricsProvider.overrideWith((ref) => Future.value(zeroPosition)),
            dashboardObligationsSummaryProvider.overrideWith((ref) => Future.value(settledObligations)),
            dashboardPriorityActionsProvider.overrideWith((ref) => Future.value([])),
            dashboardMarketSummaryProvider.overrideWith((ref) => Future.value(emptyMarket)),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeShellScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify settled obligations message
      expect(find.text('All obligations settled'), findsOneWidget);
      // Verify clean calm priority actions message
      expect(find.text('No Pending Actions'), findsOneWidget);
      expect(find.text('All financial actions and reminders are currently up to date.'), findsOneWidget);
    });
  });
}
