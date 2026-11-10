import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/audio_recording_service.dart';
import '../services/wake_word_detector_service.dart';
import 'voice_interaction_controller.dart';

const String _kWakeWordEnabledKey = 'mv_wake_word_namaste_vyapar_enabled';

class WakeWordStateData {
  final WakeWordState state;
  final bool isEnabled;
  final String wakePhrase;
  final String? errorMessage;

  const WakeWordStateData({
    required this.state,
    required this.isEnabled,
    this.wakePhrase = 'Namaste Vyapar',
    this.errorMessage,
  });

  WakeWordStateData copyWith({
    WakeWordState? state,
    bool? isEnabled,
    String? wakePhrase,
    String? errorMessage,
  }) {
    return WakeWordStateData(
      state: state ?? this.state,
      isEnabled: isEnabled ?? this.isEnabled,
      wakePhrase: wakePhrase ?? this.wakePhrase,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Controller managing the foreground-only Namaste Vyapar wake-word lifecycle.
/// Strictly enforces single-microphone ownership and zero continuous cloud audio streaming.
class WakeWordController extends StateNotifier<WakeWordStateData> with WidgetsBindingObserver {
  final WakeWordDetectorEngine detectorEngine;
  final AudioRecordingService recordingService;
  final VoiceInteractionController voiceController;
  final FlutterSecureStorage _storage;

  WakeWordController({
    required this.detectorEngine,
    required this.recordingService,
    required this.voiceController,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        super(const WakeWordStateData(
          state: WakeWordState.disabled,
          isEnabled: false,
        )) {
    WidgetsBinding.instance.addObserver(this);
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final saved = await _storage.read(key: _kWakeWordEnabledKey);
      final isEnabled = saved == 'true';
      if (isEnabled) {
        await enableWakeWord();
      }
    } catch (_) {}
  }

  /// Explicit opt-in by merchant in settings.
  Future<void> enableWakeWord() async {
    state = state.copyWith(
      isEnabled: true,
      state: WakeWordState.initializing,
      errorMessage: null,
    );

    await _storage.write(key: _kWakeWordEnabledKey, value: 'true');

    // Check Android microphone permission
    final hasPerm = await recordingService.hasPermission();
    if (!hasPerm) {
      final granted = await recordingService.requestPermission();
      if (!granted) {
        state = state.copyWith(
          state: WakeWordState.permissionRequired,
          errorMessage: 'Microphone permission required for Namaste Vyapar detection.',
        );
        return;
      }
    }

    final initOk = await detectorEngine.initialize();
    if (!initOk) {
      state = state.copyWith(
        state: WakeWordState.error,
        errorMessage: 'Failed to initialize wake-word acoustic engine.',
      );
      return;
    }

    await startListening();
  }

  /// Explicit disable by merchant.
  Future<void> disableWakeWord() async {
    await stopListening();
    state = state.copyWith(
      isEnabled: false,
      state: WakeWordState.disabled,
      errorMessage: null,
    );
    await _storage.write(key: _kWakeWordEnabledKey, value: 'false');
  }

  /// Starts listening for "Namaste Vyapar" if conditions allow.
  Future<void> startListening() async {
    if (!state.isEnabled) return;

    // Do not capture wake-word if active voice interaction owns microphone
    if (voiceController.state.status == VoiceInteractionStatus.recording ||
        voiceController.state.status == VoiceInteractionStatus.processing) {
      state = state.copyWith(state: WakeWordState.paused);
      return;
    }

    state = state.copyWith(state: WakeWordState.listeningForWakeWord);
    await detectorEngine.startListening(onWakeWordDetected: _onWakeWordDetected);
  }

  /// Stops wake-word listening immediately.
  Future<void> stopListening() async {
    await detectorEngine.stopListening();
    if (state.isEnabled) {
      state = state.copyWith(state: WakeWordState.paused);
    }
  }

  /// Invoked when the acoustic engine detects "Namaste Vyapar".
  void _onWakeWordDetected() async {
    if (state.state != WakeWordState.listeningForWakeWord) return;

    // 1. Immediately stop wake-word listening to release microphone
    await detectorEngine.stopListening();

    state = state.copyWith(state: WakeWordState.wakeWordDetected);

    // 2. Seamlessly transition microphone ownership to existing VoiceInteractionController
    state = state.copyWith(state: WakeWordState.capturingCommand);
    await voiceController.startRecording();
  }

  /// Called after command interaction is completed or cancelled.
  Future<void> onVoiceInteractionEnded() async {
    if (state.isEnabled) {
      await startListening();
    }
  }

  // --- Foreground App Lifecycle Observation ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      // App entered foreground: resume listening if enabled
      if (state.isEnabled) {
        startListening();
      }
    } else if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.inactive ||
        appState == AppLifecycleState.detached) {
      // App entered background or inactive: stop immediately (Zero background listening)
      stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    detectorEngine.dispose();
    super.dispose();
  }
}
