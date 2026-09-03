import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class DeviceEvidenceCapture {
  bool get isPlatformSupported;
  Future<bool> checkPermission(String feature);
  Future<bool> requestPermission(String feature);
}

class AndroidDeviceEvidenceCapture implements DeviceEvidenceCapture {
  static const MethodChannel _channel = MethodChannel('com.meravyapar.ai/capture');

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
