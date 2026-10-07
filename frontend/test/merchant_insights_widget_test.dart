import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/intelligence/data/intelligence_repository.dart';
import 'package:frontend/features/intelligence/domain/merchant_insight_model.dart';
import 'package:frontend/features/intelligence/presentation/insight_detail_screen.dart';
import 'package:frontend/features/intelligence/presentation/merchant_insight_card.dart';
import 'package:frontend/features/intelligence/presentation/merchant_insights_screen.dart';

class MockIntelligenceRepository implements IntelligenceRepository {
  List<MerchantInsightItemModel> insightsToReturn = [];
  bool shouldThrow = false;
  String errorMessage = 'Failed to load insights';

  @override
  Future<List<MerchantInsightItemModel>> listInsights({int skip = 0, int limit = 20}) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return insightsToReturn;
  }

  @override
  Future<MerchantInsightItemModel> getInsightDetail(String insightId) async {
    if (shouldThrow) {
      throw Exception(errorMessage);
    }
    return insightsToReturn.firstWhere(
      (i) => i.id == insightId,
      orElse: () => throw Exception('Not found'),
    );
  }

  // Legacy method stubs
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final sampleInsight = MerchantInsightItemModel(
    id: 'ins-123',
    insightType: 'expense_spike',
    title: 'Packaging Expense Surge',
    summary: 'Packaging costs increased by 38% compared to the prior period.',
    financialFacts: const [
      InternalFactDetailModel(
        factId: 'fact-1',
        label: 'Packaging Cost Increase',
        value: '₹13,800 (+38%)',
        metricName: 'packaging_expense',
        currentValue: '13800',
        comparisonValue: '10000',
        percentageChange: '38.0%',
      ),
    ],
    externalSignals: const [
      ExternalSignalDetailModel(
        evidenceId: 'ev-1',
        engine: 'google_shopping',
        title: 'Corrugated Box 10x10 bulk wholesale',
        sourceName: 'IndiaMART',
        price: '₹45/unit',
        sourceUrl: 'https://example.com/boxes',
      ),
    ],
    interpretation: 'Observed packaging paper price inflation in wholesale markets likely contributed to rising costs.',
    groundingStatus: 'SUPPORTED',
    evidenceReferences: const ['ev-1'],
    limitations: const [
      'External market evidence reflects regional wholesale trends and may not match exact supplier terms.',
    ],
    focusEntityId: 'evt-456',
    generatedAt: DateTime.parse('2026-10-07T10:00:00Z'),
    status: 'completed',
  );

  group('MerchantInsightCard Tests', () {
    testWidgets('renders title, summary, fact pills, and grounding badge correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantInsightCard(
              insight: sampleInsight,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Packaging Expense Surge'), findsOneWidget);
      expect(find.text('Packaging costs increased by 38% compared to the prior period.'), findsOneWidget);
      expect(find.text('Packaging Cost Increase: ₹13,800 (+38%)'), findsOneWidget);
      expect(find.text('Supported by Market Evidence'), findsOneWidget);
      expect(find.text('1 external source'), findsOneWidget);
    });
  });

  group('InsightDetailScreen Tests', () {
    testWidgets('displays all four sections: facts, signals, interpretation, limitations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InsightDetailScreen(insight: sampleInsight),
        ),
      );

      // Section Headers
      expect(find.text('YOUR FINANCIAL DATA (VERIFIED FACTS)'), findsOneWidget);
      expect(find.text('EXTERNAL MARKET EVIDENCE (OBSERVED SIGNALS)'), findsOneWidget);
      expect(find.text('MERAVYAPAR INTERPRETATION'), findsOneWidget);
      expect(find.text('LIMITATIONS & SCOPE'), findsOneWidget);

      // Content verification
      expect(find.text('Packaging Cost Increase'), findsOneWidget);
      expect(find.text('₹13,800 (+38%)'), findsOneWidget);
      expect(find.text('Corrugated Box 10x10 bulk wholesale'), findsOneWidget);
      expect(find.textContaining('IndiaMART'), findsOneWidget);
      expect(find.textContaining('₹45/unit'), findsOneWidget);
      expect(find.textContaining('Observed packaging paper price inflation'), findsOneWidget);
      expect(find.textContaining('External market evidence reflects regional'), findsOneWidget);
    });
  });

  group('MerchantInsightsScreen Tests', () {
    late MockIntelligenceRepository mockRepo;

    setUp(() {
      mockRepo = MockIntelligenceRepository();
    });

    testWidgets('renders empty state when no insights exist', (tester) async {
      mockRepo.insightsToReturn = [];

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantInsightsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Financial Insights Yet'), findsOneWidget);
      expect(
        find.text('MeraVyapar will surface important events as your financial activity is analyzed.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error state and retries successfully', (tester) async {
      mockRepo.shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantInsightsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unable to load financial insights. Please retry.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix error and retry
      mockRepo.shouldThrow = false;
      mockRepo.insightsToReturn = [sampleInsight];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Packaging Expense Surge'), findsOneWidget);
    });

    testWidgets('renders list of insights when data is available', (tester) async {
      mockRepo.insightsToReturn = [sampleInsight];

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantInsightsScreen(repository: mockRepo),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Packaging Expense Surge'), findsOneWidget);
      expect(find.byType(MerchantInsightCard), findsOneWidget);
    });
  });
}
