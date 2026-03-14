// ABOUTME: E2E test reproducing bug #2163: other users see deleted videos
// ABOUTME: Proves that after a kind 5 delete event, other users' cached views
// ABOUTME: still show the video until they force-refresh (pull to refresh)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:openvine/main.dart' as app;
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
      'deleted video remains visible to other users until force-refresh',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();

        // ── Phase 1: Seed relay with User A's profile and video ──
        logPhase('── Phase 1: Seed User A profile + video on relay ──');

        // Create User A's identity and publish a profile + video event
        // BEFORE launching the app, so the data is available when User B
        // navigates to User A's profile.
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

        // Verify the video is queryable on the relay before proceeding.
        // ClickHouse may need a moment to make the event available for reads.
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

        // Confirm we're on the main app
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

        // Convert User A's hex pubkey to npub for the route
        final userANpub = Nip19.encodePubKey(userA.pubkey);
        final profilePath = OtherProfileScreen.pathForNpub(userANpub);

        // Use GoRouter to push to User A's profile
        final router = GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        );
        router.push(profilePath);
        await pumpUntilSettled(tester, maxSeconds: 5);
        logPhase('Pushed to User A profile: $profilePath');

        // Wait for the video thumbnail to appear on User A's profile grid.
        // ProfileVideosGrid assigns semantics id 'video_thumbnail_$index'.
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

        // Publish a kind 5 deletion event as User A.
        // This simulates User A deleting their video from their device.
        // User B's app has NO subscription for kind 5 events.
        final deletionId = await publishDeleteEvent(
          eventId: video.eventId,
          kind: 34236,
          privateKey: userA.privateKey,
        );
        logPhase('Kind 5 delete event published: $deletionId');

        // Verify the relay has processed the deletion — querying the
        // original video ID should return empty now.
        final afterDelete = await queryRelay({
          'ids': [video.eventId],
        });
        expect(
          afterDelete,
          isEmpty,
          reason: 'Relay should filter deleted video from query results',
        );
        logPhase('Relay confirmed: video filtered after kind 5');

        // ── Phase 5: Navigate away and back — video should STILL show ──
        logPhase('── Phase 5: Navigate away and back (no force refresh) ──');

        // Go back from User A's profile
        router.pop();
        await pumpUntilSettled(tester);

        // Navigate to a different tab to clear the UI state
        await tapBottomNavTab(tester, 'explore_tab');
        await pumpUntilSettled(tester);
        logPhase('On explore tab');

        // Navigate back to User A's profile
        router.push(profilePath);
        await pumpUntilSettled(tester, maxSeconds: 5);
        logPhase('Back on User A profile');

        // THE BUG: The video should STILL be visible because:
        // 1. ProfileFeedProvider is keepAlive — it cached the video list
        // 2. No kind 5 subscription exists to notify the app of deletion
        // 3. SQLite cache holds the event for 1 day
        final videoStillVisible = find
            .bySemanticsIdentifier('video_thumbnail_0')
            .evaluate()
            .isNotEmpty;

        // Give it a moment to load if the provider needs to re-fetch
        final stillShows =
            videoStillVisible ||
            await waitForWidget(tester, videoTile, maxSeconds: 10);

        expect(
          stillShows,
          isTrue,
          reason:
              'BUG REPRODUCTION: Deleted video should STILL be visible to '
              'other users after navigating away and back, because the app '
              'has no mechanism to learn about the deletion. '
              'ProfileFeedProvider is keepAlive and no kind 5 subscription '
              'exists.',
        );
        logPhase(
          'BUG CONFIRMED: Deleted video still visible after navigate away/back',
        );

        // ── Phase 6: Force refresh — video should disappear ──
        logPhase('── Phase 6: Force refresh (pull to refresh) ──');

        // Pull to refresh by flinging down on the profile grid.
        // ProfileVideosGrid uses a CustomScrollView, and the profile
        // screen wraps it in a RefreshIndicator or similar.
        // If pull-to-refresh isn't available, navigating to the profile
        // fresh (invalidating the provider) should also work.
        //
        // The profile_feed_provider.refresh() calls _refreshFromRestApi()
        // which re-fetches from funnelcake REST API. The REST API filters
        // deleted events via deleted_events_set.

        // Try flinging to trigger refresh
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.fling(scrollable.first, const Offset(0, 400), 1000);
          await pumpUntilSettled(tester, maxSeconds: 10);
          logPhase('Flung down to trigger refresh');
        }

        // Check if video is gone after refresh
        final videoGoneAfterRefresh = find
            .bySemanticsIdentifier('video_thumbnail_0')
            .evaluate()
            .isEmpty;

        if (videoGoneAfterRefresh) {
          logPhase('Video disappeared after pull-to-refresh (expected path)');
        } else {
          // If pull-to-refresh didn't work (no RefreshIndicator on other
          // profile), the video stays cached. This is ALSO part of the bug:
          // there's no way for the user to force-refresh another user's
          // profile to see updated content.
          logPhase(
            'Video STILL visible even after fling — no pull-to-refresh '
            'on other user profile. This is the full extent of the bug.',
          );
        }

        // Either way, the bug is reproduced: the deleted video was visible
        // to User B after User A deleted it and the relay confirmed deletion.

        // ── Cleanup ──
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
