import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class DeviceEvidenceCapture {
  bool get isPlatformSupported;
  Future<bool> checkPermission(String feature);
  Future<bool> requestPermission(String feature);
  void setNotificationHandler(Future<void> Function(Map<String, dynamic> data) handler);
}

class AndroidDeviceEvidenceCapture implements DeviceEvidenceCapture {
  static const MethodChannel _channel = MethodChannel('com.meravyapar.ai/capture');
  Future<void> Function(Map<String, dynamic> data)? _notificationHandler;

  AndroidDeviceEvidenceCapture() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null && _notificationHandler != null) {
        await _notificationHandler!(Map<String, dynamic>.from(args));
      }
    }
  }

  @override
  void setNotificationHandler(Future<void> Function(Map<String, dynamic> data) handler) {
    _notificationHandler = handler;
  }

  @override
  bool get isPlatformSupported => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> checkPermission(String feature) async {
    if (!isPlatformSupported) return false;
    try {
      final bool result = await _channel.invokeMethod('checkPermission', {'feature': feature});
      return result;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission(String feature) async {
    if (!isPlatformSupported) return false;
    try {
      final bool result = await _channel.invokeMethod('requestPermission', {'feature': feature});
      return result;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
