import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

enum LocalAuthStatus {
  uninitialized, // No merchant profile or PIN set up
  locked,        // Merchant profile exists; waiting for PIN/biometric unlock
  authenticated, // Logged in and active session
}

class LocalMerchantSession {
  final String merchantId;
  final String displayName;
  final DateTime authenticatedAt;

  const LocalMerchantSession({
    required this.merchantId,
    required this.displayName,
    required this.authenticatedAt,
  });
}

/// Secure local authentication repository backed by platform keystore (FlutterSecureStorage).
/// Completely eliminates Supabase Auth dependency.
class LocalAuthRepository {
  static const String _keyMerchantId = 'mv_local_merchant_id';
  static const String _keyMerchantName = 'mv_local_merchant_name';
  static const String _keyPinHash = 'mv_local_pin_hash';
  static const String _keyPinSalt = 'mv_local_pin_salt';
  static const String _keyFailedAttempts = 'mv_local_failed_attempts';
  static const String _keyLockoutUntil = 'mv_local_lockout_until';

  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  final FlutterSecureStorage _secureStorage;
  LocalMerchantSession? _currentSession;

  LocalAuthRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  LocalMerchantSession? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession != null;

  /// Check whether a local merchant account is already configured.
  Future<bool> hasLocalMerchant() async {
    final id = await _secureStorage.read(key: _keyMerchantId);
    final pinHash = await _secureStorage.read(key: _keyPinHash);
    return id != null && pinHash != null;
  }

  /// Create local merchant identity with a secure PIN.
  Future<LocalMerchantSession> registerLocalMerchant({
    required String displayName,
    required String pin,
  }) async {
    if (pin.length < 4 || pin.length > 8) {
      throw ArgumentError('PIN must be between 4 and 8 digits');
    }

    final merchantId = const Uuid().v4();
    final salt = const Uuid().v4();
    final pinHash = _hashPin(pin, salt);

    await _secureStorage.write(key: _keyMerchantId, value: merchantId);
    await _secureStorage.write(key: _keyMerchantName, value: displayName);
    await _secureStorage.write(key: _keyPinSalt, value: salt);
    await _secureStorage.write(key: _keyPinHash, value: pinHash);
    await _secureStorage.write(key: _keyFailedAttempts, value: '0');

    _currentSession = LocalMerchantSession(
      merchantId: merchantId,
      displayName: displayName,
      authenticatedAt: DateTime.now().toUtc(),
    );

    return _currentSession!;
  }

  /// Authenticate merchant via PIN.
  Future<bool> authenticateWithPin(String pin) async {
    // Check lockout status
    final lockoutStr = await _secureStorage.read(key: _keyLockoutUntil);
    if (lockoutStr != null) {
      final lockoutTime = DateTime.tryParse(lockoutStr);
      if (lockoutTime != null && DateTime.now().toUtc().isBefore(lockoutTime)) {
        throw StateError('Account temporarily locked due to failed attempts. Try again later.');
      }
    }

    final storedHash = await _secureStorage.read(key: _keyPinHash);
    final salt = await _secureStorage.read(key: _keyPinSalt);
    final merchantId = await _secureStorage.read(key: _keyMerchantId);
    final displayName = await _secureStorage.read(key: _keyMerchantName) ?? 'Merchant';

    if (storedHash == null || salt == null || merchantId == null) {
      throw StateError('No local merchant account found.');
    }

    final computedHash = _hashPin(pin, salt);
    if (computedHash == storedHash) {
      // Reset failed attempts on success
      await _secureStorage.write(key: _keyFailedAttempts, value: '0');
      await _secureStorage.delete(key: _keyLockoutUntil);

      _currentSession = LocalMerchantSession(
        merchantId: merchantId,
        displayName: displayName,
        authenticatedAt: DateTime.now().toUtc(),
      );
      return true;
    } else {
      // Increment failed attempts
      final failedCountStr = await _secureStorage.read(key: _keyFailedAttempts) ?? '0';
      final failedCount = (int.tryParse(failedCountStr) ?? 0) + 1;
      await _secureStorage.write(key: _keyFailedAttempts, value: failedCount.toString());

      if (failedCount >= maxFailedAttempts) {
        final lockUntil = DateTime.now().toUtc().add(lockoutDuration).toIso8601String();
        await _secureStorage.write(key: _keyLockoutUntil, value: lockUntil);
      }
      return false;
    }
  }

  /// Lock session
  void lockSession() {
    _currentSession = null;
  }

  /// PBKDF2 / SHA-256 multi-round cryptographic hash with salt.
  String _hashPin(String pin, String salt) {
    var bytes = utf8.encode('$salt:$pin:$salt');
    for (int i = 0; i < 5000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return sha256.convert(bytes).toString();
  }
}
