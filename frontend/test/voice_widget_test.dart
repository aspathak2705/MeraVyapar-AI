import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/features/voice/domain/voice_models.dart';
import 'package:frontend/features/voice/data/voice_repository.dart';
import 'package:frontend/features/voice/services/audio_recording_service.dart';
import 'package:frontend/features/voice/services/audio_playback_service.dart';
import 'package:frontend/features/voice/presentation/voice_interaction_controller.dart';
import 'package:frontend/features/voice/presentation/voice_assistant_sheet.dart';
import 'package:frontend/features/voice/presentation/voice_confirmation_card.dart';
import 'package:frontend/features/actions/data/local_action_repository.dart';
import 'package:frontend/core/database/local_database_service.dart';

void main() {
  late StateNotifierProvider<VoiceInteractionController, VoiceInteractionState> testControllerProvider;
  late VoiceRepository voiceRepo;
  late SimulatedAudioRecordingService recordingSvc;
  late SimulatedAudioPlaybackService playbackSvc;
  late LocalActionRepository actionRepo;

  setUp(() {
    voiceRepo = VoiceRepository(baseUrl: 'http://localhost:8000');
    recordingSvc = SimulatedAudioRecordingService();
    playbackSvc = SimulatedAudioPlaybackService();
    actionRepo = LocalActionRepository(dbService: LocalDatabaseService.instance);

    testControllerProvider = StateNotifierProvider<VoiceInteractionController, VoiceInteractionState>((ref) {
      return VoiceInteractionController(
        voiceRepository: voiceRepo,
        recordingService: recordingSvc,
        playbackService: playbackSvc,
        actionRepository: actionRepo,
        authToken: 'test_token',
      );
    });
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: VoiceAssistantSheet(controllerProvider: testControllerProvider),
        ),
      ),
    );
  }

  testWidgets('Renders idle state with microphone and language selector', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.text('Voice Assistant'), findsOneWidget);
    expect(find.text('Tap microphone to speak'), findsOneWidget);
    expect(find.text('हिंदी'), findsOneWidget);
    expect(find.text('मराठी'), findsOneWidget);
    expect(find.text('Eng'), findsOneWidget);
    expect(find.text('Start Speaking'), findsOneWidget);
  });

  testWidgets('Tapping Start Speaking transitions to recording state with cancel and stop buttons', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    await tester.tap(find.text('Start Speaking'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Listening...'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('VoiceConfirmationCard renders details and responds to cancel and confirm', (tester) async {
    bool confirmed = false;
    bool cancelled = false;

    const candidate = VoiceCandidateActionModel(
      actionType: 'DRAFT_PAYMENT_REMINDER',
      promiseId: 'promise-123',
      counterpartyName: 'Rajesh Traders',
      amount: '8500.00',
      channel: 'WHATSAPP',
      endpoint: '/api/v1/actions/draft-reminder',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConfirmationCard(
            candidate: candidate,
            onConfirm: () => confirmed = true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    expect(find.text('Voice Mutation Proposal'), findsOneWidget);
    expect(find.text('Rajesh Traders'), findsOneWidget);
    expect(find.text('₹8500.00'), findsOneWidget);
    expect(find.text('WHATSAPP'), findsOneWidget);

    await tester.tap(find.text('Confirm Action'));
    expect(confirmed, true);

    await tester.tap(find.text('Cancel'));
    expect(cancelled, true);
  });
}
