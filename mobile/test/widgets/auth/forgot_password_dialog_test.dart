// ABOUTME: Tests for ForgotPasswordDialog (showForgotPasswordDialog)
// ABOUTME: Verifies dialog rendering, email validation, and reset callback

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show ForgotPasswordResult;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';

void main() {
  group('showForgotPasswordDialog', () {
    late List<String> resetEmails;

    setUp(() {
      resetEmails = [];
    });

    Widget createTestWidget({
      String initialEmail = '',
      Future<ForgotPasswordResult> Function(String email)? onSendResetEmail,
    }) {
      return MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
                      onSendResetEmail:
                          onSendResetEmail ??
                          (email) async {
                            resetEmails.add(email);
                            return ForgotPasswordResult(success: true);
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

      testWidgets('keeps dialog open and shows retry copy when sending fails', (
        tester,
      ) async {
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (message) async {
                final data = message! as Map<Object?, Object?>;
                if (data['type'] == 'announce') {
                  final payload = data['data']! as Map<Object?, Object?>;
                  announcements.add(payload['message']! as String);
                }
                return null;
              },
            );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger
              .setMockDecodedMessageHandler<Object?>(
                SystemChannels.accessibility,
                null,
              ),
        );
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) async => ForgotPasswordResult(
              success: false,
              error: 'Server response must not be shown',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Email Reset Link'),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.text(l10n.authFailedToSendResetEmail), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, l10n.authTryAgain),
          findsOneWidget,
        );
        expect(announcements, contains(l10n.authFailedToSendResetEmail));
        expect(find.text('Server response must not be shown'), findsNothing);
      });
    });
  });
}
