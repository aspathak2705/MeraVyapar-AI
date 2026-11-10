import 'package:uuid/uuid.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/database/local_database_schema.dart';
import '../domain/counterparty_model.dart';
import '../domain/payment_promise_model.dart';

class LocalMemoryRepository {
  final LocalDatabaseService _dbService;

  LocalMemoryRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Fetch all counterparties for the active merchant.
  Future<List<CounterpartyModel>> getCounterparties({
    required String merchantId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableFinancialCounterparties}
      WHERE merchant_id = ?
      ORDER BY name ASC
      ''',
      [merchantId],
    );

    return rows.map<CounterpartyModel>((row) {
      final now = DateTime.now();
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? now;
      final updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? now;
      final name = (row['name'] ?? row['display_name'] ?? 'Unknown').toString();
      return CounterpartyModel(
        id: row['id'] as String,
        merchantId: row['merchant_id'] as String,
        displayName: name,
        normalizedName: name.trim().toLowerCase(),
        relationshipType: row['category'] as String? ?? 'CUSTOMER',
        status: 'ACTIVE',
        createdAt: createdAt,
        updatedAt: updatedAt,
        aliases: const [],
      );
    }).toList();
  }

  /// Fetch payment promises with proper status filtering.
  Future<List<PaymentPromiseModel>> getPaymentPromises({
    required String merchantId,
    String? status,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    String sql = '''
      SELECT * FROM ${LocalDatabaseSchema.tablePaymentPromises}
      WHERE merchant_id = ?
    ''';
    final params = <dynamic>[merchantId];

    if (status != null) {
      sql += ' AND status = ?';
      params.add(status);
    }
    sql += ' ORDER BY due_date ASC';

    final rows = await driver.query(sql, params);

    return rows.map<PaymentPromiseModel>((row) {
      final minor = row['amount_minor_units'] as int? ?? 0;
      final now = DateTime.now();
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? now;
      final dueAt = DateTime.tryParse(row['due_date']?.toString() ?? '') ?? now;
      final fulfilledAt = row['fulfilled_at'] != null ? DateTime.tryParse(row['fulfilled_at'].toString()) : null;
      return PaymentPromiseModel(
        id: row['id'] as String,
        merchantId: row['merchant_id'] as String,
        counterpartyId: row['counterparty_id'] as String?,
        description: row['notes'] as String? ?? 'Payment Promise',
        promisedAmount: (minor / 100.0).toStringAsFixed(2),
        currency: row['currency'] as String? ?? 'INR',
        promiseDirection: row['direction'] as String? ?? 'EXPECTED_INCOMING',
        dueAt: dueAt,
        status: row['status'] as String? ?? 'OPEN',
        source: row['source'] as String? ?? 'MERCHANT_DECLARED',
        sourceReference: null,
        fulfilledAt: fulfilledAt,
        createdAt: createdAt,
        updatedAt: createdAt,
        events: const [],
      );
    }).toList();
  }

  /// Create a new payment promise atomically.
  Future<PaymentPromiseModel> createPaymentPromise({
    required String merchantId,
    required String counterpartyName,
    required String amount,
    required String direction,
    required String dueDate,
    String? counterpartyId,
    String? notes,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database not initialized');

    final doubleAmount = double.tryParse(amount);
    if (doubleAmount == null) {
      throw ArgumentError('Invalid monetary amount format: $amount');
    }
    final int amountMinor = (doubleAmount * 100).round();
    final promiseId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await driver.execute(
      '''
      INSERT INTO ${LocalDatabaseSchema.tablePaymentPromises} (
        id, merchant_id, counterparty_id, counterparty_name, amount_minor_units,
        currency, direction, status, source, due_date, created_at, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        promiseId,
        merchantId,
        counterpartyId,
        counterpartyName,
        amountMinor,
        'INR',
        direction,
        'OPEN',
        'MERCHANT_DECLARED',
        dueDate,
        nowIso,
        notes,
      ],
    );

    final now = DateTime.now();
    final dueAt = DateTime.tryParse(dueDate) ?? now;
    return PaymentPromiseModel(
      id: promiseId,
      merchantId: merchantId,
      counterpartyId: counterpartyId,
      description: notes ?? 'Payment Promise',
      promisedAmount: (amountMinor / 100.0).toStringAsFixed(2),
      currency: 'INR',
      promiseDirection: direction,
      dueAt: dueAt,
      status: 'OPEN',
      source: 'MERCHANT_DECLARED',
      sourceReference: null,
      fulfilledAt: null,
      createdAt: now,
      updatedAt: now,
      events: const [],
    );
  }

  /// Fulfill a payment promise atomically.
  Future<void> fulfillPromise({
    required String merchantId,
    required String promiseId,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database not initialized');

    final nowIso = DateTime.now().toUtc().toIso8601String();
    await driver.execute(
      '''
      UPDATE ${LocalDatabaseSchema.tablePaymentPromises}
      SET status = 'FULFILLED', fulfilled_at = ?
      WHERE id = ? AND merchant_id = ?
      ''',
      [nowIso, promiseId, merchantId],
    );
  }
}
