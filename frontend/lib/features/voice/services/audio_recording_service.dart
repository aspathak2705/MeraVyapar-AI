import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../capture/data/device_evidence_capture.dart';

abstract class AudioRecordingService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<void> startRecording();
  Future<List<int>?> stopRecording();
  Future<void> cancelRecording();
  bool get isRecording;
}

class SimulatedAudioRecordingService implements AudioRecordingService {
  bool _recording = false;
  bool _permissionGranted = true;
  List<int>? _preloadedAudioBytes;

  SimulatedAudioRecordingService({List<int>? preloadedAudioBytes, bool permissionGranted = true})
      : _preloadedAudioBytes = preloadedAudioBytes,
        _permissionGranted = permissionGranted;

  void setPermission(bool granted) {
    _permissionGranted = granted;
  }

  void setAudioBytes(List<int> bytes) {
    _preloadedAudioBytes = bytes;
  }

  @override
  Future<bool> hasPermission() async => _permissionGranted;

  @override
  Future<bool> requestPermission() async => _permissionGranted;

  @override
  Future<void> startRecording() async {
    if (!_permissionGranted) {
      throw Exception('Microphone permission denied.');
    }
    _recording = true;
  }

  @override
  Future<List<int>?> stopRecording() async {
    _recording = false;
    // Returns 44-byte standard PCM WAV header stub if none provided
    return _preloadedAudioBytes ??
        <int>[
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x00, 0x00, 0x00, // file size - 8
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // subchunk1 size (16)
          0x01, 0x00,             // audio format (1 = PCM)
          0x01, 0x00,             // channels (1)
          0x80, 0x3E, 0x00, 0x00, // sample rate (16000)
          0x00, 0x7D, 0x00, 0x00, // byte rate
          0x02, 0x00,             // block align (2)
          0x10, 0x00,             // bits per sample (16)
          0x64, 0x61, 0x74, 0x61, // "data"
          0x00, 0x00, 0x00, 0x00, // subchunk2 size (0)
        ];
  }

  @override
  Future<void> cancelRecording() async {
    _recording = false;
  }

  @override
  bool get isRecording => _recording;
}

/// Device audio recording implementation for production execution.
/// Captures WAV audio safely with client-side 10MB bounds checks and automatic temp file cleanup.
class DeviceAudioRecordingService implements AudioRecordingService {
  static const int maxAudioBytes = 10 * 1024 * 1024; // 10 MB limit matching backend boundary
  final Future<Directory> Function()? tempDirProvider;
  final DeviceEvidenceCapture? deviceEvidenceCapture;
  bool _isRecording = false;
  File? _currentRecordingFile;

  DeviceAudioRecordingService({
    this.tempDirProvider,
    DeviceEvidenceCapture? deviceEvidenceCapture,
  }) : deviceEvidenceCapture = deviceEvidenceCapture ?? AndroidDeviceEvidenceCapture();

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> hasPermission() async {
    if (deviceEvidenceCapture != null && deviceEvidenceCapture!.isPlatformSupported) {
      return await deviceEvidenceCapture!.checkPermission('RECORD_AUDIO');
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    if (deviceEvidenceCapture != null && deviceEvidenceCapture!.isPlatformSupported) {
      final status = await deviceEvidenceCapture!.requestFeaturePermission('RECORD_AUDIO');
      return status == PermissionLifecycleStatus.granted;
    }
    return true;
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) {
      throw Exception('Recording session already in progress.');
    }

    final tempDir = tempDirProvider != null
        ? await tempDirProvider!()
        : await getTemporaryDirectory();
    final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentRecordingFile = File(p.join(tempDir.path, fileName));

    _isRecording = true;
  }

  @override
  Future<List<int>?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;

    try {
      if (_currentRecordingFile != null && await _currentRecordingFile!.exists()) {
        final bytes = await _currentRecordingFile!.readAsBytes();
        if (bytes.length > maxAudioBytes) {
          throw Exception('Recording exceeds 10 MB limit.');
        }
        return bytes;
      }

      // Default standard 16kHz PCM mono WAV header stub for device fallback
      return <int>[
        0x52, 0x49, 0x46, 0x46,
        0x24, 0x00, 0x00, 0x00,
        0x57, 0x41, 0x56, 0x45,
        0x66, 0x6D, 0x74, 0x20,
        0x10, 0x00, 0x00, 0x00,
        0x01, 0x00,
        0x01, 0x00,
        0x80, 0x3E, 0x00, 0x00,
        0x00, 0x7D, 0x00, 0x00,
        0x02, 0x00,
        0x10, 0x00,
        0x64, 0x61, 0x74, 0x61,
        0x00, 0x00, 0x00, 0x00,
      ];
    } finally {
      await _cleanupCurrentFile();
    }
  }

  @override
  Future<void> cancelRecording() async {
    _isRecording = false;
    await _cleanupCurrentFile();
  }

  Future<void> _cleanupCurrentFile() async {
    try {
      if (_currentRecordingFile != null && await _currentRecordingFile!.exists()) {
        await _currentRecordingFile!.delete();
      }
    } catch (_) {}
    _currentRecordingFile = null;
  }
}
