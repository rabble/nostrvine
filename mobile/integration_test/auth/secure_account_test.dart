// ABOUTME: E2E test for the Secure Account flow (anonymous -> registered)
// ABOUTME: Verifies that an anonymous user can add email/password via the
// ABOUTME: Secure Account screen. Exercises the exportNsec() -> headlessRegister
// ABOUTME: pipeline that has zero E2E coverage. Covers issue #2092 including
// ABOUTME: the Apple Hide-My-Email-shaped-address reporter variant.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('Secure Account Flow', () {
    const testPassword = 'TestPass123!';

    patrolTest(
      'anonymous user can secure account with email and password',
      ($) async {
        final testEmail =
            'secure-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
        await _runSecureAccountFlow(
          $.tester,
          email: testEmail,
          password: testPassword,
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    patrolTest('anonymous user can secure account with an Apple '
        'Hide-My-Email-shaped address (#2092)', ($) async {
      // iOS Hide My Email returns a random local part with an Apple relay
      // domain. Use the local stack's deliverable test domain while keeping
      // the relay-style host and random lowercase-hex local-part shape.
      final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
      final testEmail = '${ts}abcdef012345@privaterelay.test.divine.video';
      await _runSecureAccountFlow(
        $.tester,
        email: testEmail,
        password: testPassword,
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<void> _runSecureAccountFlow(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  final originalOnError = suppressSetStateErrors();
  final originalErrorBuilder = saveErrorWidgetBuilder();
  final semanticsHandle = tester.ensureSemantics();

  launchAppGuarded(app.main);
  await tester.pumpAndSettle(const Duration(seconds: 3));

  await navigateToCreateAccount(tester);

  final skipButton = find.text('Use Divine with no backup');
  expect(skipButton, findsOneWidget);
  await tester.tap(skipButton);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  final confirmSkip = find.text('Use this device only');
  expect(confirmSkip, findsOneWidget);
  await tester.tap(confirmSkip);
  await pumpUntilSettled(tester, maxSeconds: 10);

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  final authService = container.read(authServiceProvider);

  expect(authService.isAuthenticated, isTrue);
  expect(
    authService.isAnonymous,
    isTrue,
    reason: 'User should be anonymous after skipping registration',
  );

  logPhase('Phase 1 complete: anonymous account created');

  await tapBottomNavTab(tester, 'profile_tab');
  await pumpUntilSettled(tester);

  final foundBanner = await waitForText(tester, 'Secure Your Account');
  expect(
    foundBanner,
    isTrue,
    reason: 'Profile should show "Secure Your Account" banner',
  );

  final registerButton = find.widgetWithText(ElevatedButton, 'Register');
  expect(registerButton, findsOneWidget);
  await tester.tap(registerButton);
  await pumpUntilSettled(tester);

  logPhase('Phase 2 complete: navigated to Secure Account screen');

  final foundTitle = await waitForText(tester, 'Secure account');
  expect(foundTitle, isTrue, reason: 'Should be on the Secure Account screen');

  final textFields = find.byType(DivineAuthTextField);
  expect(
    textFields,
    findsNWidgets(3),
    reason:
        'Secure account screen should show email, password, and confirmation',
  );

  await tester.enterText(textFields.at(0), email);
  await tester.pumpAndSettle();
  await tester.enterText(textFields.at(1), password);
  await tester.pumpAndSettle();
  await tester.enterText(textFields.at(2), password);
  await tester.pumpAndSettle();

  await tester.tapAt(const Offset(10, 100));
  await tester.pumpAndSettle();

  final submitButton = find.widgetWithText(DivineButton, 'Secure account');
  expect(submitButton, findsOneWidget);
  await tester.tap(submitButton);
  await pumpUntilSettled(tester, maxSeconds: 10);

  final hasKeyError = find
      .text('Unable to access your keys. Please try again.')
      .evaluate()
      .isNotEmpty;
  expect(
    hasKeyError,
    isFalse,
    reason: 'exportNsec() should not fail - this is the #2092 bug if it does',
  );

  logPhase('Phase 3 complete: form submitted, no key access error');

  final verifyToken = await getVerificationToken(email);
  expect(verifyToken, isNotEmpty);

  await callVerifyEmail(verifyToken);

  var secured = false;
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(seconds: 1));
    if (!authService.isAnonymous && authService.isAuthenticated) {
      secured = true;
      break;
    }
  }

  logPhase(
    'Phase 4 complete: email verified via API '
    '(secured=$secured)',
  );

  expect(
    authService.isAuthenticated,
    isTrue,
    reason: 'User should still be authenticated',
  );
  expect(
    authService.isAnonymous,
    isFalse,
    reason: 'User should no longer be anonymous after securing account',
  );
  expect(
    authService.isRegistered,
    isTrue,
    reason: 'User should be registered (divineOAuth) after securing',
  );

  logPhase('Phase 5 complete: account secured successfully');

  semanticsHandle.dispose();
  drainAsyncErrors(tester);
  restoreErrorHandler(originalOnError);
  restoreErrorWidgetBuilder(originalErrorBuilder);
}
