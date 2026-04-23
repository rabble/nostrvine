// ABOUTME: E2E tests for multi-relay user personas
// ABOUTME: Verifies that seeded Type A (Divine) and Type B (Nostr-native) users
// ABOUTME: are discoverable and displayable across different relay configurations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:patrol/patrol.dart';

import '../helpers/constants.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';

/// Register a new user, verify via deep link, and wait for the main app.
///
/// Returns the test email used for registration.
Future<String> _registerAndVerify(WidgetTester tester) async {
  final testEmail =
      'persona-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
  const password = 'TestPass123!';

  await navigateToCreateAccount(tester);
  await registerNewUser(tester, testEmail, password);

  final foundVerifyScreen = await waitForText(
    tester,
    'Complete your registration',
  );
  expect(
    foundVerifyScreen,
    isTrue,
    reason: 'Should navigate to email verification screen',
  );

  final verifyToken = await getVerificationToken(testEmail);
  expect(verifyToken, isNotEmpty);

  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  final emailListener = container.read(emailVerificationListenerProvider);
  await emailListener.handleUri(
    Uri.parse('https://login.divine.video/verify-email?token=$verifyToken'),
  );

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

  final hasMainApp =
      find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
      find.text('Popular').evaluate().isNotEmpty ||
      find.text('Trending').evaluate().isNotEmpty;
  expect(
    hasMainApp,
    isTrue,
    reason: 'Should land on main app after verification',
  );

  return testEmail;
}

/// Verify the FunnelCake notifications route is reachable via the relay
/// proxy.
///
/// Probes `GET /api/users/{pubkey}/notifications?limit=1` through the
/// funnelcake-proxy and returns true if the response proves the route
/// exists. A generic `/api/videos` probe would not catch a regression
/// specific to the notifications routing path; probing the actual
/// notifications endpoint does.
///
/// Acceptable responses: 200 OK, 401 Unauthorized, 403 Forbidden. All of
/// these prove the route exists and is wired to the upstream notifications
/// handler — the test harness doesn't construct a NIP-98 auth header, so a
/// 401 from an auth-required endpoint is expected and fine.
///
/// Rejected: 404 (route missing from nginx/upstream), 5xx (upstream error).
/// Network failures return false as well.
///
/// Note: this calls the endpoint directly from the test harness, so it
/// does NOT exercise the app's own URL-resolution path.
Future<bool> _verifyFunnelcakeNotificationsRouteReachable(
  String pubkey,
) async {
  final status = await probeFunnelcakeNotificationsStatus(pubkey);
  // -1 = network/exception
  // 404 = route missing
  // 5xx = upstream failure
  return status == 200 || status == 401 || status == 403;
}

void main() {
  group('Persona E2E Tests', () {
    patrolTest(
      // The Type B profile lives on the external relay + indexer (see
      // `setupTypeBPresence`), but this test's video is published to
      // FunnelCake via `publishTestVideoEvent` with no `relayPort`. So the
      // scenario exercised is: profile resolves from external-via-indexer
      // while the video is served from FunnelCake — a mixed-relay render
      // path, not a pure external-only fetch.
      'browse Type B profile (external relay) with a FunnelCake-hosted video',
      timeout: const Timeout(Duration(minutes: 5)),
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Phase 1: Register and verify ──
        logPhase('── Persona Test 1: Register + verify ──');
        await _registerAndVerify(tester);

        // ── Phase 2: Seed a Type B user with relay presence ──
        logPhase('── Persona Test 1: Seeding Type B user ──');
        final typeBKey = generatePrivateKey();
        final typeBPubkey = getPublicKey(typeBKey);

        await setupTypeBPresence(
          privateKey: typeBKey,
          name: 'nostr-native-browse-test',
          displayName: 'Nostr Native Browse Test',
          about: 'E2E Type B profile discovery test',
        );

        // Publish a video on FunnelCake so the user is discoverable
        await publishTestVideoEvent(
          title: 'Type B Video Browse Test',
          privateKey: typeBKey,
        );

        // Wait for FunnelCake to index the video
        final videoIndexed = await waitForFunnelcakeVideo(typeBPubkey);
        expect(
          videoIndexed,
          isTrue,
          reason: 'FunnelCake should index the Type B video',
        );

        // ── Phase 3: Navigate to explore and find the video ──
        logPhase('── Persona Test 1: Navigate to explore ──');
        await tapBottomNavTab(tester, 'explore_tab');

        final foundNewTab = await waitForText(tester, 'New', maxSeconds: 10);
        expect(foundNewTab, isTrue, reason: 'Explore should show New tab');
        await tester.tap(find.text('New'));
        await tester.pump(const Duration(seconds: 1));

        // Wait for video thumbnails to appear
        final foundThumbnails = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'video_thumbnail_0',
          ),
          maxSeconds: 20,
        );
        expect(
          foundThumbnails,
          isTrue,
          reason: 'Explore grid should show video thumbnails',
        );

        // ── Phase 4: Navigate to Type B profile page ──
        logPhase('── Persona Test 1: Navigate to Type B profile ──');
        final typeBNpub = NostrKeyUtils.encodePubKey(typeBPubkey);
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.push(OtherProfileScreen.pathForNpub(typeBNpub));
        await pumpUntilSettled(tester);

        // Verify profile page rendered (ProfileGrid or loading state)
        // The profile page should at minimum load without crashing.
        // If profile resolution works, the display name should appear.
        final foundProfilePage = await waitForWidget(
          tester,
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.identifier == 'profile_tab',
              )
              .hitTestable(),
        );

        // Profile page is rendered if we can see the profile tab in
        // the background, OR if the profile view itself is shown.
        // Use a fallback: check for any profile-related widget.
        if (!foundProfilePage) {
          // Profile page should still be visible even without bottom nav
          // (OtherProfileScreen is pushed outside shell route).
          // Check for the back button or profile grid.
          final hasBackButton = find
              .bySemanticsLabel('Go back')
              .evaluate()
              .isNotEmpty;
          final hasProfileContent =
              find.text('Videos').evaluate().isNotEmpty ||
              find.text('Likes').evaluate().isNotEmpty ||
              find.text('Reposts').evaluate().isNotEmpty;
          expect(
            hasBackButton || hasProfileContent,
            isTrue,
            reason:
                'Type B profile page should load (back button or '
                'profile content tabs visible)',
          );
        }

        // The profile was published to the external relay and the kind 10002
        // relay-list event was published to the indexer relay. This assertion
        // is the core of the test: the app must resolve the author's relay
        // list from the indexer, then fetch the kind 0 from the external
        // relay, and render the display name. Without this expect(), the
        // test passes even if external-relay profile resolution is broken.
        final foundDisplayName = await waitForText(
          tester,
          'Nostr Native Browse Test',
          maxSeconds: 10,
        );
        expect(
          foundDisplayName,
          isTrue,
          reason:
              'Type B display name must resolve from the external relay via '
              'the indexer. Failure indicates outbox-routing or external '
              'relay profile fetch is broken.',
        );

        // Verify the video grid shows the published video
        final foundVideoInProfile = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'video_thumbnail_0',
          ),
        );
        expect(
          foundVideoInProfile,
          isTrue,
          reason: 'Type B profile should show video published to FunnelCake',
        );

        logPhase('Persona Test 1 complete');

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
    );

    patrolTest(
      'Type B profile shows videos from both FunnelCake and external relay',
      timeout: const Timeout(Duration(minutes: 5)),
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Phase 1: Register and verify ──
        logPhase('── Persona Test 2: Register + verify ──');
        await _registerAndVerify(tester);

        // ── Phase 2: Seed a Type B user with videos on both relays ──
        logPhase('── Persona Test 2: Seeding Type B user with videos ──');
        final typeBKey = generatePrivateKey();
        final typeBPubkey = getPublicKey(typeBKey);

        await setupTypeBPresence(
          privateKey: typeBKey,
          name: 'nostr-native-videos-test',
          displayName: 'Multi Video Test User',
        );

        // Publish 2 videos on FunnelCake
        await publishTestVideoEvent(
          title: 'Type B Video FC One',
          privateKey: typeBKey,
        );
        await publishTestVideoEvent(
          title: 'Type B Video FC Two',
          privateKey: typeBKey,
        );

        // Publish 1 video on external relay (mixed-relay scenario)
        await publishTestVideoEvent(
          title: 'Type B Video External',
          privateKey: typeBKey,
          relayPort: localExternalRelayPort,
        );

        // Wait until BOTH FunnelCake videos are indexed. A bare
        // waitForFunnelcakeVideo returns on the first indexed video and the
        // follow-up `>= 2` assertion would flake under indexer load.
        final bothVideosIndexed = await waitForFunnelcakeVideoCount(
          typeBPubkey,
          minCount: 2,
        );
        expect(
          bothVideosIndexed,
          isTrue,
          reason:
              "FunnelCake should index both of the Type B author's videos "
              'within the poll window.',
        );

        // Confirm the post-wait query still sees both videos.
        final fcVideos = await queryFunnelcakeVideos(typeBPubkey);
        expect(
          fcVideos.length,
          greaterThanOrEqualTo(2),
          reason: 'FunnelCake API should return at least 2 videos',
        );

        // Verify external relay also has the video
        final externalVideos = await queryRelay({
          'kinds': [34236],
          'authors': [typeBPubkey],
          'limit': 10,
        }, relayPort: localExternalRelayPort);
        expect(
          externalVideos,
          isNotEmpty,
          reason: 'External relay should have at least 1 video',
        );

        logPhase(
          'Seeded ${fcVideos.length} FunnelCake + '
          '${externalVideos.length} external videos',
        );

        // ── Phase 3: Navigate to profile and check video grid ──
        logPhase('── Persona Test 2: Navigate to profile ──');
        final typeBNpub = NostrKeyUtils.encodePubKey(typeBPubkey);
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        router.push(OtherProfileScreen.pathForNpub(typeBNpub));
        await pumpUntilSettled(tester);

        // Wait for the video grid to populate
        final foundGrid = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'video_thumbnail_0',
          ),
          maxSeconds: 20,
        );
        expect(
          foundGrid,
          isTrue,
          reason: 'Profile grid should show video thumbnails',
        );

        // The profile grid must show all three videos: 2 FunnelCake +
        // 1 external. Asserting on `video_thumbnail_2` (the third position)
        // is what binds the external-relay video to a UI assertion —
        // without it the earlier `video_thumbnail_0` / `_1` checks could be
        // satisfied entirely by the two FunnelCake videos, and a regression
        // that silently dropped the external relay from the fetch path
        // would still pass this test.
        final thumb1 = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'video_thumbnail_1',
        );
        expect(
          thumb1,
          findsOneWidget,
          reason:
              'Profile grid should show the second FunnelCake video '
              '(video_thumbnail_1).',
        );

        // Wait for the external-relay video to appear in the grid. This
        // explicitly verifies cross-relay video aggregation — the video
        // was published to the external relay only, so the app had to
        // follow the author's kind 10002 relay list and fetch from there.
        final foundExternalVideoInGrid = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.identifier == 'video_thumbnail_2',
          ),
          maxSeconds: 20,
        );
        expect(
          foundExternalVideoInGrid,
          isTrue,
          reason:
              'Profile grid should show the external-relay video '
              '(video_thumbnail_2). Missing third thumbnail indicates the '
              'app failed to aggregate from the external relay despite the '
              'kind 10002 relay list advertising it.',
        );

        logPhase('Persona Test 2 complete');

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
    );

    patrolTest(
      'notifications UI renders and FunnelCake API is routable',
      timeout: const Timeout(Duration(minutes: 5)),
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        final originalErrorBuilder = saveErrorWidgetBuilder();
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Phase 1: Register and verify ──
        logPhase('── Persona Test 3: Register + verify ──');
        final testEmail = await _registerAndVerify(tester);

        // ── Phase 2: Smoke-test FunnelCake notifications routing ──
        logPhase(
          '── Persona Test 3: Checking FunnelCake notifications routing ──',
        );

        // Get the logged-in user's pubkey from the database. The
        // notifications probe is keyed by pubkey, so we need the real one.
        final userPubkey = await getUserPubkeyByEmail(testEmail);
        expect(userPubkey, isNotNull, reason: 'Should find user in DB');

        // Verify the notifications endpoint itself is reachable through
        // the local stack's nginx proxy. Probing a generic videos endpoint
        // would pass even if notifications routing were broken; probing
        // `/api/users/{pubkey}/notifications` specifically catches
        // regressions in the notifications routing path. This is still a
        // direct HTTP call from the test harness — it does NOT exercise
        // the app's own URL resolution path.
        final notificationsRouteOk =
            await _verifyFunnelcakeNotificationsRouteReachable(userPubkey!);
        expect(
          notificationsRouteOk,
          isTrue,
          reason:
              'FunnelCake notifications route should be reachable via the '
              'relay proxy (accepting 200 / 401 / 403 — anything that proves '
              'the endpoint exists). A 404 or 5xx indicates the route is '
              'missing or the upstream is broken.',
        );

        // ── Phase 3: Navigate to inbox/notifications in the UI ──
        logPhase('── Persona Test 3: Navigate to notifications ──');
        await tapBottomNavTab(tester, 'inbox_tab');
        await tester.pump(const Duration(seconds: 3));

        // Verify the inbox screen rendered (Messages/Notifications tabs)
        final hasInboxTabs =
            find.text('Messages').evaluate().isNotEmpty ||
            find.text('Notifications').evaluate().isNotEmpty;
        expect(
          hasInboxTabs,
          isTrue,
          reason: 'Inbox screen should render Messages/Notifications toggle',
        );

        // Tap Notifications tab and verify it renders without error
        final notificationsTab = find.text('Notifications');
        expect(
          notificationsTab,
          findsOneWidget,
          reason: 'Notifications tab should be visible',
        );
        await tester.tap(notificationsTab);
        await pumpUntilSettled(tester);

        // A fresh user has no notifications, so the notifications tab body
        // must render the empty-state placeholder. Without this expect(),
        // an error widget or a blank screen would still pass as long as
        // the 'Notifications' label existed in the tab bar, and the test
        // would give almost no signal about the notifications surface.
        final hasEmptyState = await waitForText(
          tester,
          'No notifications yet',
          maxSeconds: 10,
        );
        expect(
          hasEmptyState,
          isTrue,
          reason:
              'Notifications tab body should render the empty-state '
              'placeholder for a fresh user. An error widget or blank body '
              'here indicates the notifications UI is broken even though '
              'the tab label renders.',
        );

        logPhase('Persona Test 3 complete');

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        restoreErrorHandler(originalOnError);
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
    );
  });
}
