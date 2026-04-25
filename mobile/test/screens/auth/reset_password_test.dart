// ABOUTME: Tests for ResetPasswordScreen autofill integration
// ABOUTME: Verifies AutofillGroup wrapping, newPassword hint, and
// ABOUTME: finishAutofillContext call on successful password reset.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/reset_password.dart';

import '../../helpers/autofill_context_mock.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  group(ResetPasswordScreen, () {
    late _MockKeycastOAuth mockOAuth;

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          oauthClientProvider.overrideWithValue(mockOAuth),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResetPasswordScreen(token: 'test-token-abc123'),
        ),
      );
    }

    group('autofill', () {
      testWidgets('password field has AutofillHints.newPassword', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // DivineAuthTextField forwards autofillHints to the underlying
        // TextField. Find the TextField whose autofillHints contains
        // AutofillHints.newPassword.
        final matchingField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              (widget.autofillHints?.contains(AutofillHints.newPassword) ??
                  false),
        );

        expect(matchingField, findsOneWidget);
      });

      testWidgets('wraps form in $AutofillGroup', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AutofillGroup), findsOneWidget);
      });

      testWidgets('calls TextInput.finishAutofillContext on successful reset', (
        tester,
      ) async {
        final recorder = AutofillContextRecorder.install();

        when(
          () => mockOAuth.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async => ResetPasswordResult(success: true));

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Enter a valid password (>= 8 characters).
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'New Password'),
            matching: find.byType(TextField),
          ),
          'NewSecure123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Update password'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(recorder.didFinishAutofillContext, isTrue);
      });
    });
  });
}
