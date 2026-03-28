// ABOUTME: Performance test measuring feed video TTFF under throttled network
// ABOUTME: Scrolls Popular feed; TTFF metrics come from [POOLED] logs in JSONL

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  patrolTest('feed TTFF under throttled network', ($) async {
    final tester = $.tester;
    final originalOnError = suppressSetStateErrors();
    final originalErrorBuilder = saveErrorWidgetBuilder();

    launchAppGuarded(app.main);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Register a fresh user ---
    logPhase('perf: register_start');
    await navigateToCreateAccount(tester);
    final email = 'perf-${DateTime.now().millisecondsSinceEpoch}@test.com';
    await registerNewUser(tester, email, 'TestPass123!');

    // --- Verify email via DB bypass ---
    logPhase('perf: verify_email');
    final token = await getVerificationToken(email);
    await callVerifyEmail(token);

    // --- Wait for feed to appear (polling detection) ---
    logPhase('perf: wait_for_feed');
    final feedLoaded = await waitForText(tester, 'For You', maxSeconds: 30);
    if (!feedLoaded) {
      fail('Feed did not load within 30s after email verification');
    }

    // --- Switch to Popular feed via mode picker bottom sheet ---
    logPhase('perf: switch_to_popular');
    // Tap the current mode label to open the bottom sheet
    await tester.tap(find.text('For You'));
    await tester.pump(const Duration(milliseconds: 500));
    // Select Popular from the bottom sheet
    final popularFound = await waitForText(tester, 'Popular', maxSeconds: 5);
    if (!popularFound) {
      fail('Feed mode bottom sheet did not show "Popular" option');
    }
    await tester.tap(find.text('Popular'));
    await pumpUntilSettled(tester, maxSeconds: 3);

    // --- Wait for Popular feed to load videos ---
    logPhase('perf: popular_feed_loading');
    await pumpUntilSettled(tester);

    // --- Scroll through 10 videos ---
    for (var i = 0; i < 10; i++) {
      logPhase('perf: scroll_video_$i');
      // Fling up to advance to the next video in the fullscreen feed
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.flingFrom(
        Offset(size.width / 2, size.height * 0.8),
        Offset(0, -size.height * 0.6),
        800,
      );
      // Allow time for video to load and start playing
      await tester.pump(const Duration(seconds: 3));
    }

    logPhase('perf: scroll_complete');

    // --- Cleanup ---
    restoreErrorWidgetBuilder(originalErrorBuilder);
    restoreErrorHandler(originalOnError);
    drainAsyncErrors(tester);
  });
}
