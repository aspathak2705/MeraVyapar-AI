import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/voice_models.dart';
import '../data/voice_repository.dart';
import '../services/audio_recording_service.dart';
import '../services/audio_playback_service.dart';
import '../../actions/data/local_action_repository.dart';
import '../../actions/domain/communication_action_model.dart';

enum VoiceInteractionStatus {
  idle,
  requestingPermission,
  permissionRationale,
  recording,
  processing,
  speaking,
  awaitingConfirmation,
  confirmationCompleted,
  error,
}

class VoiceInteractionState {
  final VoiceInteractionStatus status;
  final String selectedLanguage;
  final String? transcript;
  final String? responseText;
  final String? intent;
  final VoiceCandidateActionModel? candidateAction;
  final CommunicationAction? committedAction;
  final String? audioBase64;
  final bool isPlayingAudio;
  final int recordingDurationSeconds;
  final String? errorMessage;

  const VoiceInteractionState({
    required this.status,
    this.selectedLanguage = 'hi-IN',
    this.transcript,
    this.responseText,
    this.intent,
    this.candidateAction,
    this.committedAction,
    this.audioBase64,
    this.isPlayingAudio = false,
    this.recordingDurationSeconds = 0,
    this.errorMessage,
  });

  VoiceInteractionState copyWith({
    VoiceInteractionStatus? status,
    String? selectedLanguage,
    String? transcript,
    String? responseText,
    String? intent,
    VoiceCandidateActionModel? candidateAction,
    CommunicationAction? committedAction,
    String? audioBase64,
    bool? isPlayingAudio,
    int? recordingDurationSeconds,
    String? errorMessage,
  }) {
    return VoiceInteractionState(
      status: status ?? this.status,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      transcript: transcript ?? this.transcript,
      responseText: responseText ?? this.responseText,
      intent: intent ?? this.intent,
      candidateAction: candidateAction ?? this.candidateAction,
      committedAction: committedAction ?? this.committedAction,
      audioBase64: audioBase64 ?? this.audioBase64,
      isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
      recordingDurationSeconds: recordingDurationSeconds ?? this.recordingDurationSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class VoiceInteractionController extends StateNotifier<VoiceInteractionState> {
  final VoiceRepository voiceRepository;
  final AudioRecordingService recordingService;
  final AudioPlaybackService playbackService;
  final LocalActionRepository actionRepository;
  final String authToken;
  Timer? _timer;

  VoiceInteractionController({
    required this.voiceRepository,
    required this.recordingService,
    required this.playbackService,
    required this.actionRepository,
    required this.authToken,
    String defaultLanguage = 'hi-IN',
  }) : super(VoiceInteractionState(
          status: VoiceInteractionStatus.idle,
          selectedLanguage: defaultLanguage,
        ));

  void selectLanguage(String languageCode) {
    state = state.copyWith(selectedLanguage: languageCode);
  }

  Future<void> startRecording({bool proceedDirectly = false}) async {
    try {
      final hasPermission = await recordingService.hasPermission();
      if (!hasPermission && !proceedDirectly) {
        state = state.copyWith(
          status: VoiceInteractionStatus.permissionRationale,
          errorMessage: null,
        );
        return;
      }

      state = state.copyWith(
        status: VoiceInteractionStatus.requestingPermission,
        errorMessage: null,
      );

      if (!hasPermission) {
        final granted = await recordingService.requestPermission();
        if (!granted) {
          state = state.copyWith(
            status: VoiceInteractionStatus.error,
            errorMessage: 'Microphone permission is required for voice assistant. You can enable it in Android App Settings.',
          );
          return;
        }
      }

      await recordingService.startRecording();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (state.status == VoiceInteractionStatus.recording) {
          state = state.copyWith(recordingDurationSeconds: state.recordingDurationSeconds + 1);
        } else {
          t.cancel();
        }
      });
      state = state.copyWith(
        status: VoiceInteractionStatus.recording,
        recordingDurationSeconds: 0,
      );
    } catch (e) {
      state = state.copyWith(
        status: VoiceInteractionStatus.error,
        errorMessage: 'Failed to start microphone recording: $e',
      );
    }
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    await recordingService.cancelRecording();
    state = state.copyWith(status: VoiceInteractionStatus.idle, recordingDurationSeconds: 0);
  }

  Future<void> stopAndProcessRecording() async {
    _timer?.cancel();
    try {
      final audioBytes = await recordingService.stopRecording();
      if (audioBytes == null || audioBytes.isEmpty) {
        state = state.copyWith(
          status: VoiceInteractionStatus.error,
          errorMessage: 'No speech was recorded. Please try again.',
        );
        return;
      }

      state = state.copyWith(status: VoiceInteractionStatus.processing);

      final interaction = await voiceRepository.interactWithVoice(
        audioBytes: audioBytes,
        filename: 'voice_query.wav',
        authToken: authToken,
        languageCode: state.selectedLanguage,
        synthesizeAudio: true,
      );

      if (!mounted) return;

      // Check if mutation requires explicit Two-Phase confirmation
      if (interaction.confirmationRequired && interaction.candidateAction != null) {
        state = state.copyWith(
          status: VoiceInteractionStatus.awaitingConfirmation,
          transcript: interaction.transcript,
          responseText: interaction.responseText,
          intent: interaction.intent,
          candidateAction: interaction.candidateAction,
          audioBase64: interaction.audioBase64,
        );
      } else {
        state = state.copyWith(
          status: VoiceInteractionStatus.speaking,
          transcript: interaction.transcript,
          responseText: interaction.responseText,
          intent: interaction.intent,
          candidateAction: null,
          audioBase64: interaction.audioBase64,
        );
      }

      if (interaction.audioBase64 != null) {
        await playSpokenResponse();
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: VoiceInteractionStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> playSpokenResponse() async {
      if (state.audioBase64 != null) {
        try {
          if (!mounted) return;
          state = state.copyWith(isPlayingAudio: true);
          await playbackService.playBase64Audio(state.audioBase64!);
        } catch (_) {
        } finally {
          if (mounted) {
            state = state.copyWith(isPlayingAudio: false);
          }
        }
      }
    }

    Future<void> stopPlayback() async {
      await playbackService.stop();
      if (mounted) {
        state = state.copyWith(isPlayingAudio: false);
      }
    }

  /// Two-Phase Mutation Confirmation:
  /// Merchant explicitly taps 'Confirm' on the proposed candidate card.
  Future<void> confirmCandidateAction() async {
    final candidate = state.candidateAction;
    if (candidate == null) return;

    try {
      state = state.copyWith(status: VoiceInteractionStatus.processing);

      // Phase 1: Draft the reminder via existing LocalActionRepository
      final draft = await actionRepository.draftPaymentReminder(
        promiseId: candidate.promiseId,
        channel: candidate.channel,
        merchantId: authToken,
      );

      // Phase 2: Confirm the action explicitly
      final confirmed = await actionRepository.confirmAction(
        actionId: draft.id,
        merchantId: authToken,
      );

      if (!mounted) return;

      state = state.copyWith(
        status: VoiceInteractionStatus.confirmationCompleted,
        committedAction: confirmed,
        responseText: 'Payment reminder has been created and confirmed for ${candidate.counterpartyName}.',
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: VoiceInteractionStatus.error,
        errorMessage: 'Failed to confirm reminder: $e',
      );
    }
  }

  void cancelCandidateAction() {
    state = state.copyWith(
      status: VoiceInteractionStatus.idle,
      candidateAction: null,
      responseText: 'Action was cancelled.',
    );
  }

  void reset() {
    playbackService.stop();
    recordingService.cancelRecording();
    state = VoiceInteractionState(
      status: VoiceInteractionStatus.idle,
      selectedLanguage: state.selectedLanguage,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    playbackService.stop();
    recordingService.cancelRecording();
    super.dispose();
  }
}
