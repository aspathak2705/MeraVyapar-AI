import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/capture/presentation/capture_center_screen.dart';
import 'package:frontend/features/capture/presentation/capture_settings_screen.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('CaptureCenterScreen renders capture actions and non-android warning', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: CaptureCenterScreen(
          isAndroidPlatform: false,
          onAddManual: () {},
          onShareProof: () {},
          onOpenNotificationSettings: () {},
          onOpenSmsSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evidence Capture Center'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);
    expect(find.text('Passive Notification and SMS capture are unsupported on this platform.'), findsOneWidget);
  });

  testWidgets('CaptureSettingsScreen renders provider selection switches', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: CaptureSettingsScreen(
          title: 'Payment Notification Settings',
          sourceType: 'NOTIFICATION_CAPTURE',
          settings: const [],
          onToggleSetting: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Notification Settings'), findsOneWidget);
    expect(find.text('Merchant Permission & Consent'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('PhonePe'), findsOneWidget);
  });
}
