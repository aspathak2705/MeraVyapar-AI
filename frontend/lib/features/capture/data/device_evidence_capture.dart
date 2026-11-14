import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PermissionLifecycleStatus {
  granted,
  denied,
  permanentlyDenied,
  notRequested,
  unsupported,
}

abstract class DeviceEvidenceCapture {
  bool get isPlatformSupported;
  Future<bool> checkPermission(String feature);
  Future<PermissionLifecycleStatus> requestFeaturePermission(String feature);
  Future<Map<String, PermissionLifecycleStatus>> getDetailedPermissionStatus();
  Future<bool> openAppSettings();
  Future<bool> openNotificationListenerSettings();
  void setNotificationHandler(Future<void> Function(Map<String, dynamic> data) handler);
  void setQuickEntryHandler(Future<void> Function(Map<String, dynamic> data) handler);
  Future<bool> showQuickEntryNotification();
  Future<bool> notifyQuickEntrySuccess(String amount, String type);
}

class AndroidDeviceEvidenceCapture implements DeviceEvidenceCapture {
  static const MethodChannel _channel = MethodChannel('com.meravyapar.ai/capture');
  Future<void> Function(Map<String, dynamic> data)? _notificationHandler;
  Future<void> Function(Map<String, dynamic> data)? _quickEntryHandler;

  AndroidDeviceEvidenceCapture() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null && _notificationHandler != null) {
        await _notificationHandler!(Map<String, dynamic>.from(args));
      }
    } else if (call.method == 'onQuickEntrySubmitted') {
      final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null && _quickEntryHandler != null) {
        await _quickEntryHandler!(Map<String, dynamic>.from(args));
      }
    }
  }

  @override
  void setNotificationHandler(Future<void> Function(Map<String, dynamic> data) handler) {
    _notificationHandler = handler;
  }

  @override
  void setQuickEntryHandler(Future<void> Function(Map<String, dynamic> data) handler) {
    _quickEntryHandler = handler;
  }

  @override
  Future<bool> showQuickEntryNotification() async {
    if (!isPlatformSupported) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('showQuickEntryNotification');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> notifyQuickEntrySuccess(String amount, String type) async {
    if (!isPlatformSupported) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('notifyQuickEntrySuccess', {
        'amount': amount,
        'type': type,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
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
  Future<PermissionLifecycleStatus> requestFeaturePermission(String feature) async {
    if (!isPlatformSupported) return PermissionLifecycleStatus.unsupported;
    try {
      final dynamic result = await _channel.invokeMethod('requestPermission', {'feature': feature});
      if (result == true || result == 'GRANTED') {
        return PermissionLifecycleStatus.granted;
      } else if (result == 'PERMANENTLY_DENIED') {
        return PermissionLifecycleStatus.permanentlyDenied;
      } else {
        return PermissionLifecycleStatus.denied;
      }
    } on MissingPluginException {
      return PermissionLifecycleStatus.unsupported;
    } catch (_) {
      return PermissionLifecycleStatus.denied;
    }
  }

  @override
  Future<Map<String, PermissionLifecycleStatus>> getDetailedPermissionStatus() async {
    if (!isPlatformSupported) {
      return {
        'RECORD_AUDIO': PermissionLifecycleStatus.unsupported,
        'NOTIFICATION_LISTENER': PermissionLifecycleStatus.unsupported,
        'POST_NOTIFICATIONS': PermissionLifecycleStatus.unsupported,
        'INTERNET': PermissionLifecycleStatus.unsupported,
      };
    }

    try {
      final dynamic raw = await _channel.invokeMethod('getDetailedPermissionStatus');
      if (raw is Map) {
        final Map<String, PermissionLifecycleStatus> result = {};
        raw.forEach((key, value) {
          final k = key.toString();
          final v = value.toString();
          if (v == 'GRANTED' || v == 'CONNECTED') {
            result[k] = PermissionLifecycleStatus.granted;
          } else if (v == 'PERMANENTLY_DENIED') {
            result[k] = PermissionLifecycleStatus.permanentlyDenied;
          } else if (v == 'NOT_REQUESTED') {
            result[k] = PermissionLifecycleStatus.notRequested;
          } else {
            result[k] = PermissionLifecycleStatus.denied;
          }
        });
        return result;
      }
    } catch (_) {}

    return {
      'RECORD_AUDIO': PermissionLifecycleStatus.notRequested,
      'NOTIFICATION_LISTENER': PermissionLifecycleStatus.denied,
      'POST_NOTIFICATIONS': PermissionLifecycleStatus.notRequested,
      'INTERNET': PermissionLifecycleStatus.denied,
    };
  }

  @override
  Future<bool> openAppSettings() async {
    if (!isPlatformSupported) return false;
    try {
      final bool? res = await _channel.invokeMethod<bool>('openAppSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openNotificationListenerSettings() async {
    if (!isPlatformSupported) return false;
    try {
      final bool? res = await _channel.invokeMethod<bool>('openNotificationListenerSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
