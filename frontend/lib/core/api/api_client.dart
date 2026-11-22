import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../errors/failure.dart';

class ApiClient {
  static const Duration defaultTimeout = Duration(seconds: 45);
  http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _buildHeaders(Map<String, String>? extraHeaders) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close',
      if (extraHeaders != null) ...extraHeaders,
    };
  }

  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function(http.Client client) call,
    Duration timeout,
  ) async {
    try {
      return await call(_client).timeout(timeout);
    } catch (e) {
      final isConnectionClosed = e is http.ClientException &&
          (e.message.toLowerCase().contains('connection closed') ||
              e.message.toLowerCase().contains('connection reset') ||
              e.message.toLowerCase().contains('broken pipe'));
      final isSocketDrop = e is SocketException;

      if (isConnectionClosed || isSocketDrop) {
        // Re-instantiate client to dump stale pooled socket and retry once
        _client.close();
        _client = http.Client();
        try {
          return await call(_client).timeout(timeout);
        } on http.ClientException catch (_) {
          throw const Failure(
            'Connection closed by server. Gateway may be waking up, please tap Retry.',
            code: 'CONNECTION_CLOSED',
          );
        } on SocketException catch (_) {
          throw const Failure(
            'Network socket disconnected. Please check internet connection and retry.',
            code: 'SOCKET_DISCONNECTED',
          );
        } on TimeoutException {
          throw Failure(
            'Gateway request timed out (${timeout.inSeconds}s). Please retry.',
            code: 'GATEWAY_TIMEOUT',
          );
        }
      }

      if (e is TimeoutException) {
        throw Failure(
          'Gateway request timed out (${timeout.inSeconds}s). Cloud instance may be cold-starting; please retry.',
          code: 'GATEWAY_TIMEOUT',
        );
      }

      if (e is http.ClientException) {
        throw Failure('Network connection error: ${e.message}', code: 'NETWORK_ERROR');
      }

      if (e is Failure) rethrow;
      throw Failure('Request failed: $e', code: 'REQUEST_ERROR');
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');
    final combinedHeaders = _buildHeaders(headers);

    final response = await _executeWithRetry(
      (client) => client.get(url, headers: combinedHeaders),
      timeout,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');
    final combinedHeaders = _buildHeaders(headers);
    final payload = body != null ? jsonEncode(body) : null;

    final response = await _executeWithRetry(
      (client) => client.post(url, headers: combinedHeaders, body: payload),
      timeout,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');
    final combinedHeaders = _buildHeaders(headers);
    final payload = jsonEncode(body);

    final response = await _executeWithRetry(
      (client) => client.put(url, headers: combinedHeaders, body: payload),
      timeout,
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic parsed;
    try {
      parsed = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (e) {
      throw Failure('Invalid server response format (${response.statusCode})', code: 'MALFORMED_RESPONSE');
    }
    final Map<String, dynamic> decoded =
        parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      final errorMessage = decoded['message'] ??
          decoded['detail'] ??
          'An unknown error occurred (HTTP ${response.statusCode})';
      final errorCode = decoded['error']?['code']?.toString();
      throw Failure(errorMessage, code: errorCode);
    }
  }
}
