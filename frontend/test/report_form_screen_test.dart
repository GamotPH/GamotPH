import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/report_form_screen.dart';

void main() {
  testWidgets('ReportFormScreen renders and submits data', (
    WidgetTester tester,
  ) async {
    // Render the widget inside a MaterialApp
    await tester.pumpWidget(const MaterialApp(home: ReportFormScreen()));

    await tester.pumpAndSettle(); // Wait for all widgets to render

    // Fill text fields using their labelText
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Patient Age'),
      '35',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Drug Name'),
      'Biogesic',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reaction Description'),
      'Rash and fever',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location (e.g., Makati City)'),
      'Quezon City',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'AI Assistance Response'),
      'Allergy warning',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Case Priority Score'),
      '7.5',
    );

    // Select Gender
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Male'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();

    // Select Severity
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'mild'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Severe').last);
    await tester.pumpAndSettle();

    // Submit the form
    final submitButton = find.widgetWithText(ElevatedButton, 'Submit');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pump(); // show snackbar

    // Expect confirmation message
    expect(find.textContaining('Submitting ADR Report'), findsOneWidget);
  });
}
