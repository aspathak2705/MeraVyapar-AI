import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'drivers/sqflite_database_driver.dart';
import 'local_database_schema.dart';

/// Abstract interface for local database operations to allow deterministic test mocks
/// and clean repository injection.
abstract class LocalDatabaseDriver {
  Future<void> open(String path);
  Future<void> execute(String sql, [List<dynamic>? arguments]);
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]);
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action);
  Future<void> close();
}

/// In-memory / file-based SQLite driver abstraction managed by LocalDatabaseService.
class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  bool _isInitialized = false;
  String? _databaseFilePath;
  LocalDatabaseDriver? _activeDriver;

  LocalDatabaseService._();

  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;
  String? get databasePath => _databaseFilePath;
  LocalDatabaseDriver? get driver => _activeDriver;

  /// Resolves the app-private database file path inside ApplicationDocumentsDirectory.
  static Future<String> getDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(docsDir.path, 'database'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return p.join(dbDir.path, LocalDatabaseSchema.databaseFileName);
  }

  /// Initialize local database schema tables atomically and apply incremental migrations.
  Future<void> initialize({LocalDatabaseDriver? customDriver, String? customDbPath}) async {
    if (_isInitialized) return;

    _databaseFilePath = customDbPath ?? await getDatabasePath();
    _activeDriver = customDriver ?? SqfliteDatabaseDriver();

    await _activeDriver!.open(_databaseFilePath!);
    // Enable WAL mode and foreign key constraints for production SQLite integrity
    await _activeDriver!.execute('PRAGMA journal_mode = WAL;');
    await _activeDriver!.execute('PRAGMA foreign_keys = ON;');

    // Inspect user_version PRAGMA to perform safe incremental migration
    final versionRows = await _activeDriver!.query('PRAGMA user_version;');
    final currentDbVersion = versionRows.isNotEmpty && versionRows.first['user_version'] != null
        ? (versionRows.first['user_version'] as num).toInt()
        : 0;

    if (currentDbVersion == 0) {
      // Fresh install: execute full V4 schema atomically
      for (final sql in LocalDatabaseSchema.createStatementsV4) {
        await _activeDriver!.execute(sql);
      }
      await _activeDriver!.execute('PRAGMA user_version = ${LocalDatabaseSchema.version};');
    } else if (currentDbVersion < 4) {
      // Existing V3 (or earlier) database: apply additive procurement migration inside a transaction
      await _activeDriver!.transaction((txn) async {
        for (final sql in LocalDatabaseSchema.procurementStatementsV4) {
          await txn.execute(sql);
        }
        await txn.execute('PRAGMA user_version = 4;');
      });
    }

    _isInitialized = true;
  }

  /// Reset/close state for testing or logout
  void reset() {
    _isInitialized = false;
    _databaseFilePath = null;
    _activeDriver = null;
  }
}
