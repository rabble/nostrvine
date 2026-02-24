// ABOUTME: Tests for ForgotPasswordDialog (showForgotPasswordDialog)
// ABOUTME: Verifies dialog rendering, email validation, and reset callback

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';

void main() {
  group('showForgotPasswordDialog', () {
    late List<String> resetEmails;

    setUp(() {
      resetEmails = [];
    });

    Widget createTestWidget({String initialEmail = ''}) {
      return MaterialApp.router(
        theme: VineTheme.theme,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showForgotPasswordDialog(
                      context: context,
                      initialEmail: initialEmail,
                      onSendResetEmail: (email) async {
                        resetEmails.add(email);
                      },
                    ),
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('displays Reset Password title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(find.text('Reset Password'), findsOneWidget);
      });

      testWidgets('displays instructional text', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(
          find.textContaining("Enter your email address and we'll send you"),
          findsOneWidget,
        );
      });

      testWidgets('displays Cancel button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      });

      testWidgets('displays Email Reset Link button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(
          find.widgetWithText(ElevatedButton, 'Email Reset Link'),
          findsOneWidget,
        );
      });

      testWidgets('pre-populates email field', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialEmail: 'user@example.com'),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(find.text('user@example.com'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('Cancel closes dialog', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(find.text('Reset Password'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsNothing);
      });

      testWidgets('shows validation error for invalid email', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        // Clear and enter invalid email
        await tester.enterText(find.byType(TextFormField), 'not-an-email');
        await tester.pump();

        // Tap send
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Email Reset Link'),
        );
        await tester.pumpAndSettle();

        // Dialog should still be open (validation failed)
        expect(find.text('Reset Password'), findsOneWidget);
        expect(resetEmails, isEmpty);
      });

      testWidgets('calls onSendResetEmail with valid email', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialEmail: 'valid@example.com'),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Email Reset Link'),
        );
        await tester.pumpAndSettle();

        expect(resetEmails, equals(['valid@example.com']));
      });

      testWidgets('closes dialog after sending', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialEmail: 'user@example.com'),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Email Reset Link'),
        );
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.text('Reset Password'), findsNothing);
      });
    });
  });
}
