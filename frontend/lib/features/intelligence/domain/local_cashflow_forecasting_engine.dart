import 'dart:math';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';

enum ForecastStatus { success, insufficientHistory, error }

class DailyCashFlowProjection {
  final DateTime date;
  final int projectedInflowPaise;
  final int projectedOutflowPaise;
  final int projectedNetPaise;
  final double confidenceScore;

  const DailyCashFlowProjection({
    required this.date,
    required this.projectedInflowPaise,
    required this.projectedOutflowPaise,
    required this.projectedNetPaise,
    required this.confidenceScore,
  });

  double get projectedInflowInr => projectedInflowPaise / 100.0;
  double get projectedOutflowInr => projectedOutflowPaise / 100.0;
  double get projectedNetInr => projectedNetPaise / 100.0;
}

class CashFlowForecastResult {
  final ForecastStatus status;
  final String statusMessage;
  final int forecastHorizonDays;
  final int totalProjectedInflowPaise;
  final int totalProjectedOutflowPaise;
  final int totalProjectedNetPaise;
  final List<DailyCashFlowProjection> dailyProjections;
  final List<String> assumptions;

  const CashFlowForecastResult({
    required this.status,
    required this.statusMessage,
    required this.forecastHorizonDays,
    required this.totalProjectedInflowPaise,
    required this.totalProjectedOutflowPaise,
    required this.totalProjectedNetPaise,
    required this.dailyProjections,
    required this.assumptions,
  });
}

/// Deterministic, on-device Cash Flow Forecasting Engine.
/// Derives projections from confirmed canonical transactions and active payment promises.
/// Strictly returns INSUFFICIENT_HISTORY when data is sparse.
class LocalCashFlowForecastingEngine {
  static const int minTransactionsRequired = 7;
  final LocalDatabaseService _dbService;

  LocalCashFlowForecastingEngine({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Generates a forward-looking cash flow forecast for 7, 14, or 30 days.
  Future<CashFlowForecastResult> generateForecast({
    required String merchantId,
    int horizonDays = 14,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    // 1. Fetch confirmed historical transactions
    final txRows = await driver.query(
      '''
      SELECT transaction_type, amount_minor_units, occurred_at
      FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ORDER BY occurred_at DESC
      LIMIT 180
      ''',
      [merchantId],
    );

    // Guard: Insufficient data check
    if (txRows.length < minTransactionsRequired) {
      return CashFlowForecastResult(
        status: ForecastStatus.insufficientHistory,
        statusMessage: 'Insufficient transaction history. At least $minTransactionsRequired transactions are required to produce an explainable forecast.',
        forecastHorizonDays: horizonDays,
        totalProjectedInflowPaise: 0,
        totalProjectedOutflowPaise: 0,
        totalProjectedNetPaise: 0,
        dailyProjections: const [],
        assumptions: const ['Minimum 7 transactions required for moving baseline calculation.'],
      );
    }

    // 2. Compute historical daily averages (deterministic baseline)
    int histInflows = 0;
    int histOutflows = 0;
    for (final r in txRows) {
      final type = (r['transaction_type'] as String?)?.toUpperCase() ?? 'UNKNOWN';
      final paise = r['amount_minor_units'] as int? ?? 0;
      if (type == 'CREDIT') histInflows += paise;
      if (type == 'DEBIT') histOutflows += paise;
    }

    final double avgDailyInflow = histInflows / max(txRows.length, 1);
    final double avgDailyOutflow = histOutflows / max(txRows.length, 1);

    // 3. Fetch active payment promises due within the forecast horizon
    final now = DateTime.now().toUtc();
    final horizonEnd = now.add(Duration(days: horizonDays));
    final promiseRows = await driver.query(
      '''
      SELECT direction, amount_minor_units, due_date
      FROM ${LocalDatabaseSchema.tablePaymentPromises}
      WHERE merchant_id = ? AND status = 'OPEN' AND due_date >= ? AND due_date <= ?
      ''',
      [merchantId, now.toIso8601String(), horizonEnd.toIso8601String()],
    );

    // Map promises by day offset
    final promiseInflowsByDay = <int, int>{};
    final promiseOutflowsByDay = <int, int>{};

    for (final pr in promiseRows) {
      final dueStr = pr['due_date'] as String? ?? '';
      final dueDate = DateTime.tryParse(dueStr);
      if (dueDate != null) {
        final diffDays = dueDate.difference(now).inDays;
        if (diffDays >= 0 && diffDays < horizonDays) {
          final dir = (pr['direction'] as String?)?.toUpperCase() ?? 'EXPECTED_INCOMING';
          final paise = pr['amount_minor_units'] as int? ?? 0;
          if (dir == 'EXPECTED_INCOMING') {
            promiseInflowsByDay[diffDays] = (promiseInflowsByDay[diffDays] ?? 0) + paise;
          } else {
            promiseOutflowsByDay[diffDays] = (promiseOutflowsByDay[diffDays] ?? 0) + paise;
          }
        }
      }
    }

    // 4. Construct daily projections combining deterministic trend + scheduled promises
    final projections = <DailyCashFlowProjection>[];
    int totalProjInflows = 0;
    int totalProjOutflows = 0;

    for (int d = 0; d < horizonDays; d++) {
      final dayDate = now.add(Duration(days: d));
      final scheduledIn = promiseInflowsByDay[d] ?? 0;
      final scheduledOut = promiseOutflowsByDay[d] ?? 0;

      // Projection = scheduled promises + baseline estimate
      final dayInflow = scheduledIn > 0 ? scheduledIn : avgDailyInflow.round();
      final dayOutflow = scheduledOut > 0 ? scheduledOut : avgDailyOutflow.round();
      final dayNet = dayInflow - dayOutflow;

      totalProjInflows += dayInflow;
      totalProjOutflows += dayOutflow;

      projections.add(DailyCashFlowProjection(
        date: dayDate,
        projectedInflowPaise: dayInflow,
        projectedOutflowPaise: dayOutflow,
        projectedNetPaise: dayNet,
        confidenceScore: scheduledIn > 0 || scheduledOut > 0 ? 0.85 : 0.65,
      ));
    }

    return CashFlowForecastResult(
      status: ForecastStatus.success,
      statusMessage: 'Forecast derived from ${txRows.length} confirmed transactions and ${promiseRows.length} scheduled payment promises.',
      forecastHorizonDays: horizonDays,
      totalProjectedInflowPaise: totalProjInflows,
      totalProjectedOutflowPaise: totalProjOutflows,
      totalProjectedNetPaise: totalProjInflows - totalProjOutflows,
      dailyProjections: projections,
      assumptions: [
        'Historical moving average used as baseline for days without scheduled payment promises.',
        'Open payment promises are assumed to be fulfilled on their specified due date.',
        'Forecast estimates cash movements, not actual guaranteed bank deposits.'
      ],
    );
  }
}
