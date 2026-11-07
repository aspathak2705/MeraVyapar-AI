import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_interaction_controller.dart';
import 'voice_confirmation_card.dart';

class VoiceAssistantSheet extends ConsumerWidget {
  final StateNotifierProvider<VoiceInteractionController, VoiceInteractionState> controllerProvider;

  const VoiceAssistantSheet({
    super.key,
    required this.controllerProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title & Language Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.mic, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Voice Assistant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                _buildLanguageSelector(state.selectedLanguage, controller),
              ],
            ),
            const SizedBox(height: 20),

            // Main Status Visualizer
            _buildStatusArea(context, state, controller),

            const SizedBox(height: 24),

            // Bottom Action Controls
            _buildActionControls(context, state, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(String currentLang, VoiceInteractionController controller) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'hi-IN', label: Text('हिंदी', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: 'mr-IN', label: Text('मराठी', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: 'en-IN', label: Text('Eng', style: TextStyle(fontSize: 12))),
      ],
      selected: {currentLang},
      onSelectionChanged: (set) {
        if (set.isNotEmpty) {
          controller.selectLanguage(set.first);
        }
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildStatusArea(
    BuildContext context,
    VoiceInteractionState state,
    VoiceInteractionController controller,
  ) {
    switch (state.status) {
      case VoiceInteractionStatus.idle:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text(
                'Tap microphone to speak',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              SizedBox(height: 6),
              Text(
                'Ask about receivables, overdue promises, or cashflow.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        );

      case VoiceInteractionStatus.requestingPermission:
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Requesting microphone permission...', style: TextStyle(color: Color(0xFF64748B))),
          ),
        );

      case VoiceInteractionStatus.recording:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Listening... (${state.recordingDurationSeconds}s)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Speak your query in your chosen language.',
                style: TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
              ),
            ],
          ),
        );

      case VoiceInteractionStatus.processing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Processing financial speech...',
                style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
            ],
          ),
        );

      case VoiceInteractionStatus.speaking:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.transcript != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '“${state.transcript}”',
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.intent != null ? 'Intent: ${state.intent}' : 'MeraVyapar Insight',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                      if (state.audioBase64 != null)
                        IconButton(
                          icon: Icon(
                            state.isPlayingAudio ? Icons.volume_up : Icons.replay,
                            color: const Color(0xFF1D4ED8),
                            size: 20,
                          ),
                          onPressed: () {
                            if (state.isPlayingAudio) {
                              controller.stopPlayback();
                            } else {
                              controller.playSpokenResponse();
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.responseText ?? '',
                    style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
          ],
        );

      case VoiceInteractionStatus.awaitingConfirmation:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.transcript != null) ...[
              Text(
                '“${state.transcript}”',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
            ],
            VoiceConfirmationCard(
              candidate: state.candidateAction!,
              onConfirm: () => controller.confirmCandidateAction(),
              onCancel: () => controller.cancelCandidateAction(),
            ),
          ],
        );

      case VoiceInteractionStatus.confirmationCompleted:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 36),
              const SizedBox(height: 8),
              Text(
                state.responseText ?? 'Action confirmed successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
              ),
            ],
          ),
        );

      case VoiceInteractionStatus.error:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              Text(
                state.errorMessage ?? 'An error occurred.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF991B1B)),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildActionControls(
    BuildContext context,
    VoiceInteractionState state,
    VoiceInteractionController controller,
  ) {
    if (state.status == VoiceInteractionStatus.recording) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => controller.cancelRecording(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => controller.stopAndProcessRecording(),
            ),
          ),
        ],
      );
    }

    if (state.status == VoiceInteractionStatus.idle ||
        state.status == VoiceInteractionStatus.speaking ||
        state.status == VoiceInteractionStatus.confirmationCompleted ||
        state.status == VoiceInteractionStatus.error) {
      return Row(
        children: [
          if (state.status != VoiceInteractionStatus.idle)
            Expanded(
              child: OutlinedButton(
                onPressed: () => controller.reset(),
                child: const Text('Reset'),
              ),
            ),
          if (state.status != VoiceInteractionStatus.idle) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mic),
              label: Text(state.status == VoiceInteractionStatus.idle ? 'Start Speaking' : 'Ask Another'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => controller.startRecording(),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
