import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';
import 'package:frontend/features/auth/presentation/auth_screen.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('App renders configuration required screen when unconfigured', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeraVyaparApp()));
    await tester.pumpAndSettle();

    expect(find.text('Environment Configuration Required'), findsOneWidget);
  });

  testWidgets('AuthScreen renders cleanly when displayed', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.theme,
          home: AuthScreen(
            onSubmit: (email, password, isSignUp) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MeraVyapar AI'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
