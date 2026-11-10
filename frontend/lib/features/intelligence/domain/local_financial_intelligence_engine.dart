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

  /// Retrieve and deterministically prioritize receivables strictly from local SQLite payment promises.
  /// Categorizes into HIGH, MEDIUM, LOW priority based on overdue age, amount outstanding, and promise status.
  Future<List<Map<String, dynamic>>> getPrioritizedReceivables({
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    final rows = await driver.query(
      '''
      SELECT p.*, c.phone_number as counterparty_phone
      FROM ${LocalDatabaseSchema.tablePaymentPromises} p
      LEFT JOIN ${LocalDatabaseSchema.tableFinancialCounterparties} c
        ON p.counterparty_id = c.id
      WHERE p.merchant_id = ?
        AND UPPER(p.direction) = 'EXPECTED_INCOMING'
        AND UPPER(p.status) NOT IN ('FULFILLED', 'CANCELLED', 'SETTLED')
      ORDER BY p.due_date ASC
      ''',
      [merchantId],
    );

    final List<Map<String, dynamic>> results = [];

    for (final r in rows) {
      final promiseId = r['id'] as String;
      final cpName = r['counterparty_name'] as String? ?? 'Counterparty';
      final cpId = r['counterparty_id'] as String?;
      final amountPaise = r['amount_minor_units'] as int? ?? 0;
      final currency = r['currency'] as String? ?? 'INR';
      final dueDateStr = r['due_date'] as String? ?? nowIso;
      final status = (r['status'] as String? ?? 'OPEN').toUpperCase();

      final dueDate = DateTime.tryParse(dueDateStr) ?? now;
      final diff = now.difference(dueDate);
      final daysOverdue = diff.inDays;

      String state = 'PENDING';
      String priority = 'LOW';
      final List<String> reasonCodes = [];

      if (dueDate.isBefore(now)) {
        state = 'OVERDUE';
        if (daysOverdue > 14) {
          priority = 'HIGH';
          reasonCodes.add('Severely overdue (> 14 days overdue: ${daysOverdue}d)');
        } else if (daysOverdue > 3) {
          priority = 'HIGH';
          reasonCodes.add('Overdue by ${daysOverdue} days');
        } else {
          priority = 'MEDIUM';
          reasonCodes.add('Recently overdue by ${daysOverdue} days');
        }
      } else {
        final daysUntilDue = dueDate.difference(now).inDays;
        if (daysUntilDue <= 3) {
          state = 'DUE_SOON';
          priority = 'MEDIUM';
          reasonCodes.add('Due within 3 days ($daysUntilDue days remaining)');
        } else {
          state = 'PENDING';
          priority = 'LOW';
          reasonCodes.add('Scheduled upcoming receivable');
        }
      }

      // Large outstanding amount escalation (> ₹10,000 = 1,000,000 paise)
      if (amountPaise >= 1000000) {
        if (priority == 'MEDIUM') {
          priority = 'HIGH';
        }
        reasonCodes.add('High value receivable (≥ ₹10,000)');
      }

      results.add({
        'receivable_id': promiseId,
        'counterparty_id': cpId,
        'counterparty_name': cpName,
        'amount': (amountPaise / 100.0).toStringAsFixed(2),
        'currency': currency,
        'due_at': dueDate.toIso8601String(),
        'state': state,
        'priority': priority,
        'reason_codes': reasonCodes,
        'source_payment_promise_id': promiseId,
      });
    }

    // Sort: HIGH first, then MEDIUM, then LOW
    final order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2};
    results.sort((a, b) {
      final cmp = (order[a['priority']] ?? 2).compareTo(order[b['priority']] ?? 2);
      if (cmp != 0) return cmp;
      return (a['due_at'] as String).compareTo(b['due_at'] as String);
    });

    return results;
  }
}
