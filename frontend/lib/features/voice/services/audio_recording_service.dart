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
