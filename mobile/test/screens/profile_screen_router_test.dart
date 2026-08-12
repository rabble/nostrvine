// ABOUTME: Tests for router-driven ProfileScreen implementation
// ABOUTME: Verifies URL ↔ PageView synchronization for profile feeds

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';

import '../helpers/test_provider_overrides.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: c.read(goRouterProvider),
    ),
  );

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  final mockVideos = [
    VideoEvent(
      id: 'p0',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 0',
      timestamp: now,
      title: 'Profile 0',
      videoUrl: 'https://example.com/p0.mp4',
    ),
    VideoEvent(
      id: 'p1',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 1',
      timestamp: now,
      title: 'Profile 1',
      videoUrl: 'https://example.com/p1.mp4',
    ),
    VideoEvent(
      id: 'p2',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 2',
      timestamp: now,
      title: 'Profile 2',
      videoUrl: 'https://example.com/p2.mp4',
    ),
  ];

  testWidgets('PROFILE: URL ↔ PageView sync', (tester) async {
    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(videos: mockVideos, hasMoreContent: false),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 0));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreenRouter), findsOneWidget);

    // Verify first video shown
    expect(find.text('Profile 0/3'), findsOneWidget);

    // Navigate to index 1
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 1));
    await tester.pumpAndSettle();

    // Verify second video shown
    expect(find.text('Profile 1/3'), findsOneWidget);
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  testWidgets('PROFILE: Empty state shows when no videos', (tester) async {
    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return const AsyncValue.data(
            VideoFeedState(videos: [], hasMoreContent: false),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('No posts yet'), findsOneWidget);
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  testWidgets('PROFILE: Lifecycle pause → activeVideoId becomes null', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        appForegroundProvider.overrideWithValue(const AsyncValue.data(false)),
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(videos: mockVideos, hasMoreContent: false),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 1));
    await tester.pumpAndSettle();

    // When backgrounded, active video should be null
    expect(c.read(activeVideoIdProvider), isNull);
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  // A divine:///profile/<npub> or https://divine.video/profile/<npub> deep
  // link lands on this route with a one-entry stack. When that account has
  // blocked or muted the viewer the screen swaps to BlockedUserScreen, whose
  // app-bar back used to be a raw context.pop — GoError, dead caret.
  group('$BlockedUserScreen back affordance', () {
    const npub =
        'npub1424242424242424242424242424242424242424242424242424qamrcaj';

    testWidgets('back lands on the feed when there is nothing to pop', (
      tester,
    ) async {
      final blocklistRepository = _MockContentBlocklistRepository();
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(true);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);

      final profilePath = ProfileScreenRouter.pathForNpub(npub);
      final router = GoRouter(
        initialLocation: profilePath,
        routes: [
          GoRoute(
            path: VideoFeedPage.pathForIndex(0),
            builder: (_, _) => const Scaffold(body: Text('feed')),
          ),
          GoRoute(
            path: ProfileScreenRouter.pathWithNpub,
            builder: (_, _) => const ProfileScreenRouter(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            routerLocationStreamProvider.overrideWithValue(
              Stream.value(profilePath),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BlockedUserScreen), findsOneWidget);
      // Precondition: cold entry really does leave a one-entry stack, so a
      // raw context.pop() here would throw GoError.
      expect(router.canPop(), isFalse);

      await tester.tap(find.byType(DivineAppBarIconButton));
      await tester.pumpAndSettle();

      expect(find.text('feed'), findsOneWidget);
    });
  });
}
