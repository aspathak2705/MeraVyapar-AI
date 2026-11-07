import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/voice_models.dart';

class VoiceRepository {
  final String baseUrl;
  final http.Client client;

  VoiceRepository({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<VoiceStatusModel> getVoiceStatus() async {
    final uri = Uri.parse('$baseUrl/api/v1/voice/status');
    final response = await client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return VoiceStatusModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch voice status: ${response.statusCode}');
    }
  }

  Future<VoiceInteractionModel> interactWithVoice({
    required List<int> audioBytes,
    required String filename,
    required String authToken,
    String? languageCode,
    bool synthesizeAudio = true,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/voice/interact');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $authToken';
    request.headers['Accept'] = 'application/json';

    final multipartFile = http.MultipartFile.fromBytes(
      'audio_file',
      audioBytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    if (languageCode != null && languageCode.isNotEmpty) {
      request.fields['language_code'] = languageCode;
    }
    request.fields['synthesize_audio'] = synthesizeAudio ? 'true' : 'false';

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return VoiceInteractionModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 400) {
      final msg = _parseErrorMessage(response.body, 'Invalid audio recording format.');
      throw Exception(msg);
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please sign in again.');
    } else if (response.statusCode == 429) {
      throw Exception('Voice request limit exceeded. Please wait a moment.');
    } else if (response.statusCode == 503) {
      throw Exception('Voice intelligence service is temporarily unavailable.');
    } else {
      final msg = _parseErrorMessage(response.body, 'Server error during voice processing (${response.statusCode}).');
      throw Exception(msg);
    }
  }

  Future<List<int>> synthesizeSpeech({
    required String text,
    required String authToken,
    String languageCode = 'hi-IN',
    String voice = 'Nalini',
    double speed = 1.0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/voice/synthesize');
    final response = await client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'language_code': languageCode,
        'voice': voice,
        'speed': speed,
      }),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to synthesize speech: ${response.statusCode}');
    }
  }

  String _parseErrorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}
