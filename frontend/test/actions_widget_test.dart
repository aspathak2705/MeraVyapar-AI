import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/database/local_database_service.dart';
import 'package:frontend/features/actions/data/local_action_repository.dart';
import 'package:frontend/features/actions/presentation/action_center_screen.dart';
import 'package:frontend/features/actions/presentation/reminder_draft_screen.dart';

void main() {
  testWidgets('ActionCenterScreen displays actions list cleanly', (WidgetTester tester) async {
    final repo = LocalActionRepository(dbService: LocalDatabaseService.instance);

    await tester.pumpWidget(
      MaterialApp(
        home: ActionCenterScreen(
          actionRepository: repo,
          authToken: '00000000-0000-0000-0000-000000000001',
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Merchant Action Center'), findsOneWidget);
  });

  testWidgets('ReminderDraftScreen renders draft and confirm actions', (WidgetTester tester) async {
    final repo = LocalActionRepository(dbService: LocalDatabaseService.instance);

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderDraftScreen(
          actionRepository: repo,
          promiseId: '33333333-3333-3333-3333-333333333333',
          authToken: '00000000-0000-0000-0000-000000000001',
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Payment Reminder Draft'), findsOneWidget);
  });
}
