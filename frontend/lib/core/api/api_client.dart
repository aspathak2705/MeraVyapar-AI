import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import '../errors/failure.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<String?> _getToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _getToken();
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    final response = await _client.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final token = await _getToken();
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body != null ? jsonEncode(body) : null,
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, {required Map<String, dynamic> body}) async {
    final token = await _getToken();
    final url = Uri.parse('${Env.apiBaseUrl}$path');

    final response = await _client.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final Map<String, dynamic> decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      final errorMessage = decoded['message'] ?? 'An unknown error occurred';
      final errorCode = decoded['error']?['code']?.toString();
      throw Failure(errorMessage, code: errorCode);
    }
  }
}
