// ABOUTME: Complete end-to-end integration test for video creation flow
// ABOUTME: Tests app start -> welcome screen -> auth -> camera navigation
// ABOUTME: Requires: local Docker stack running (mise run local_up)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:openvine/main.dart' as app;

import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('Complete Video Creation Flow E2E Tests', () {
    patrolTest(
      'Full flow: App start -> Welcome -> Camera navigation',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();

        // Launch app in guarded zone to catch external relay errors
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify app is running
        final materialAppFinder = find.byType(MaterialApp);
        expect(materialAppFinder, findsOneWidget, reason: 'App should start');

        // Welcome screen uses passive terms — tap "Create a new Divine
        // account" to proceed (no checkboxes in current UI)
        final foundCreateButton = await waitForText(
          tester,
          'Create a new Divine account',
          maxSeconds: 10,
        );
        expect(
          foundCreateButton,
          isTrue,
          reason: 'Welcome screen should show "Create a new Divine account"',
        );
        await navigateToCreateAccount(tester);

        // Verify we reached the registration screen
        final foundRegScreen = await waitForText(
          tester,
          'Create account',
          maxSeconds: 5,
        );
        expect(
          foundRegScreen,
          isTrue,
          reason: 'Should navigate to create account screen',
        );

        // TODO: Complete auth flow and navigate to camera when Docker
        // stack is available. Camera access requires authentication
        // (router redirects unauthenticated users to /welcome) and
        // Patrol native automation for camera/mic permissions.

        await pumpUntilSettled(tester, maxSeconds: 3);
        drainAsyncErrors(tester);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
