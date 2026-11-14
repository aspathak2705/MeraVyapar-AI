import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../errors/failure.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    final response = await _client.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
      body: body != null ? jsonEncode(body) : null,
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    final response = await _client.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final dynamic parsed =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final Map<String, dynamic> decoded =
        parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      final errorMessage = decoded['message'] ??
          decoded['detail'] ??
          'An unknown error occurred';
      final errorCode = decoded['error']?['code']?.toString();
      throw Failure(errorMessage, code: errorCode);
    }
  }
}
