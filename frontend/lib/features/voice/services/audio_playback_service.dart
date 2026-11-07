import 'dart:convert';
import 'dart:typed_data';

abstract class AudioPlaybackService {
  Future<void> playBase64Audio(String base64Audio);
  Future<void> playBytes(List<int> bytes);
  Future<void> stop();
  bool get isPlaying;
}

class SimulatedAudioPlaybackService implements AudioPlaybackService {
  bool _isPlaying = false;
  Uint8List? _lastPlayedBytes;

  Uint8List? get lastPlayedBytes => _lastPlayedBytes;

  @override
  Future<void> playBase64Audio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      await playBytes(bytes);
    } catch (e) {
      throw Exception('Failed to decode audio playback: $e');
    }
  }

  @override
  Future<void> playBytes(List<int> bytes) async {
    _isPlaying = true;
    _lastPlayedBytes = Uint8List.fromList(bytes);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
  }

  @override
  bool get isPlaying => _isPlaying;
}
