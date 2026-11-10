import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/local_financial_intelligence_engine.dart';
import '../domain/local_cashflow_forecasting_engine.dart';
import '../domain/local_fig_service.dart';
import '../../auth/data/local_auth_repository.dart';

// Riverpod Providers for Local Financial Intelligence
final localFinancialIntelligenceEngineProvider = Provider((ref) => LocalFinancialIntelligenceEngine());
final localCashFlowForecastingEngineProvider = Provider((ref) => LocalCashFlowForecastingEngine());
final localFigServiceProvider = Provider((ref) => LocalFinancialIntelligenceGraphService());

final financialPositionMetricsProvider = FutureProvider.autoDispose<FinancialPositionMetrics>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) {
    throw StateError('Merchant session is locked or uninitialized');
  }
  final engine = ref.watch(localFinancialIntelligenceEngineProvider);
  return await engine.calculatePosition(merchantId: merchantId);
});

final topCounterpartiesProvider = FutureProvider.autoDispose<List<CounterpartyConcentration>>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) return [];
  final engine = ref.watch(localFinancialIntelligenceEngineProvider);
  return await engine.getTopCounterparties(merchantId: merchantId);
});

final cashFlowForecastProvider = FutureProvider.autoDispose<CashFlowForecastResult>((ref) async {
  final authRepo = ref.watch(localAuthRepositoryProvider);
  final merchantId = authRepo.activeMerchantId;
  if (merchantId == null) {
    throw StateError('Merchant session is locked or uninitialized');
  }
  final engine = ref.watch(localCashFlowForecastingEngineProvider);
  return await engine.generateForecast(merchantId: merchantId, horizonDays: 14);
});

/// Comprehensive Financial Intelligence Dashboard Screen
class UnifiedFinancialIntelligenceScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  final void Function(String route, [Map<String, dynamic>? args])? onNavigate;

  const UnifiedFinancialIntelligenceScreen({super.key, this.onBack, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(financialPositionMetricsProvider);
    final forecastAsync = ref.watch(cashFlowForecastProvider);
    final counterpartiesAsync = ref.watch(topCounterpartiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial & Business Intelligence'),
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Intelligence',
            onPressed: () {
              ref.invalidate(financialPositionMetricsProvider);
              ref.invalidate(cashFlowForecastProvider);
              ref.invalidate(topCounterpartiesProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(financialPositionMetricsProvider);
            ref.invalidate(cashFlowForecastProvider);
            ref.invalidate(topCounterpartiesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Position Card
                positionAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
                  error: (err, _) => Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Position Calculation Error: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                  data: (metrics) => _buildPositionCard(context, metrics),
                ),
                const SizedBox(height: 20),

                // 2. Cash Flow Forecast Outlook
                const Text('Cash Flow Outlook (14-Day Estimate)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                forecastAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
                  error: (err, _) => Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Forecast Error: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                  data: (forecast) => _buildForecastCard(forecast),
                ),
                const SizedBox(height: 20),

                // 3. Counterparty Concentration
                const Text('Top Counterparty Concentration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                counterpartiesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cps) => _buildCounterpartyList(cps),
                ),
                const SizedBox(height: 20),

                // 4. Grounded AI Financial Explanation Section
                _buildGroundedExplanationCard(context, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionCard(BuildContext context, FinancialPositionMetrics metrics) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Cash Movement', style: TextStyle(color: Colors.grey, fontSize: 14)),
                Text('${metrics.transactionCount} transactions', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₹${metrics.netCashMovementInr.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: metrics.netCashMovementPaise >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Inflows', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('₹${metrics.totalInflowsInr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Outflows', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('₹${metrics.totalOutflowsInr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Receivables Due', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('₹${metrics.totalReceivablesInr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overdue Inflows', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('₹${metrics.totalOverdueReceivablesInr.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                    ],
                  ),
                ),
              ],
            ),
            if (metrics.totalReceivablesPaise > 0 || metrics.totalOverdueReceivablesPaise > 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(
                  metrics.overduePromiseCount > 0
                      ? 'Review ${metrics.overduePromiseCount} Overdue Receivables'
                      : 'Review Prioritized Receivables',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF166534),
                  minimumSize: const Size.fromHeight(40),
                ),
                onPressed: () => onNavigate?.call('/receivables'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard(CashFlowForecastResult forecast) {
    if (forecast.status == ForecastStatus.insufficientHistory) {
      return Card(
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Text('Data Sufficiency Warning', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                ],
              ),
              const SizedBox(height: 8),
              Text(forecast.statusMessage, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Projected 14-Day Net Movement', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Deterministic Forecast', style: TextStyle(fontSize: 10, color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₹${(forecast.totalProjectedNetPaise / 100.0).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: forecast.totalProjectedNetPaise >= 0 ? Colors.green.shade800 : Colors.red.shade800),
            ),
            const SizedBox(height: 12),
            Text(forecast.statusMessage, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const Divider(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(forecast.dailyProjections.length, 5),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final proj = forecast.dailyProjections[idx];
                final dateStr = '${proj.date.day}/${proj.date.month}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('+₹${proj.projectedInflowInr.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Colors.green)),
                      Text('-₹${proj.projectedOutflowInr.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Colors.red)),
                      Text(
                        '₹${proj.projectedNetInr.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: proj.projectedNetPaise >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterpartyList(List<CounterpartyConcentration> counterparties) {
    if (counterparties.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No counterparties identified yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: counterparties.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final cp = counterparties[idx];
          return ListTile(
            title: Text(cp.counterpartyName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${cp.transactionCount} transactions | ${cp.volumePercentage}% of total volume'),
            trailing: Text('₹${(cp.totalVolumePaise / 100.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }

  Widget _buildGroundedExplanationCard(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 20),
                SizedBox(width: 8),
                Text(
                  'Grounded Intelligence Explanations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Nemotron AI provides factual explanations grounded directly in your verified SQLite data snapshot. Zero hallucinations or ledger mutations.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.psychology, size: 16),
                    label: const Text('Ask Assistant', style: TextStyle(fontSize: 13)),
                    onPressed: () => onNavigate?.call('/assistant'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.public, size: 16),
                    label: const Text('Market Signals', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                    onPressed: () => onNavigate?.call('/market'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
