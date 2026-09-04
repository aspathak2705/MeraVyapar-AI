import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/evidence/presentation/manual_entry_screen.dart';
import 'package:frontend/features/evidence/presentation/file_upload_screen.dart';
import 'package:frontend/features/evidence/presentation/evidence_history_screen.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  testWidgets('ManualEntryScreen renders required form fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: ManualEntryScreen(
          onSubmit: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Expense / Payment Sent'), findsOneWidget);
    expect(find.text('Record Financial Evidence'), findsOneWidget);
  });

  testWidgets('FileUploadScreen renders file submission UI', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: FileUploadScreen(
          onUploadPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload Payment Proof or Screenshot'), findsOneWidget);
    expect(find.text('Select Screenshot or Receipt File'), findsOneWidget);
  });

  testWidgets('EvidenceHistoryScreen renders empty state when list is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: const EvidenceHistoryScreen(
          evidenceList: [],
          candidateList: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No financial activity recorded yet.'), findsOneWidget);
  });
}
