// ABOUTME: Tests for ForgotPasswordSheetContent
// ABOUTME: Verifies email autofill hints for password manager integration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show ForgotPasswordResult;
import 'package:openvine/screens/auth/forgot_password/forgot_password_sheet_content.dart';

void main() {
  group('ForgotPasswordSheetContent', () {
    late TextEditingController emailController;

    setUp(() {
      emailController = TextEditingController();
    });

    tearDown(() {
      emailController.dispose();
    });

    Widget createTestWidget({
      String initialEmail = '',
      Future<ForgotPasswordResult> Function(String)? onSendResetLink,
    }) {
      emailController = TextEditingController(text: initialEmail);
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: ForgotPasswordSheetContent(
            initialEmail: initialEmail,
            onSendResetLink:
                onSendResetLink ??
                (_) async => ForgotPasswordResult(success: false),
          ),
        ),
      );
    }

    testWidgets('email field has AutofillHints.email', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the underlying TextField that receives the forwarded autofillHints
      final matched = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.autofillHints?.contains(AutofillHints.email) ?? false),
      );
      expect(matched, findsOneWidget);
    });

    testWidgets('renders email input field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('pre-populates email field with initialEmail', (tester) async {
      const testEmail = 'user@example.com';
      await tester.pumpWidget(createTestWidget(initialEmail: testEmail));
      await tester.pumpAndSettle();

      expect(find.text(testEmail), findsOneWidget);
    });
  });
}
