import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

/// Holds a short-lived gateway session for optional cloud features.  This is
/// deliberately independent from merchant data and from Supabase/Auth.
class GatewaySessionService {
  static const _installationIdKey = 'mv_gateway_installation_id';
  static const _clientPublicKeyKey = 'mv_gateway_client_public_key';
  static const _tokenKey = 'mv_gateway_session_token';
  static const _tokenExpiryKey = 'mv_gateway_session_expiry';

  final FlutterSecureStorage _storage;
  final ApiClient _apiClient;

  GatewaySessionService({FlutterSecureStorage? storage, ApiClient? apiClient})
      : _storage = storage ?? const FlutterSecureStorage(),
        _apiClient = apiClient ?? ApiClient();

  Future<String> getAuthorizationHeader() async {
    final token = await _validCachedToken();
    if (token != null) {
      return 'Bearer $token';
    }

    final installationId = await _getOrCreate(_installationIdKey);
    // The gateway currently validates the enrollment field's shape only. This
    // stable opaque value is not a financial identifier or a provider secret.
    final clientPublicKey = await _getOrCreate(_clientPublicKeyKey);
    final response = await _apiClient.post(
      '/auth/enroll',
      body: {
        'installation_id': installationId,
        'client_public_key': clientPublicKey,
      },
    );
    final issuedToken = response['gateway_session_token'] as String?;
    final ttl = response['expires_in_seconds'] as int? ?? 300;
    if (issuedToken == null || issuedToken.isEmpty) {
      throw StateError('Gateway did not return a usable session token.');
    }
    await _storage.write(key: _tokenKey, value: issuedToken);
    await _storage.write(
      key: _tokenExpiryKey,
      value: DateTime.now()
          .toUtc()
          .add(Duration(seconds: ttl - 15))
          .toIso8601String(),
    );
    return 'Bearer $issuedToken';
  }

  Future<String?> _validCachedToken() async {
    final token = await _storage.read(key: _tokenKey);
    final expiry =
        DateTime.tryParse(await _storage.read(key: _tokenExpiryKey) ?? '');
    if (token == null ||
        expiry == null ||
        !DateTime.now().toUtc().isBefore(expiry)) {
      return null;
    }
    return token;
  }

  Future<String> _getOrCreate(String key) async {
    final existing = await _storage.read(key: key);
    if (existing != null && existing.length >= 16) {
      return existing;
    }
    final value = key == _installationIdKey
        ? const Uuid().v4()
        : '${const Uuid().v4()}${const Uuid().v4()}';
    await _storage.write(key: key, value: value);
    return value;
  }
}
