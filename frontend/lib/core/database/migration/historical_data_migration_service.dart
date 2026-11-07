import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/database/local_database_service.dart';
import '../../core/database/local_database_schema.dart';

class MigrationResult {
  final bool success;
  final int recordsMigrated;
  final String checksum;
  final String? errorMessage;

  const MigrationResult({
    required this.success,
    required this.recordsMigrated,
    required this.checksum,
    this.errorMessage,
  });
}

/// Service executing idempotent, atomic migration of historical financial data
/// from PostgreSQL export payload into local SQLite database.
class HistoricalDataMigrationService {
  final LocalDatabaseService _dbService;

  HistoricalDataMigrationService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Check whether migration has already been executed for this source payload.
  Future<bool> isMigrationCompleted(String migrationKey) async {
    final driver = _dbService.driver;
    if (driver == null) return false;

    final rows = await driver.query(
      '''
      SELECT migration_key FROM ${LocalDatabaseSchema.tableMigrationMetadata}
      WHERE migration_key = ?
      ''',
      [migrationKey],
    );
    return rows.isNotEmpty;
  }

  /// Atomically ingest historical PostgreSQL export JSON.
  Future<MigrationResult> ingestHistoricalData({
    required String migrationKey,
    required Map<String, dynamic> exportData,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) {
      return const MigrationResult(
        success: false,
        recordsMigrated: 0,
        checksum: '',
        errorMessage: 'Local database driver is not initialized',
      );
    }

    if (await isMigrationCompleted(migrationKey)) {
      return MigrationResult(
        success: true,
        recordsMigrated: 0,
        checksum: 'ALREADY_COMPLETED',
      );
    }

    final rawJsonString = jsonEncode(exportData);
    final calculatedChecksum = sha256.convert(utf8.encode(rawJsonString)).toString();

    int totalCount = 0;

    try {
      await driver.transaction((txn) async {
        // 1. Ingest Merchant Profile
        final merchant = exportData['merchant'] as Map<String, dynamic>?;
        if (merchant != null) {
          await txn.execute(
            '''
            INSERT OR REPLACE INTO ${LocalDatabaseSchema.tableMerchantProfile} (
              id, display_name, phone_number, business_category, currency,
              created_at, updated_at, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              merchant['id'],
              merchant['display_name'],
              merchant['phone_number'],
              merchant['business_category'],
              merchant['currency'] ?? 'INR',
              merchant['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
              merchant['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
              merchant['status'] ?? 'ACTIVE',
            ],
          );
          totalCount++;
        }

        // 2. Ingest Counterparties
        final counterparties = exportData['counterparties'] as List? ?? [];
        for (final cp in counterparties) {
          await txn.execute(
            '''
            INSERT OR REPLACE INTO ${LocalDatabaseSchema.tableFinancialCounterparties} (
              id, merchant_id, name, phone_number, category, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              cp['id'],
              cp['merchant_id'],
              cp['name'],
              cp['phone_number'],
              cp['category'] ?? 'CUSTOMER',
              cp['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
              cp['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
            ],
          );
          totalCount++;
        }

        // 3. Ingest Canonical Transactions
        final transactions = exportData['transactions'] as List? ?? [];
        for (final tx in transactions) {
          int? minorUnits;
          if (tx['amount_minor_units'] != null) {
            minorUnits = tx['amount_minor_units'] as int;
          } else if (tx['amount'] != null) {
            final doubleVal = double.tryParse(tx['amount'].toString());
            if (doubleVal != null) {
              minorUnits = (doubleVal * 100).round();
            }
          }

          await txn.execute(
            '''
            INSERT OR REPLACE INTO ${LocalDatabaseSchema.tableCanonicalTransactions} (
              id, merchant_id, amount_minor_units, currency, transaction_type,
              payment_mode, counterparty_name, counterparty_id, transaction_reference,
              description, occurred_at, reconciliation_status, source_type,
              source_provider, is_simulated, idempotency_key, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              tx['id'],
              tx['merchant_id'],
              minorUnits,
              tx['currency'] ?? 'INR',
              tx['transaction_type'] ?? 'UNKNOWN',
              tx['payment_mode'] ?? 'UNKNOWN',
              tx['counterparty_name'],
              tx['counterparty_id'],
              tx['transaction_reference'],
              tx['description'],
              tx['occurred_at'],
              tx['reconciliation_status'] ?? 'UNRESOLVED',
              tx['source_type'] ?? 'MIGRATED',
              tx['source_provider'] ?? 'POSTGRESQL_MIGRATION',
              0,
              tx['idempotency_key'] ?? 'migrated_${tx['id']}',
              tx['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
            ],
          );
          totalCount++;
        }

        // 4. Ingest Payment Promises
        final promises = exportData['promises'] as List? ?? [];
        for (final pr in promises) {
          int minorUnits = 0;
          if (pr['amount_minor_units'] != null) {
            minorUnits = pr['amount_minor_units'] as int;
          } else if (pr['amount'] != null) {
            final doubleVal = double.tryParse(pr['amount'].toString());
            if (doubleVal != null) {
              minorUnits = (doubleVal * 100).round();
            }
          }

          await txn.execute(
            '''
            INSERT OR REPLACE INTO ${LocalDatabaseSchema.tablePaymentPromises} (
              id, merchant_id, counterparty_id, counterparty_name, amount_minor_units,
              currency, direction, status, source, due_date, created_at, fulfilled_at, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              pr['id'],
              pr['merchant_id'],
              pr['counterparty_id'],
              pr['counterparty_name'] ?? 'Counterparty',
              minorUnits,
              pr['currency'] ?? 'INR',
              pr['direction'] ?? 'EXPECTED_INCOMING',
              pr['status'] ?? 'OPEN',
              pr['source'] ?? 'MERCHANT_DECLARED',
              pr['due_date'],
              pr['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
              pr['fulfilled_at'],
              pr['notes'],
            ],
          );
          totalCount++;
        }

        // 5. Record Migration Completion Metadata
        await txn.execute(
          '''
          INSERT INTO ${LocalDatabaseSchema.tableMigrationMetadata} (
            migration_key, source_system, migrated_records_count, migrated_at, checksum
          ) VALUES (?, ?, ?, ?, ?)
          ''',
          [
            migrationKey,
            'POSTGRESQL_BACKEND',
            totalCount,
            DateTime.now().toUtc().toIso8601String(),
            calculatedChecksum,
          ],
        );
      });

      return MigrationResult(
        success: true,
        recordsMigrated: totalCount,
        checksum: calculatedChecksum,
      );
    } catch (e) {
      return MigrationResult(
        success: false,
        recordsMigrated: 0,
        checksum: '',
        errorMessage: 'Migration transaction failed and rolled back: $e',
      );
    }
  }
}
