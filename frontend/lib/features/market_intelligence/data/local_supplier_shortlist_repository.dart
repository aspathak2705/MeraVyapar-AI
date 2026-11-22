import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../domain/shortlisted_supplier_model.dart';

final localSupplierShortlistRepositoryProvider = Provider((ref) => LocalSupplierShortlistRepository());

class LocalSupplierShortlistRepository {
  final LocalDatabaseService _dbService;

  LocalSupplierShortlistRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  Future<List<ShortlistedSupplierModel>> getShortlist({required String merchantId}) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database driver not initialized');

    final rows = await driver.query(
      '''
      SELECT * FROM ${LocalDatabaseSchema.tableSupplierShortlist}
      WHERE merchant_id = ?
      ORDER BY created_at DESC
      ''',
      [merchantId],
    );

    return rows.map((r) => ShortlistedSupplierModel.fromMap(r)).toList();
  }

  Future<void> addToShortlist(ShortlistedSupplierModel supplier) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database driver not initialized');

    final map = supplier.toMap();

    await driver.execute(
      '''
      INSERT OR REPLACE INTO ${LocalDatabaseSchema.tableSupplierShortlist} (
        id, merchant_id, business_name, business_category, address,
        latitude, longitude, phone, website, rating, review_count,
        operating_hours, source_url, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        map['id'],
        map['merchant_id'],
        map['business_name'],
        map['business_category'],
        map['address'],
        map['latitude'],
        map['longitude'],
        map['phone'],
        map['website'],
        map['rating'],
        map['review_count'],
        map['operating_hours'],
        map['source_url'],
        map['notes'],
        map['created_at'],
      ],
    );
  }

  Future<void> removeFromShortlist(String id) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database driver not initialized');

    await driver.execute(
      '''
      DELETE FROM ${LocalDatabaseSchema.tableSupplierShortlist}
      WHERE id = ?
      ''',
      [id],
    );
  }

  Future<bool> isShortlisted({
    required String merchantId,
    required String businessName,
    String? sourceUrl,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return false;

    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      final rows = await driver.query(
        '''
        SELECT id FROM ${LocalDatabaseSchema.tableSupplierShortlist}
        WHERE merchant_id = ? AND (source_url = ? OR business_name = ?)
        LIMIT 1
        ''',
        [merchantId, sourceUrl, businessName],
      );
      return rows.isNotEmpty;
    }

    final rows = await driver.query(
      '''
      SELECT id FROM ${LocalDatabaseSchema.tableSupplierShortlist}
      WHERE merchant_id = ? AND business_name = ?
      LIMIT 1
      ''',
      [merchantId, businessName],
    );
    return rows.isNotEmpty;
  }

  Future<void> updateNotes(String id, String notes) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database driver not initialized');

    await driver.execute(
      '''
      UPDATE ${LocalDatabaseSchema.tableSupplierShortlist}
      SET notes = ?
      WHERE id = ?
      ''',
      [notes, id],
    );
  }
}
