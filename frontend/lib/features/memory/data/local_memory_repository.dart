import 'package:uuid/uuid.dart';
import '../../core/database/local_database_service.dart';
import '../../core/database/local_database_schema.dart';
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

    return rows.map((row) {
      return CounterpartyModel(
        id: row['id'] as String,
        merchantId: row['merchant_id'] as String,
        name: row['name'] as String,
        phoneNumber: row['phone_number'] as String?,
        category: row['category'] as String? ?? 'CUSTOMER',
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
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

    return rows.map((row) {
      final minor = row['amount_minor_units'] as int;
      return PaymentPromiseModel(
        id: row['id'] as String,
        merchantId: row['merchant_id'] as String,
        counterpartyId: row['counterparty_id'] as String?,
        counterpartyName: row['counterparty_name'] as String,
        amount: (minor / 100.0).toStringAsFixed(2),
        currency: row['currency'] as String? ?? 'INR',
        direction: row['direction'] as String,
        status: row['status'] as String,
        source: row['source'] as String,
        dueDate: row['due_date'] as String,
        createdAt: row['created_at'] as String,
        fulfilledAt: row['fulfilled_at'] as String?,
        notes: row['notes'] as String?,
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

    return PaymentPromiseModel(
      id: promiseId,
      merchantId: merchantId,
      counterpartyId: counterpartyId,
      counterpartyName: counterpartyName,
      amount: (amountMinor / 100.0).toStringAsFixed(2),
      currency: 'INR',
      direction: direction,
      status: 'OPEN',
      source: 'MERCHANT_DECLARED',
      dueDate: dueDate,
      createdAt: nowIso,
      notes: notes,
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
