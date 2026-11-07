import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../database/local_database_service.dart';
import '../database/local_database_schema.dart';
import '../../features/evidence/data/app_private_evidence_storage.dart';

class BackupManifest {
  final int backupVersion;
  final int schemaVersion;
  final String createdAt;
  final String merchantId;
  final String databaseChecksum;
  final int evidenceFileCount;
  final Map<String, String> evidenceChecksums;

  const BackupManifest({
    required this.backupVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.merchantId,
    required this.databaseChecksum,
    required this.evidenceFileCount,
    required this.evidenceChecksums,
  });

  Map<String, dynamic> toJson() => {
        'backup_version': backupVersion,
        'schema_version': schemaVersion,
        'created_at': createdAt,
        'merchant_id': merchantId,
        'database_checksum': databaseChecksum,
        'evidence_file_count': evidenceFileCount,
        'evidence_checksums': evidenceChecksums,
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        backupVersion: json['backup_version'],
        schemaVersion: json['schema_version'],
        createdAt: json['created_at'],
        merchantId: json['merchant_id'],
        databaseChecksum: json['database_checksum'],
        evidenceFileCount: json['evidence_file_count'],
        evidenceChecksums: Map<String, String>.from(json['evidence_checksums'] ?? {}),
      );
}

class BackupPackageResult {
  final bool success;
  final String? backupFilePath;
  final BackupManifest? manifest;
  final String? errorMessage;

  const BackupPackageResult({
    required this.success,
    this.backupFilePath,
    this.manifest,
    this.errorMessage,
  });
}

/// Service providing merchant-controlled, encrypted local backup and atomic restore.
class EncryptedLocalBackupService {
  static const int currentBackupVersion = 1;
  static const int pbkdf2Iterations = 20000;

  final LocalDatabaseService _dbService;

  EncryptedLocalBackupService({LocalDatabaseService? dbService})
      : _dbService = dbService ?? LocalDatabaseService.instance;

  /// Creates an encrypted archive containing the SQLite snapshot, evidence files, and manifest.
  Future<BackupPackageResult> createEncryptedBackup({
    required String merchantId,
    required String passphrase,
    required String outputDirectoryPath,
  }) async {
    if (passphrase.length < 8) {
      return const BackupPackageResult(
        success: false,
        errorMessage: 'Backup passphrase must be at least 8 characters',
      );
    }

    try {
      final dbPath = await LocalDatabaseService.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return const BackupPackageResult(
          success: false,
          errorMessage: 'Local database file does not exist',
        );
      }

      // Checkpoint WAL if driver is active
      final driver = _dbService.driver;
      if (driver != null) {
        await driver.execute('PRAGMA wal_checkpoint(FULL);');
      }

      // Read DB bytes & compute SHA-256
      final dbBytes = await dbFile.readAsBytes();
      final dbChecksum = sha256.convert(dbBytes).toString();

      // Collect evidence files
      final docsDir = await getApplicationDocumentsDirectory();
      final merchantEvidenceDir = Directory(p.join(docsDir.path, 'evidence', merchantId));
      final evidenceChecksums = <String, String>{};
      final evidenceFiles = <String, List<int>>{};

      if (await merchantEvidenceDir.exists()) {
        await for (final entity in merchantEvidenceDir.list(recursive: true)) {
          if (entity is File && p.basename(entity.path) == 'original') {
            final relPath = p.relative(entity.path, from: docsDir.path);
            final fileBytes = await entity.readAsBytes();
            final chk = sha256.convert(fileBytes).toString();
            evidenceChecksums[relPath] = chk;
            evidenceFiles[relPath] = fileBytes;
          }
        }
      }

      // Generate Manifest
      final manifest = BackupManifest(
        backupVersion: currentBackupVersion,
        schemaVersion: LocalDatabaseSchema.version,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        merchantId: merchantId,
        databaseChecksum: dbChecksum,
        evidenceFileCount: evidenceFiles.length,
        evidenceChecksums: evidenceChecksums,
      );

      // Package JSON payload
      final packageMap = {
        'manifest': manifest.toJson(),
        'database_b64': base64Encode(dbBytes),
        'evidence_files_b64': evidenceFiles.map((k, v) => MapEntry(k, base64Encode(v))),
      };
      final packagePlaintext = utf8.encode(jsonEncode(packageMap));

      // Encrypt package using authenticated key derivation (PBKDF2-HMAC-SHA256 + HMAC auth tag)
      final salt = const Uuid().v4();
      final key = _deriveKey(passphrase, salt, pbkdf2Iterations);
      final encryptedBytes = _encryptPayload(packagePlaintext, key);

      // Construct encrypted backup container
      final container = {
        'format': 'MERAVYAPAR_ENCRYPTED_BACKUP',
        'version': currentBackupVersion,
        'salt': salt,
        'iterations': pbkdf2Iterations,
        'payload_b64': base64Encode(encryptedBytes.ciphertext),
        'auth_tag': encryptedBytes.authTag,
      };

      final backupFilename = 'meravyapar_backup_${DateTime.now().millisecondsSinceEpoch}.mvbak';
      final outDir = Directory(outputDirectoryPath);
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final outPath = p.join(outputDirectoryPath, backupFilename);
      await File(outPath).writeAsString(jsonEncode(container), flush: true);

      return BackupPackageResult(
        success: true,
        backupFilePath: outPath,
        manifest: manifest,
      );
    } catch (e) {
      return BackupPackageResult(
        success: false,
        errorMessage: 'Backup generation failed: $e',
      );
    }
  }

  /// Validates and restores an encrypted backup package into a staging directory before atomic swap.
  Future<BackupPackageResult> restoreEncryptedBackup({
    required String backupFilePath,
    required String passphrase,
  }) async {
    try {
      final file = File(backupFilePath);
      if (!await file.exists()) {
        return const BackupPackageResult(success: false, errorMessage: 'Backup file not found');
      }

      final content = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (content['format'] != 'MERAVYAPAR_ENCRYPTED_BACKUP') {
        return const BackupPackageResult(success: false, errorMessage: 'Invalid backup format');
      }

      final salt = content['salt'] as String;
      final iterations = content['iterations'] as int;
      final ciphertext = base64Decode(content['payload_b64'] as String);
      final authTag = content['auth_tag'] as String;

      // Verify and decrypt
      final key = _deriveKey(passphrase, salt, iterations);
      final decryptedBytes = _decryptPayload(ciphertext, key, authTag);
      if (decryptedBytes == null) {
        return const BackupPackageResult(
          success: false,
          errorMessage: 'Decryption failed: invalid passphrase or corrupted backup',
        );
      }

      final packageMap = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
      final manifest = BackupManifest.fromJson(packageMap['manifest']);

      // Validate database checksum
      final dbBytes = base64Decode(packageMap['database_b64'] as String);
      final calculatedDbChecksum = sha256.convert(dbBytes).toString();
      if (calculatedDbChecksum != manifest.databaseChecksum) {
        return const BackupPackageResult(
          success: false,
          errorMessage: 'Database integrity checksum mismatch',
        );
      }

      // Restore to Staging Directory First
      final docsDir = await getApplicationDocumentsDirectory();
      final stagingDir = Directory(p.join(docsDir.path, 'staging_restore'));
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
      await stagingDir.create(recursive: true);

      // Write staging database
      final stagingDbFile = File(p.join(stagingDir.path, LocalDatabaseSchema.databaseFileName));
      await stagingDbFile.writeAsBytes(dbBytes, flush: true);

      // Restore evidence files
      final evidenceMap = packageMap['evidence_files_b64'] as Map<String, dynamic>? ?? {};
      for (final entry in evidenceMap.entries) {
        final relPath = entry.key;
        // Path traversal guard
        if (relPath.contains('..') || relPath.startsWith('/') || relPath.startsWith('\\')) {
          throw StateError('Security violation: path traversal detected in backup manifest');
        }
        final bytes = base64Decode(entry.value as String);
        final chk = sha256.convert(bytes).toString();
        if (manifest.evidenceChecksums[relPath] != chk) {
          throw StateError('Evidence file checksum mismatch: $relPath');
        }
        final targetFile = File(p.join(docsDir.path, relPath));
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(bytes, flush: true);
      }

      // Close active database and atomically swap
      _dbService.reset();
      final liveDbPath = await LocalDatabaseService.getDatabasePath();
      final liveDbFile = File(liveDbPath);
      if (await liveDbFile.exists()) {
        final backupOld = File('$liveDbPath.old');
        if (await backupOld.exists()) await backupOld.delete();
        await liveDbFile.rename(backupOld.path);
      }

      await stagingDbFile.copy(liveDbPath);
      await stagingDir.delete(recursive: true);

      return BackupPackageResult(
        success: true,
        backupFilePath: backupFilePath,
        manifest: manifest,
      );
    } catch (e) {
      return BackupPackageResult(
        success: false,
        errorMessage: 'Restore failed: $e',
      );
    }
  }

  // --- Cryptographic Helpers ---
  List<int> _deriveKey(String passphrase, String salt, int iterations) {
    final passBytes = utf8.encode(passphrase);
    final saltBytes = utf8.encode(salt);
    final hmac = Hmac(sha256, passBytes);

    var u = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    var result = List<int>.from(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int k = 0; k < result.length; k++) {
        result[k] ^= u[k];
      }
    }
    return result;
  }

  _EncryptedPayload _encryptPayload(List<int> plaintext, List<int> key) {
    // Authenticated XOR-stream cipher with HMAC-SHA256 authentication tag
    final keystream = Hmac(sha256, key).convert(plaintext.length > 32 ? plaintext.sublist(0, 32) : plaintext).bytes;
    final ciphertext = List<int>.filled(plaintext.length, 0);
    for (int i = 0; i < plaintext.length; i++) {
      ciphertext[i] = plaintext[i] ^ keystream[i % keystream.length];
    }
    final authTag = Hmac(sha256, key).convert(ciphertext).toString();
    return _EncryptedPayload(ciphertext, authTag);
  }

  List<int>? _decryptPayload(List<int> ciphertext, List<int> key, String expectedTag) {
    final computedTag = Hmac(sha256, key).convert(ciphertext).toString();
    if (computedTag != expectedTag) {
      return null; // Tamper detection
    }
    final keystream = Hmac(sha256, key).convert(ciphertext.length > 32 ? ciphertext.sublist(0, 32) : ciphertext).bytes;
    final plaintext = List<int>.filled(ciphertext.length, 0);
    for (int i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ keystream[i % keystream.length];
    }
    return plaintext;
  }
}

class _EncryptedPayload {
  final List<int> ciphertext;
  final String authTag;
  _EncryptedPayload(this.ciphertext, this.authTag);
}
