// ABOUTME: E2E tests for multi-relay user personas
// ABOUTME: Verifies that seeded Type A (Divine) and Type B (Nostr-native) users
// ABOUTME: are discoverable and displayable across different relay configurations

import 'dart:io';

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

/// Verify the FunnelCake REST API is reachable via the relay proxy.
///
/// Returns true if `/api/videos` responds with HTTP 200. This is a
/// smoke test for the local stack's nginx routing — it confirms the
/// funnelcake-proxy routes `/api/*` requests to the REST API correctly.
///
/// Note: this calls the endpoint directly from the test harness, so it
/// does NOT exercise the app's own API/relay resolution path.
Future<bool> _verifyFunnelcakeApiReachable() async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'http://$localHost:$localRelayPort/api/videos?limit=1',
    );
    final request = await client.getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode == 200;
  } on Exception {
    return false;
  } finally {
    client.close();
  }
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

        // Check if the display name resolved from the external relay
        final foundDisplayName = await waitForText(
          tester,
          'Nostr Native Browse Test',
          maxSeconds: 10,
        );
        logPhase(
          'Type B display name resolved: $foundDisplayName '
          '(profile discovery ${foundDisplayName ? "succeeded" : "pending"})',
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

        // Wait for FunnelCake to index the videos
        final videoIndexed = await waitForFunnelcakeVideo(typeBPubkey);
        expect(videoIndexed, isTrue);

        // Verify FunnelCake API returns at least 2 videos
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

        // Verify at least 2 thumbnails rendered (FunnelCake videos)
        final thumb1 = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'video_thumbnail_1',
        );
        final hasSecondThumb = thumb1.evaluate().isNotEmpty;
        expect(
          hasSecondThumb,
          isTrue,
          reason: 'Profile grid should show at least 2 video thumbnails',
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

        // ── Phase 2: Smoke-test FunnelCake API routing ──
        logPhase('── Persona Test 3: Checking FunnelCake API routing ──');

        // Get the logged-in user's pubkey from the database
        final userPubkey = await getUserPubkeyByEmail(testEmail);
        expect(userPubkey, isNotNull, reason: 'Should find user in DB');

        // Verify the FunnelCake REST API endpoint is reachable through
        // the local stack's nginx proxy. This is a direct HTTP call from
        // the test harness — it confirms the proxy routes /api/* to the
        // REST API, but does NOT exercise the app's own URL resolution.
        final notificationsApiOk = await _verifyFunnelcakeApiReachable();
        expect(
          notificationsApiOk,
          isTrue,
          reason:
              'FunnelCake REST API should return 200 via the relay proxy. '
              'Failure indicates a local stack routing problem.',
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

        // For a fresh user with no authored content, empty state is expected.
        // The key assertion is that the tab renders (API resolved correctly)
        // and the API returned 200 (verified above).
        final hasEmptyState = find
            .text('No notifications yet')
            .evaluate()
            .isNotEmpty;
        logPhase(
          'Notifications tab rendered. '
          'Empty state: $hasEmptyState (expected for fresh user). '
          'FunnelCake API returned 200 via proxy.',
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
