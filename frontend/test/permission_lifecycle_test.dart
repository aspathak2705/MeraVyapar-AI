import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/capture/data/device_evidence_capture.dart';

class MockDeviceEvidenceCapture implements DeviceEvidenceCapture {
  bool platformSupported;
  Map<String, bool> permissionStates;
  Map<String, PermissionLifecycleStatus> lifecycleStates;

  MockDeviceEvidenceCapture({
    this.platformSupported = true,
    Map<String, bool>? permissions,
    Map<String, PermissionLifecycleStatus>? lifecycle,
  })  : permissionStates = permissions ?? {'RECORD_AUDIO': false, 'NOTIFICATION_LISTENER': false},
        lifecycleStates = lifecycle ?? {
          'RECORD_AUDIO': PermissionLifecycleStatus.notRequested,
          'NOTIFICATION_LISTENER': PermissionLifecycleStatus.denied,
          'POST_NOTIFICATIONS': PermissionLifecycleStatus.notRequested,
          'INTERNET': PermissionLifecycleStatus.granted,
        };

  @override
  bool get isPlatformSupported => platformSupported;

  @override
  Future<bool> checkPermission(String feature) async {
    return permissionStates[feature] ?? false;
  }

  @override
  Future<PermissionLifecycleStatus> requestFeaturePermission(String feature) async {
    final cur = lifecycleStates[feature];
    if (cur == PermissionLifecycleStatus.permanentlyDenied) {
      return PermissionLifecycleStatus.permanentlyDenied;
    }
    lifecycleStates[feature] = PermissionLifecycleStatus.granted;
    permissionStates[feature] = true;
    return PermissionLifecycleStatus.granted;
  }

  @override
  Future<Map<String, PermissionLifecycleStatus>> getDetailedPermissionStatus() async {
    return Map.from(lifecycleStates);
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openNotificationListenerSettings() async => true;

  @override
  void setNotificationHandler(Future<void> Function(Map<String, dynamic> data) handler) {}
}

void main() {
  group('Android Permission & Consent Lifecycle Tests', () {
    test('Initial permission state reports accurately without false positives', () async {
      final mock = MockDeviceEvidenceCapture(
        permissions: {'RECORD_AUDIO': false, 'NOTIFICATION_LISTENER': false},
      );

      final hasMic = await mock.checkPermission('RECORD_AUDIO');
      expect(hasMic, isFalse);

      final hasNotif = await mock.checkPermission('NOTIFICATION_LISTENER');
      expect(hasNotif, isFalse);

      final detailed = await mock.getDetailedPermissionStatus();
      expect(detailed['RECORD_AUDIO'], PermissionLifecycleStatus.notRequested);
      expect(detailed['NOTIFICATION_LISTENER'], PermissionLifecycleStatus.denied);
      expect(detailed['INTERNET'], PermissionLifecycleStatus.granted);
    });

    test('Requesting microphone permission grants and transitions status', () async {
      final mock = MockDeviceEvidenceCapture();

      final status = await mock.requestFeaturePermission('RECORD_AUDIO');
      expect(status, PermissionLifecycleStatus.granted);

      final hasMic = await mock.checkPermission('RECORD_AUDIO');
      expect(hasMic, isTrue);
    });

    test('Permanently denied permission does not trigger false grant', () async {
      final mock = MockDeviceEvidenceCapture(
        lifecycle: {
          'RECORD_AUDIO': PermissionLifecycleStatus.permanentlyDenied,
        },
      );

      final status = await mock.requestFeaturePermission('RECORD_AUDIO');
      expect(status, PermissionLifecycleStatus.permanentlyDenied);
    });
  });
}
