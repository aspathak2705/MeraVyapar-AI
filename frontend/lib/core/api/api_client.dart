import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../errors/failure.dart';

class ApiClient {
  static const Duration defaultTimeout = Duration(seconds: 15);
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
      ).timeout(timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Failure('Network connection error: ${e.message}', code: 'NETWORK_ERROR');
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Request failed: $e', code: 'REQUEST_ERROR');
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Failure('Network connection error: ${e.message}', code: 'NETWORK_ERROR');
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Request failed: $e', code: 'REQUEST_ERROR');
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    try {
      final response = await _client.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        },
        body: jsonEncode(body),
      ).timeout(timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw Failure('Network connection error: ${e.message}', code: 'NETWORK_ERROR');
    } catch (e) {
      if (e is Failure) rethrow;
      throw Failure('Request failed: $e', code: 'REQUEST_ERROR');
    }
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
