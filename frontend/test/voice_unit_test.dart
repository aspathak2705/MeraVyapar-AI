import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/features/voice/data/voice_repository.dart';
import 'package:frontend/features/voice/services/audio_recording_service.dart';
import 'package:frontend/features/voice/services/audio_playback_service.dart';
import 'package:frontend/features/voice/presentation/voice_interaction_controller.dart';
import 'package:frontend/features/actions/data/action_repository.dart';
import 'package:frontend/features/actions/domain/communication_action_model.dart';

void main() {
  group('VoiceRepository Tests', () {
    test('getVoiceStatus parses response correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/voice/status');
        return http.Response(
          '{"stt_provider":"Gnani Prisma (prisma-v2.5)","tts_provider":"Gnani Timbre (timbre-v2.5)","stt_configured":true,"tts_configured":true,"default_language":"hi-IN","default_voice":"Nalini","supported_languages":["hi-IN","mr-IN","en-IN"]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VoiceRepository(baseUrl: 'http://localhost:8000', client: mockClient);
      final status = await repo.getVoiceStatus();

      expect(status.sttConfigured, true);
      expect(status.ttsConfigured, true);
      expect(status.defaultLanguage, 'hi-IN');
      expect(status.supportedLanguages.contains('hi-IN'), true);
      expect(status.supportedLanguages.contains('mr-IN'), true);
      expect(status.supportedLanguages.contains('en-IN'), true);
    });

    test('interactWithVoice sends multipart request and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/voice/interact');
        expect(request.headers['Authorization'], 'Bearer fake_token');
        return http.Response(
          '{"success":true,"transcript":"मेरा कितना पैसा बाकी है","language_code":"hi-IN","intent":"QUERY_RECEIVABLES","response_text":"आपके कुल ₹5,000.00 बकाया हैं।","confirmation_required":false,"candidate_action":null,"audio_base64":"UklGRg==","tts_status":"SYNTHESIZED","metadata":{}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VoiceRepository(baseUrl: 'http://localhost:8000', client: mockClient);
      final res = await repo.interactWithVoice(
        audioBytes: [1, 2, 3, 4],
        filename: 'query.wav',
        authToken: 'fake_token',
        languageCode: 'hi-IN',
      );

      expect(res.success, true);
      expect(res.intent, 'QUERY_RECEIVABLES');
      expect(res.transcript, 'मेरा कितना पैसा बाकी है');
      expect(res.confirmationRequired, false);
      expect(res.audioBase64, 'UklGRg==');
    });

    test('interactWithVoice maps 503 service unavailable error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"detail":"Gnani AI API key (GNANI_API_KEY) is not configured."}',
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VoiceRepository(baseUrl: 'http://localhost:8000', client: mockClient);

      expect(
        () => repo.interactWithVoice(
          audioBytes: [1, 2, 3],
          filename: 'query.wav',
          authToken: 'fake_token',
        ),
        throwsA(predicate((e) => e.toString().contains('Voice intelligence service is temporarily unavailable.'))),
      );
    });
  });

  group('VoiceInteractionController Tests', () {
    test('State machine transitions cleanly through voice query lifecycle', () async {
      final mockVoiceClient = MockClient((request) async {
        return http.Response(
          '{"success":true,"transcript":"काही थकबाकी आहे का","language_code":"mr-IN","intent":"QUERY_RECEIVABLES","response_text":"तुमचे एकूण ₹10,000 येणे बाकी आहेत.","confirmation_required":false,"candidate_action":null,"audio_base64":"UklGRg==","tts_status":"SYNTHESIZED","metadata":{}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final voiceRepo = VoiceRepository(baseUrl: 'http://localhost:8000', client: mockVoiceClient);
      final recordingSvc = SimulatedAudioRecordingService();
      final playbackSvc = SimulatedAudioPlaybackService();
      final actionRepo = ActionRepository(baseUrl: 'http://localhost:8000');

      final controller = VoiceInteractionController(
        voiceRepository: voiceRepo,
        recordingService: recordingSvc,
        playbackService: playbackSvc,
        actionRepository: actionRepo,
        authToken: 'fake_token',
        defaultLanguage: 'mr-IN',
      );

      expect(controller.state.status, VoiceInteractionStatus.idle);
      expect(controller.state.selectedLanguage, 'mr-IN');

      await controller.startRecording();
      expect(controller.state.status, VoiceInteractionStatus.recording);

      await controller.stopAndProcessRecording();
      expect(controller.state.status, VoiceInteractionStatus.speaking);
      expect(controller.state.intent, 'QUERY_RECEIVABLES');
      expect(controller.state.transcript, 'काही थकबाकी आहे का');
      expect(controller.state.responseText, 'तुमचे एकूण ₹10,000 येणे बाकी आहेत.');
      expect(controller.state.candidateAction, null);
    });

    test('Two-Phase Voice Mutation requires explicit confirmation', () async {
      final mockVoiceClient = MockClient((request) async {
        return http.Response(
          '{"success":true,"transcript":"सुरेश को रिमाइंडर भेजो","language_code":"hi-IN","intent":"DRAFT_REMINDER","response_text":"सुरेश कुमार के लिए ₹12,000.00 का रिमाइंडर तैयार है। क्या आप भेजना चाहते हैं?","confirmation_required":true,"candidate_action":{"action_type":"DRAFT_PAYMENT_REMINDER","promise_id":"00000000-0000-0000-0000-000000000001","counterparty_name":"सुरेश कुमार","amount":"12000.00","channel":"WHATSAPP","endpoint":"/api/v1/actions/draft-reminder"},"audio_base64":null,"tts_status":"SYNTHESIZED","metadata":{}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final mockActionClient = MockClient((request) async {
        if (request.url.path.contains('draft-reminder')) {
          return http.Response(
            '{"id":"11111111-1111-1111-1111-111111111111","merchant_id":"00000000-0000-0000-0000-000000000099","action_type":"PAYMENT_REMINDER","channel":"WHATSAPP","status":"DRAFT","draft_content":"Dear Suresh, please pay 12000.","final_content":null,"recipient_info":null,"idempotency_key":"k-1","created_at":"2026-11-07T00:00:00Z","updated_at":"2026-11-07T00:00:00Z"}',
            201,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/confirm')) {
          return http.Response(
            '{"id":"11111111-1111-1111-1111-111111111111","merchant_id":"00000000-0000-0000-0000-000000000099","action_type":"PAYMENT_REMINDER","channel":"WHATSAPP","status":"CONFIRMED_BY_MERCHANT","draft_content":"Dear Suresh, please pay 12000.","final_content":null,"recipient_info":null,"idempotency_key":"k-1","created_at":"2026-11-07T00:00:00Z","updated_at":"2026-11-07T00:00:00Z"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"detail":"Not Found"}', 404);
      });

      final voiceRepo = VoiceRepository(baseUrl: 'http://localhost:8000', client: mockVoiceClient);
      final recordingSvc = SimulatedAudioRecordingService();
      final playbackSvc = SimulatedAudioPlaybackService();
      final actionRepo = ActionRepository(baseUrl: 'http://localhost:8000', client: mockActionClient);

      final controller = VoiceInteractionController(
        voiceRepository: voiceRepo,
        recordingService: recordingSvc,
        playbackService: playbackSvc,
        actionRepository: actionRepo,
        authToken: 'fake_token',
      );

      await controller.startRecording();
      await controller.stopAndProcessRecording();

      // INVARIANT: State must be awaitingConfirmation! Nothing committed yet!
      expect(controller.state.status, VoiceInteractionStatus.awaitingConfirmation);
      expect(controller.state.candidateAction != null, true);
      expect(controller.state.candidateAction!.counterpartyName, 'सुरेश कुमार');
      expect(controller.state.committedAction, null);

      // Explicit confirmation tap
      await controller.confirmCandidateAction();

      expect(controller.state.status, VoiceInteractionStatus.confirmationCompleted);
      expect(controller.state.committedAction != null, true);
      expect(controller.state.committedAction!.status, ActionStatus.confirmedByMerchant);
    });

    test('Microphone permission denial transitions to error', () async {
      final voiceRepo = VoiceRepository(baseUrl: 'http://localhost:8000');
      final recordingSvc = SimulatedAudioRecordingService(permissionGranted: false);
      final playbackSvc = SimulatedAudioPlaybackService();
      final actionRepo = ActionRepository(baseUrl: 'http://localhost:8000');

      final controller = VoiceInteractionController(
        voiceRepository: voiceRepo,
        recordingService: recordingSvc,
        playbackService: playbackSvc,
        actionRepository: actionRepo,
        authToken: 'fake_token',
      );

      await controller.startRecording();
      expect(controller.state.status, VoiceInteractionStatus.error);
      expect(controller.state.errorMessage!.contains('Microphone permission is required'), true);
    });
  });
}
