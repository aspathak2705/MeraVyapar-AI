import 'package:sqflite/sqflite.dart' as sqflite;
import '../local_database_service.dart';

/// Concrete Native SQLite driver implementation using sqflite.
/// Runs on Android/iOS with full transaction, WAL mode, and persistent file storage.
class SqfliteDatabaseDriver implements LocalDatabaseDriver {
  sqflite.DatabaseExecutor? _executor;
  sqflite.Database? _db;

  SqfliteDatabaseDriver();

  SqfliteDatabaseDriver._withExecutor(this._executor);

  @override
  Future<void> open(String path) async {
    _db = await sqflite.openDatabase(
      path,
      singleInstance: true,
    );
    _executor = _db;
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final exec = _executor;
    if (exec == null) {
      throw StateError('Database driver is not opened');
    }
    await exec.execute(sql, arguments);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? arguments]) async {
    final exec = _executor;
    if (exec == null) {
      throw StateError('Database driver is not opened');
    }
    final rawResults = await exec.rawQuery(sql, arguments);
    return rawResults.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  @override
  Future<void> transaction(Future<void> Function(LocalDatabaseDriver txn) action) async {
    final db = _db;
    if (db == null) {
      throw StateError('Cannot start transaction: database is not opened');
    }
    await db.transaction((sqfliteTxn) async {
      final txnDriver = SqfliteDatabaseDriver._withExecutor(sqfliteTxn);
      await action(txnDriver);
    });
  }

  @override
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _executor = null;
  }
}
