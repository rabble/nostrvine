// ABOUTME: E2E test verifying fix for bug #2163: deleted video visibility
// ABOUTME: After kind 5 delete, refreshIfStale() on profile navigation
// ABOUTME: triggers a REST API re-fetch that filters the deleted video

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  group('Bug #2163: Other users see deleted videos', () {
    final testEmail =
        'e2e-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'deleted video disappears after re-navigation',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();

        // Use a short staleness TTL so we don't wait 30s in the test.
        ProfileFeed.staleTtl = const Duration(seconds: 3);

        // ── Phase 1: Seed relay with User A's profile and video ──
        logPhase('── Phase 1: Seed User A profile + video on relay ──');

        final userA = await publishTestProfileEvent(
          name: 'e2e-user-a',
          displayName: 'E2E User A',
          about: 'Test user for deletion bug reproduction',
        );
        logPhase('User A profile published: ${userA.pubkey}');

        final video = await publishTestVideoEvent(
          title: 'Video That Will Be Deleted',
          privateKey: userA.privateKey,
        );
        logPhase('User A video published: ${video.eventId}');

        // Wait for the video to be queryable on the relay (WebSocket).
        var preCheck = <dynamic>[];
        for (var i = 0; i < 10; i++) {
          preCheck = await queryRelay({
            'kinds': [34236],
            'authors': [userA.pubkey],
          });
          if (preCheck.isNotEmpty) break;
          logPhase('Relay pre-check attempt ${i + 1}: empty, retrying...');
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(
          preCheck,
          isNotEmpty,
          reason: 'User A video should be on relay before app launch',
        );
        logPhase('Relay pre-check passed: video present');

        // Wait for ClickHouse to materialize the video so the REST API
        // returns it. Without this, ProfileFeedProvider falls back to
        // Nostr (which caches indefinitely and won't reflect deletions).
        logPhase('Waiting for Funnelcake REST API to index the video...');
        final indexed = await waitForFunnelcakeVideo(userA.pubkey);
        expect(
          indexed,
          isTrue,
          reason: 'Funnelcake REST API should index the video within 30s',
        );
        logPhase('Funnelcake REST API confirmed: video indexed');

        // ── Phase 2: Launch app as User B, register ──
        logPhase('── Phase 2: Launch app, register User B ──');

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerifyScreen, isTrue);

        final token = await getVerificationToken(testEmail);
        expect(token, isNotEmpty);
        await callVerifyEmail(token);

        final verified = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(verified, isTrue);
        await pumpUntilSettled(tester);

        final hasBottomNav = find
            .bySemanticsIdentifier('home_tab')
            .evaluate()
            .isNotEmpty;
        expect(
          hasBottomNav,
          isTrue,
          reason: 'Should land on main app after verification',
        );
        logPhase('User B registered and on main app');

        // ── Phase 3: Navigate to User A's profile, see video ──
        logPhase('── Phase 3: Navigate to User A profile ──');

        final userANpub = Nip19.encodePubKey(userA.pubkey);
        final profilePath = OtherProfileScreen.pathForNpub(userANpub);

        final router = GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        );
        router.push(profilePath);
        await pumpUntilSettled(tester);
        logPhase('Pushed to User A profile: $profilePath');

        // Wait for the video thumbnail on the profile grid.
        final videoTile = find.bySemanticsIdentifier('video_thumbnail_0');
        final foundTile = await waitForWidget(
          tester,
          videoTile,
          maxSeconds: 20,
        );
        expect(
          foundTile,
          isTrue,
          reason: 'User A profile should show video thumbnail before deletion',
        );
        logPhase('Video thumbnail visible on User A profile');

        // ── Phase 4: Delete User A's video server-side ──
        logPhase('── Phase 4: Delete video via kind 5 (server-side) ──');

        final deletionId = await publishDeleteEvent(
          eventId: video.eventId,
          kind: 34236,
          privateKey: userA.privateKey,
        );
        logPhase('Kind 5 delete event published: $deletionId');

        // Verify the relay has processed the deletion.
        final afterDelete = await queryRelay({
          'ids': [video.eventId],
        });
        expect(
          afterDelete,
          isEmpty,
          reason: 'Relay should filter deleted video from query results',
        );
        logPhase('Relay confirmed: video filtered after kind 5');

        // Wait for the REST API to also reflect the deletion.
        // ClickHouse needs time to process the kind 5 event.
        logPhase('Waiting for Funnelcake REST API to filter deleted video...');
        final apiFiltered = await waitForFunnelcakeVideoGone(userA.pubkey);
        expect(
          apiFiltered,
          isTrue,
          reason: 'Funnelcake REST API should filter deleted video within 30s',
        );
        logPhase('Funnelcake REST API confirmed: video filtered');

        // ── Phase 5: Navigate away, wait for staleness, navigate back ──
        logPhase('── Phase 5: Navigate away and back (refreshIfStale) ──');

        // Go back from User A's profile
        router.pop();
        await pumpUntilSettled(tester);

        // Wait on explore tab for the cached data to become stale.
        // Test overrides staleTtl to 3s so we only need a short wait.
        await tapBottomNavTab(tester, 'explore_tab');
        await pumpUntilSettled(tester);
        logPhase('On explore tab, waiting for cache staleness...');

        // Navigate back to User A's profile.
        // OtherProfileView.initState calls refreshIfStale() which triggers
        // a background refresh. The REST API now filters the deleted video.
        router.push(profilePath);
        await pumpUntilSettled(tester, maxSeconds: 15);
        logPhase('Back on User A profile');

        // Poll for the video to disappear (background refresh is async).
        var videoGone = find
            .bySemanticsIdentifier('video_thumbnail_0')
            .evaluate()
            .isEmpty;

        if (!videoGone) {
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 250));
            videoGone = find
                .bySemanticsIdentifier('video_thumbnail_0')
                .evaluate()
                .isEmpty;
            if (videoGone) break;
          }
        }

        expect(
          videoGone,
          isTrue,
          reason:
              'Deleted video should disappear after re-navigation because '
              'refreshIfStale() triggers a REST API re-fetch, and Funnelcake '
              'filters deleted videos via deleted_events_set.',
        );
        logPhase('Deleted video disappeared after re-navigation');

        // ── Cleanup ──
        ProfileFeed.staleTtl = const Duration(seconds: 30);
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
