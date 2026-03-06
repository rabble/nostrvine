// ABOUTME: Test that verify-email deep links work for authenticated users
// ABOUTME: Reproduces the cross-user scenario: User A logged in, User B's
// ABOUTME: verification link opened on the same device
// ABOUTME: Requires: local Docker stack running (mise run local_up)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('Cross-user email verification', () {
    final userAEmail =
        'usera-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const password = 'TestPass123!';

    patrolTest(
      'authenticated user can reach verify-email screen via deep link',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();

        // Launch the full app
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Register User A and complete verification ──
        await navigateToCreateAccount(tester);
        await registerNewUser(tester, userAEmail, password);

        // Wait for verification screen
        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Should navigate to email verification screen',
        );

        // Get verification token from DB and trigger deep link
        final verifyToken = await getVerificationToken(userAEmail);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final emailListener = container.read(emailVerificationListenerProvider);
        await emailListener.handleUri(
          Uri.parse(
            'https://login.divine.video/verify-email?token=$verifyToken',
          ),
        );

        // Wait for verification + login to complete
        final leftVerifyScreen = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(
          leftVerifyScreen,
          isTrue,
          reason: 'Polling should detect verification and navigate away',
        );

        await pumpUntilSettled(tester);

        // Confirm we're on the main app (authenticated as User A)
        final hasMainApp =
            find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('Trending').evaluate().isNotEmpty;
        expect(
          hasMainApp,
          isTrue,
          reason: 'Should be on main app as authenticated User A',
        );

        // ── Cross-user scenario ──
        // User B registered on a different device and got a verification
        // email. The link is opened on THIS device where User A is logged
        // in. The router must NOT block /verify-email for authenticated
        // users — the endpoint is token-based and works regardless of who
        // calls it.

        // Simulate User B's deep link with a dummy token.
        // (We reuse User A's already-used token — the important thing is
        // that the router lets us REACH the screen, not that verification
        // succeeds. The screen will show "Verification Failed" or similar,
        // which proves the router allowed it through.)
        await emailListener.handleUri(
          Uri.parse(
            'https://login.divine.video/verify-email?token=$verifyToken',
          ),
        );

        // The verification screen should load — any of these texts means
        // the router allowed the authenticated user through.
        var foundVerifyFeedback = false;
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.text('Verifying...').evaluate().isNotEmpty ||
              find.text('Welcome to Divine!').evaluate().isNotEmpty ||
              find.text('Uh oh.').evaluate().isNotEmpty ||
              find.text('Complete your registration').evaluate().isNotEmpty) {
            foundVerifyFeedback = true;
            break;
          }
        }
        expect(
          foundVerifyFeedback,
          isTrue,
          reason:
              'Authenticated user should see verification screen via deep '
              'link, not get silently redirected to home. This blocks '
              'cross-user verification: if User B sends a verify link to a '
              'device where User A is logged in, the verification must '
              'still reach the server.',
        );

        await pumpUntilSettled(tester, maxSeconds: 3);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
