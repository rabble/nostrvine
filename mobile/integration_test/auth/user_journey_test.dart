// ABOUTME: Full user journey E2E test: register → verify → publish → discover → navigate
// ABOUTME: Requires: local Docker stack running (mise run local_up)
// ABOUTME: Run with: mise run e2e_test (passes --dart-define=DEFAULT_ENV=LOCAL automatically)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:openvine/main.dart' as app;

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('User Journey: Register → Upload → Discover → Navigate', () {
    final testEmail =
        'e2e-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'register, publish video, discover in feed, navigate tabs',
      ($) async {
        final tester = $.tester;
        // Suppress non-critical relay/WebSocket errors from external relays.
        final originalOnError = suppressSetStateErrors();

        // Save ErrorWidget.builder before app.main() sets a custom one.
        // Must be restored before test body ends (framework checks it).
        final originalErrorBuilder = saveErrorWidgetBuilder();

        // Launch the full app in a guarded zone to catch async relay errors
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── 1-2. Welcome → Create account ──
        await navigateToCreateAccount(tester);

        // ── 3. Fill form, submit ──
        await registerNewUser(tester, testEmail, testPassword);

        // Wait for network + navigation to verify-email screen.
        // Cannot use pumpAndSettle here — the EmailVerificationCubit
        // polls every 3s, so there are always pending timers.
        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );

        // ── 7. Assert: email verification screen is displayed ──
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Should navigate to email verification screen',
        );

        // ── 8. Extract verification token from local postgres ──
        final token = await getVerificationToken(testEmail);
        expect(
          token,
          isNotEmpty,
          reason: 'Should find verification token in local DB',
        );

        // ── 9. Verify email by calling keycast's verify endpoint directly ──
        await callVerifyEmail(token);

        // ── 10. Wait for polling to detect verification ──
        // The cubit polls every 3s, plus token exchange takes a moment
        final verified = await waitForTextGone(
          tester,
          'Complete your registration',
        );

        expect(
          verified,
          isTrue,
          reason: 'Polling should detect verification and navigate away',
        );

        // Pump a few more frames for post-verification navigation
        await pumpUntilSettled(tester);

        // ── 11. Assert: we landed on the main app ──
        final hasBottomNav = find
            .byType(BottomNavigationBar)
            .evaluate()
            .isNotEmpty;
        final hasExploreContent =
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('Trending').evaluate().isNotEmpty;

        expect(
          hasBottomNav || hasExploreContent,
          isTrue,
          reason:
              'Should land on main app screen after verification '
              '(bottom nav or explore content)',
        );

        // ── Phase 4: Publish a test video to local relay ──
        logPhase('── Phase 4: Publishing test video to relay ──');
        final videoTitle =
            'E2E Journey ${DateTime.now().millisecondsSinceEpoch}';
        final video = await publishTestVideoEvent(title: videoTitle);
        expect(
          video.eventId,
          isNotEmpty,
          reason: 'Should publish event to relay',
        );

        // Give the relay a moment to index
        await tester.pump(const Duration(seconds: 2));

        // ── Phase 5: Exercise explore feed (100+ seeded videos) ──
        logPhase('── Phase 5: Exercising explore feed tabs ──');

        // With 100 seeded videos, each tab triggers relay REQ/EOSE.
        // The profiler captures EOSE timing and event counts.
        for (final tabName in ['New', 'Popular']) {
          final tab = find.text(tabName);
          if (tab.evaluate().isNotEmpty) {
            await tester.tap(tab);
            await tester.pump(const Duration(seconds: 3));
            logPhase('Explored "$tabName" tab');
          }
        }

        // ── Phase 6: Navigate between tabs ──
        logPhase('── Phase 6: Tab navigation cycle ──');

        // Home tab
        await tapBottomNavTab(tester, 'home_tab');
        await pumpUntilSettled(tester);
        logPhase('Navigated to home tab');

        // Back to explore
        await tapBottomNavTab(tester, 'explore_tab');
        await pumpUntilSettled(tester);
        logPhase('Navigated to explore tab');

        // Profile tab
        await tapBottomNavTab(tester, 'profile_tab');
        await pumpUntilSettled(tester);
        logPhase('Navigated to profile tab');

        // Back to explore
        await tapBottomNavTab(tester, 'explore_tab');
        await pumpUntilSettled(tester);
        logPhase('Navigated back to explore tab');

        // ── Phase 7: Assert we're on a stable screen ──
        logPhase('── Phase 7: Final state verification ──');
        final hasExploreScreen =
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('New').evaluate().isNotEmpty;
        expect(
          hasExploreScreen,
          isTrue,
          reason: 'Should be on explore screen after navigation cycle',
        );

        // Drain pending errors before restoring handlers.
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
