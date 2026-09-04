import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/communication_action_model.dart';
import '../domain/communication_audit_event_model.dart';

class ActionRepository {
  final String baseUrl;
  final http.Client client;

  ActionRepository({required this.baseUrl, http.Client? client})
      : client = client ?? http.Client();

  Future<CommunicationAction> draftPaymentReminder({
    required String promiseId,
    required String channel,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/actions/draft-reminder'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'promise_id': promiseId,
        'channel': channel,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return CommunicationAction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to draft payment reminder: ${response.body}');
    }
  }

  Future<List<CommunicationAction>> fetchActions({
    required String authToken,
    String? statusFilter,
  }) async {
    String url = '$baseUrl/api/v1/actions';
    if (statusFilter != null && statusFilter.isNotEmpty) {
      url += '?status=$statusFilter';
    }

    final response = await client.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => CommunicationAction.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load actions');
    }
  }

  Future<CommunicationAction> updateDraft({
    required String actionId,
    required String finalContent,
    required String authToken,
  }) async {
    final response = await client.patch(
      Uri.parse('$baseUrl/api/v1/actions/$actionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'final_content': finalContent,
      }),
    );

    if (response.statusCode == 200) {
      return CommunicationAction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update draft action: ${response.body}');
    }
  }

  Future<CommunicationAction> confirmAction({
    required String actionId,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/actions/$actionId/confirm'),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      return CommunicationAction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to confirm action: ${response.body}');
    }
  }

  Future<CommunicationAction> cancelAction({
    required String actionId,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/actions/$actionId/cancel'),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      return CommunicationAction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to cancel action: ${response.body}');
    }
  }

  Future<CommunicationAction> dispatchAction({
    required String actionId,
    required String authToken,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/v1/actions/$actionId/dispatch'),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      return CommunicationAction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to dispatch action: ${response.body}');
    }
  }

  Future<List<CommunicationAuditEvent>> fetchAuditTrail({
    required String actionId,
    required String authToken,
  }) async {
    final response = await client.get(
      Uri.parse('$baseUrl/api/v1/actions/$actionId/audit-trail'),
      headers: {
        'Authorization': 'Bearer $authToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => CommunicationAuditEvent.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load audit trail');
    }
  }
}
