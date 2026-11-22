import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/database/local_database_schema.dart';
import '../domain/generated_report_model.dart';

final localReportRepositoryProvider = Provider((ref) => LocalReportRepository());

class LocalReportRepository {
  final LocalDatabaseService _dbService;

  LocalReportRepository({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  Future<void> saveReport(GeneratedReportModel report) async {
    final driver = _dbService.driver;
    if (driver == null) throw StateError('Database not initialized');

    final data = report.toMap();
    const sql = '''
      INSERT OR REPLACE INTO ${LocalDatabaseSchema.tableGeneratedReports} (
        id, merchant_id, report_type, title, summary, language, payload_json, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    await driver.execute(sql, [
      data['id'],
      data['merchant_id'],
      data['report_type'],
      data['title'],
      data['summary'],
      data['language'],
      data['payload_json'],
      data['created_at'],
    ]);
  }

  Future<List<GeneratedReportModel>> getReports({
    required String merchantId,
    String? reportType,
    String? language,
  }) async {
    final driver = _dbService.driver;
    if (driver == null) return [];

    String sql = '''
      SELECT * FROM ${LocalDatabaseSchema.tableGeneratedReports}
      WHERE merchant_id = ?
    ''';
    final params = <dynamic>[merchantId];

    if (reportType != null) {
      sql += ' AND report_type = ?';
      params.add(reportType);
    }
    if (language != null) {
      sql += ' AND language = ?';
      params.add(language);
    }

    sql += ' ORDER BY created_at DESC';

    final rows = await driver.query(sql, params);
    return rows.map((r) => GeneratedReportModel.fromMap(r)).toList();
  }

  Future<GeneratedReportModel?> getReportById(String id) async {
    final driver = _dbService.driver;
    if (driver == null) return null;

    final rows = await driver.query(
      'SELECT * FROM ${LocalDatabaseSchema.tableGeneratedReports} WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return GeneratedReportModel.fromMap(rows.first);
  }

  Future<void> deleteReport(String id) async {
    final driver = _dbService.driver;
    if (driver == null) return;

    await driver.execute(
      'DELETE FROM ${LocalDatabaseSchema.tableGeneratedReports} WHERE id = ?',
      [id],
    );
  }
}
