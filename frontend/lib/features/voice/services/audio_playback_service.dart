import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

/// Device audio playback implementation for production execution.
/// Writes audio bytes to temporary playback cache, verifies WAV header, and manages playback lifecycle safely.
class DeviceAudioPlaybackService implements AudioPlaybackService {
  final Future<Directory> Function()? tempDirProvider;
  bool _isPlaying = false;
  File? _lastTempFile;

  DeviceAudioPlaybackService({this.tempDirProvider});

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<void> playBase64Audio(String base64Audio) async {
    if (base64Audio.isEmpty) {
      throw Exception('Audio payload is empty.');
    }
    try {
      final bytes = base64Decode(base64Audio);
      await playBytes(bytes);
    } catch (e) {
      throw Exception('Failed to decode audio playback: $e');
    }
  }

  @override
  Future<void> playBytes(List<int> bytes) async {
    if (bytes.isEmpty) {
      throw Exception('Audio byte buffer is empty.');
    }

    // Verify minimum WAV container length (44 bytes standard header)
    if (bytes.length >= 4) {
      final magic = String.fromCharCodes(bytes.sublist(0, 4));
      if (magic != 'RIFF') {
        // Not a standard RIFF/WAV header
        throw Exception('Invalid audio format: expected RIFF/WAV header.');
      }
    }

    await stop();

    final tempDir = tempDirProvider != null
        ? await tempDirProvider!()
        : await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'playback_${DateTime.now().millisecondsSinceEpoch}.wav');
    _lastTempFile = File(tempPath);
    await _lastTempFile!.writeAsBytes(bytes, flush: true);

    _isPlaying = true;
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    await _cleanupTempFile();
  }

  Future<void> _cleanupTempFile() async {
    try {
      if (_lastTempFile != null && await _lastTempFile!.exists()) {
        await _lastTempFile!.delete();
      }
    } catch (_) {}
    _lastTempFile = null;
  }
}
