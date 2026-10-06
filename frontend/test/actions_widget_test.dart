import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/features/actions/data/action_repository.dart';
import 'package:frontend/features/actions/presentation/action_center_screen.dart';
import 'package:frontend/features/actions/presentation/reminder_draft_screen.dart';

void main() {
  testWidgets('ActionCenterScreen displays actions list cleanly', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/actions')) {
        return http.Response(
          '''[
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "merchant_id": "00000000-0000-0000-0000-000000000001",
              "action_type": "PAYMENT_REMINDER",
              "channel": "WHATSAPP",
              "status": "READY_FOR_REVIEW",
              "draft_content": "Reminder content",
              "final_content": "Reminder content edited",
              "idempotency_key": "key1",
              "created_at": "2026-09-04T12:00:00Z"
            }
          ]''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final repo = ActionRepository(baseUrl: 'http://localhost:8000', client: mockClient);

    await tester.pumpWidget(
      MaterialApp(
        home: ActionCenterScreen(
          actionRepository: repo,
          authToken: 'test_token',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Merchant Action Center'), findsOneWidget);
    expect(find.textContaining('PAYMENT_REMINDER'), findsOneWidget);
    expect(find.textContaining('Ready for Review'), findsOneWidget);
  });

  testWidgets('ReminderDraftScreen renders draft and confirm actions', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/actions/draft-reminder')) {
        return http.Response(
          '''{
            "id": "22222222-2222-2222-2222-222222222222",
            "merchant_id": "00000000-0000-0000-0000-000000000001",
            "action_type": "PAYMENT_REMINDER",
            "channel": "WHATSAPP",
            "status": "DRAFT",
            "draft_content": "Dear partner, please pay ₹5,000",
            "idempotency_key": "key2",
            "created_at": "2026-09-04T12:00:00Z"
          }''',
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final repo = ActionRepository(baseUrl: 'http://localhost:8000', client: mockClient);

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderDraftScreen(
          actionRepository: repo,
          promiseId: '33333333-3333-3333-3333-333333333333',
          authToken: 'test_token',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Payment Reminder Draft'), findsOneWidget);
    expect(find.textContaining('Dear partner, please pay ₹5,000'), findsOneWidget);
    expect(find.text('Save & Mark Ready for Review'), findsOneWidget);
    expect(find.text('Explicitly Confirm Action'), findsOneWidget);
  });
}
