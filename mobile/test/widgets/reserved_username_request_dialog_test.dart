// ABOUTME: Widget tests for ReservedUsernameRequestDialog
// ABOUTME: Tests UI rendering, form validation, submission flow, and error handling

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/reserved_username_request_repository.dart';
import 'package:openvine/widgets/reserved_username_request_dialog.dart';

class MockReservedUsernameRequestRepository extends Mock
    implements ReservedUsernameRequestRepository {}

void main() {
  group('ReservedUsernameRequestDialog', () {
    late MockReservedUsernameRequestRepository mockRepository;

    setUp(() {
      mockRepository = MockReservedUsernameRequestRepository();
    });

    Widget buildSubject({String username = 'testuser'}) {
      return ProviderScope(
        overrides: [
          reservedUsernameRequestRepositoryProvider
              .overrideWithValue(mockRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ReservedUsernameRequestDialog(username: username),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
    }

    testWidgets('renders with correct title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      expect(find.text('Request Reserved Username'), findsOneWidget);
    });

    testWidgets('displays the passed username in read-only field', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(username: 'satoshi'));
      await openDialog(tester);

      // Find the username field (first TextField, read-only)
      final usernameFinder = find.widgetWithText(TextField, 'satoshi');
      expect(usernameFinder, findsOneWidget);

      final usernameField = tester.widget<TextField>(usernameFinder);
      expect(usernameField.readOnly, isTrue);
    });

    testWidgets('email field is editable and accepts input', (tester) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Find email field by label
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      expect(emailField, findsOneWidget);

      // Enter email
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('justification field is editable and accepts input', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Find justification field by label
      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      expect(justificationField, findsOneWidget);

      // Enter justification
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      expect(find.text('I am the brand owner'), findsOneWidget);
    });

    testWidgets('Submit button is disabled when fields are empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Find Submit Request button
      final submitButton = find.text('Submit Request');
      expect(submitButton, findsOneWidget);

      // Button should be disabled (onPressed is null)
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: submitButton,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Submit button is disabled when email is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Enter invalid email
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'invalid-email');
      await tester.pump();

      // Enter valid justification
      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Submit button should still be disabled due to invalid email
      final submitButton = find.text('Submit Request');
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: submitButton,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Submit button is enabled when all fields are valid', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Enter valid email
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      // Enter valid justification
      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Submit button should be enabled
      final submitButton = find.text('Submit Request');
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: submitButton,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Cancel button is visible and closes dialog', (tester) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Verify Cancel button exists
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Request Reserved Username'), findsNothing);
    });

    testWidgets('shows loading indicator during submission', (tester) async {
      // Mock with delay
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return const ReservedUsernameRequestResult.success();
      });

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for async operation to complete
      await tester.pumpAndSettle();
    });

    testWidgets('shows success message after successful submission', (
      tester,
    ) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async => const ReservedUsernameRequestResult.success(),
      );

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(); // Complete async operation

      // Should show success message
      expect(
        find.textContaining("Request submitted! We'll review it"),
        findsOneWidget,
      );
    });

    testWidgets('shows error message on failed submission', (tester) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async =>
            const ReservedUsernameRequestResult.failure('Network error'),
      );

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(); // Complete async operation

      // Should show error message
      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('dialog auto-closes after success with timer', (tester) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async => const ReservedUsernameRequestResult.success(),
      );

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Dialog should be open
      expect(find.text('Request Reserved Username'), findsOneWidget);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(); // Complete async operation (success state set)

      // Dialog should still be open after success
      expect(find.text('Request Reserved Username'), findsOneWidget);

      // Wait for 1.5 seconds (auto-dismiss timer) + execute callback
      await tester.pumpAndSettle(const Duration(milliseconds: 1500));

      // Dialog should now be closed
      expect(find.text('Request Reserved Username'), findsNothing);
    });

    testWidgets('shows email validation error for invalid email', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Enter invalid email
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'invalid-email');
      await tester.pump();

      // Should show validation error
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('does not show email validation error when field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Email field should be empty initially
      // Should NOT show validation error for empty field
      expect(find.text('Please enter a valid email'), findsNothing);
    });

    testWidgets('hides Cancel button after successful submission', (
      tester,
    ) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async => const ReservedUsernameRequestResult.success(),
      );

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Cancel button should be visible initially
      expect(find.text('Cancel'), findsOneWidget);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(); // Complete async operation

      // Cancel button should be hidden after success
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('changes Submit button to Close after successful submission', (
      tester,
    ) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async => const ReservedUsernameRequestResult.success(),
      );

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Initial state - should have "Submit Request" button
      expect(find.text('Submit Request'), findsOneWidget);
      expect(find.text('Close'), findsNothing);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(); // Complete async operation

      // After success - should have "Close" button instead of "Submit Request"
      expect(find.text('Submit Request'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Close button dismisses dialog after success', (tester) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async => const ReservedUsernameRequestResult.success(),
      );

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Fill in form and submit
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump(); // Complete async operation

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Request Reserved Username'), findsNothing);
    });

    testWidgets('disables fields during submission', (tester) async {
      // Mock with delay to test submitting state
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return const ReservedUsernameRequestResult.success();
      });

      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'test@example.com');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I am the brand owner',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();

      // Fields should be disabled during submission
      final emailTextFieldWidget = tester.widget<TextField>(emailField);
      expect(emailTextFieldWidget.enabled, isFalse);

      final justificationTextFieldWidget =
          tester.widget<TextField>(justificationField);
      expect(justificationTextFieldWidget.enabled, isFalse);

      // Wait for completion
      await tester.pumpAndSettle();
    });

    testWidgets('calls repository with correct parameters', (tester) async {
      when(
        () => mockRepository.submitRequest(
          username: any(named: 'username'),
          email: any(named: 'email'),
          justification: any(named: 'justification'),
        ),
      ).thenAnswer(
        (_) async => const ReservedUsernameRequestResult.success(),
      );

      await tester.pumpWidget(buildSubject(username: 'satoshi'));
      await openDialog(tester);

      // Fill in form
      final emailField = find.ancestor(
        of: find.text('Your Email'),
        matching: find.byType(TextField),
      );
      await tester.enterText(emailField, 'satoshi@bitcoin.org');

      final justificationField = find.ancestor(
        of: find.text('Why should you have this username?'),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        justificationField,
        'I created Bitcoin',
      );
      await tester.pump();

      // Tap Submit
      await tester.tap(find.text('Submit Request'));
      await tester.pump();
      await tester.pump();

      // Verify repository was called with correct parameters
      verify(
        () => mockRepository.submitRequest(
          username: 'satoshi',
          email: 'satoshi@bitcoin.org',
          justification: 'I created Bitcoin',
        ),
      ).called(1);
    });

    testWidgets('username field shows lock icon for reserved status', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await openDialog(tester);

      // Look for lock icon in username field
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });
}
