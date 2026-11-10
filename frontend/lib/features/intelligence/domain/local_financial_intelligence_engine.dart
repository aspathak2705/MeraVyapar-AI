import 'dart:math';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';

class FinancialPositionMetrics {
  final int totalInflowsPaise;
  final int totalOutflowsPaise;
  final int netCashMovementPaise;
  final int totalReceivablesPaise;
  final int totalOverdueReceivablesPaise;
  final int totalPayablesPaise;
  final int transactionCount;
  final int openPromiseCount;
  final int overduePromiseCount;
  final int counterpartyCount;
  final String currency;
  final String oldestTransactionDate;
  final String newestTransactionDate;

  const FinancialPositionMetrics({
    required this.totalInflowsPaise,
    required this.totalOutflowsPaise,
    required this.netCashMovementPaise,
    required this.totalReceivablesPaise,
    required this.totalOverdueReceivablesPaise,
    required this.totalPayablesPaise,
    required this.transactionCount,
    required this.openPromiseCount,
    required this.overduePromiseCount,
    required this.counterpartyCount,
    required this.currency,
    required this.oldestTransactionDate,
    required this.newestTransactionDate,
  });

  double get totalInflowsInr => totalInflowsPaise / 100.0;
  double get totalOutflowsInr => totalOutflowsPaise / 100.0;
  double get netCashMovementInr => netCashMovementPaise / 100.0;
  double get totalReceivablesInr => totalReceivablesPaise / 100.0;
  double get totalOverdueReceivablesInr => totalOverdueReceivablesPaise / 100.0;
  double get totalPayablesInr => totalPayablesPaise / 100.0;
}

class CounterpartyConcentration {
  final String counterpartyName;
  final int totalVolumePaise;
  final double volumePercentage;
  final int transactionCount;

  const CounterpartyConcentration({
    required this.counterpartyName,
    required this.totalVolumePaise,
    required this.volumePercentage,
    required this.transactionCount,
  });
}

/// Deterministic on-device Financial Intelligence Engine.
/// Computes explainable financial positions and metrics strictly from confirmed SQLite records.
class LocalFinancialIntelligenceEngine {
  final LocalDatabaseService _dbService;

  LocalFinancialIntelligenceEngine({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Calculate comprehensive financial position metrics for the active merchant.
  Future<FinancialPositionMetrics> calculatePosition({
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Local database driver not initialized');

    // 1. Inflows & Outflows from Canonical Transactions
    final txRows = await driver.query(
      '''
      SELECT transaction_type, amount_minor_units, occurred_at
      FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ORDER BY occurred_at ASC
      ''',
      [merchantId],
    );

    int totalInflows = 0;
    int totalOutflows = 0;
    String oldestTx = '';
    String newestTx = '';

    for (int i = 0; i < txRows.length; i++) {
      final r = txRows[i];
      final type = (r['transaction_type'] as String?)?.toUpperCase() ?? 'UNKNOWN';
      final paise = r['amount_minor_units'] as int? ?? 0;
      final occurred = r['occurred_at'] as String? ?? '';

      if (i == 0) oldestTx = occurred;
      newestTx = occurred;

      if (type == 'CREDIT') {
        totalInflows += paise;
      } else if (type == 'DEBIT') {
        totalOutflows += paise;
      }
    }

    final netCashMovement = totalInflows - totalOutflows;

    // 2. Receivables and Payables from Payment Promises
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final promiseRows = await driver.query(
      '''
      SELECT direction, status, amount_minor_units, due_date
      FROM ${LocalDatabaseSchema.tablePaymentPromises}
      WHERE merchant_id = ? AND status != 'CANCELLED'
      ''',
      [merchantId],
    );

    int totalReceivables = 0;
    int totalOverdueReceivables = 0;
    int totalPayables = 0;
    int openCount = 0;
    int overdueCount = 0;

    for (final pr in promiseRows) {
      final dir = (pr['direction'] as String?)?.toUpperCase() ?? 'EXPECTED_INCOMING';
      final status = (pr['status'] as String?)?.toUpperCase() ?? 'OPEN';
      final paise = pr['amount_minor_units'] as int? ?? 0;
      final dueDate = pr['due_date'] as String? ?? '';
      final isOverdue = dueDate.isNotEmpty && dueDate.compareTo(nowIso) < 0;

      if (status == 'OPEN' || status == 'OVERDUE') {
        openCount++;
        if (dir == 'EXPECTED_INCOMING') {
          totalReceivables += paise;
          if (isOverdue || status == 'OVERDUE') {
            overdueCount++;
            totalOverdueReceivables += paise;
          }
        } else if (dir == 'EXPECTED_OUTGOING') {
          totalPayables += paise;
        }
      }
    }

    // 3. Counterparty count
    final cpRows = await driver.query(
      '''
      SELECT COUNT(*) as count FROM ${LocalDatabaseSchema.tableFinancialCounterparties}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );
    final cpCount = cpRows.isNotEmpty ? (cpRows.first['count'] as int? ?? 0) : 0;

    return FinancialPositionMetrics(
      totalInflowsPaise: totalInflows,
      totalOutflowsPaise: totalOutflows,
      netCashMovementPaise: netCashMovement,
      totalReceivablesPaise: totalReceivables,
      totalOverdueReceivablesPaise: totalOverdueReceivables,
      totalPayablesPaise: totalPayables,
      transactionCount: txRows.length,
      openPromiseCount: openCount,
      overduePromiseCount: overdueCount,
      counterpartyCount: cpCount,
      currency: 'INR',
      oldestTransactionDate: oldestTx,
      newestTransactionDate: newestTx,
    );
  }

  /// Analyze counterparty concentration to identify customer/supplier dependency.
  Future<List<CounterpartyConcentration>> getTopCounterparties({
    required String merchantId,
    int limit = 5,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    final rows = await driver.query(
      '''
      SELECT counterparty_name, SUM(amount_minor_units) as total_volume, COUNT(*) as tx_count
      FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ? AND counterparty_name IS NOT NULL
      GROUP BY counterparty_name
      ORDER BY total_volume DESC
      LIMIT ?
      ''',
      [merchantId, limit],
    );

    // Get total overall volume to compute percentages
    final totalRows = await driver.query(
      '''
      SELECT SUM(amount_minor_units) as grand_total
      FROM ${LocalDatabaseSchema.tableCanonicalTransactions}
      WHERE merchant_id = ?
      ''',
      [merchantId],
    );
    final grandTotal = totalRows.isNotEmpty ? (totalRows.first['grand_total'] as int? ?? 1) : 1;

    return rows.map((r) {
      final name = r['counterparty_name'] as String? ?? 'Unknown';
      final vol = r['total_volume'] as int? ?? 0;
      final count = r['tx_count'] as int? ?? 0;
      final pct = grandTotal > 0 ? (vol / grandTotal) * 100.0 : 0.0;

      return CounterpartyConcentration(
        counterpartyName: name,
        totalVolumePaise: vol,
        volumePercentage: double.parse(pct.toStringAsFixed(1)),
        transactionCount: count,
      );
    }).toList();
  }
}
