// ABOUTME: Tests for router-driven ProfileScreen implementation
// ABOUTME: Verifies URL ↔ playback synchronization for profile feeds

import 'dart:async';

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
import 'package:openvine/providers/app_foreground_provider.dart';
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

const _npub = 'npub1424242424242424242424242424242424242424242424242424qamrcaj';
const _authorPubkeyHex =
    'aaaa552aaaa552aaaa552aaaa552aaaa552aaaa552aaaa552aaaa552aaaa552a';

void main() {
  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  VideoEvent video(String id) => VideoEvent(
    id: id,
    pubkey: _authorPubkeyHex,
    createdAt: nowUnix,
    content: 'Profile video $id',
    timestamp: now,
    title: id,
    videoUrl: 'https://example.com/$id.mp4',
  );

  final mockVideos = [
    video('profile-video-0'),
    video('profile-video-1'),
    video('profile-video-2'),
  ];

  // The URL is the source of truth for which profile video plays:
  // routerLocationStreamProvider -> pageContextProvider -> activeVideoIdProvider.
  // videosForProfileRouteProvider is the list that provider indexes into; the
  // grid/feed widgets get their own copy from ProfileFeedCubit.
  group('profile URL drives the active video', () {
    ProviderContainer profileContainer({
      required Stream<String> locations,
      required List<VideoEvent> videos,
    }) {
      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWithValue(locations),
          videosForProfileRouteProvider.overrideWithValue(
            AsyncValue.data(
              VideoFeedState(videos: videos, hasMoreContent: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Keep the location stream subscribed for the whole test; no widget
      // tree is mounted here to do it.
      container.listen(pageContextProvider, (_, _) {}, fireImmediately: true);
      container.listen(activeVideoIdProvider, (_, _) {}, fireImmediately: true);
      return container;
    }

    test('the index segment selects the matching video', () async {
      final locations = StreamController<String>();
      addTearDown(locations.close);
      final container = profileContainer(
        locations: locations.stream,
        videos: mockVideos,
      );

      locations.add(ProfileScreenRouter.pathForIndex(_npub, 0));
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), mockVideos[0].stableId);

      locations.add(ProfileScreenRouter.pathForIndex(_npub, 1));
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), mockVideos[1].stableId);
    });

    test('an empty profile feed leaves nothing playing', () async {
      final locations = StreamController<String>();
      addTearDown(locations.close);
      final container = profileContainer(
        locations: locations.stream,
        videos: const [],
      );

      locations.add(ProfileScreenRouter.pathForIndex(_npub, 0));
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), isNull);
    });

    test(
      'backgrounding clears the active video, resuming restores it',
      () async {
        final locations = StreamController<String>();
        addTearDown(locations.close);
        final container = profileContainer(
          locations: locations.stream,
          videos: mockVideos,
        );

        locations.add(ProfileScreenRouter.pathForIndex(_npub, 1));
        await pumpEventQueue();

        expect(container.read(activeVideoIdProvider), mockVideos[1].stableId);

        container.read(appForegroundProvider.notifier).setForeground(false);

        expect(container.read(activeVideoIdProvider), isNull);

        container.read(appForegroundProvider.notifier).setForeground(true);

        expect(container.read(activeVideoIdProvider), mockVideos[1].stableId);
      },
    );
  });

  // A divine:///profile/<npub> or https://divine.video/profile/<npub> deep
  // link lands on this route with a one-entry stack. When that account has
  // blocked or muted the viewer the screen swaps to BlockedUserScreen, whose
  // app-bar back used to be a raw context.pop — GoError, dead caret.
  group('$BlockedUserScreen back affordance', () {
    testWidgets('back lands on the feed when there is nothing to pop', (
      tester,
    ) async {
      final blocklistRepository = _MockContentBlocklistRepository();
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(true);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);

      final profilePath = ProfileScreenRouter.pathForNpub(_npub);
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
