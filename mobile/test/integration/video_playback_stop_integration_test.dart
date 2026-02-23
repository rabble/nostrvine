// ABOUTME: Integration test for video playback stopping behavior
// ABOUTME: Verifies videos stop on route changes and background

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group('Video Playback Stop Integration Tests', () {
    // Create mock video data
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockHomeVideos = [
      VideoEvent(
        id: 'home-video-0',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Home Video 0',
        timestamp: now,
        title: 'Home Video 0',
        videoUrl: 'https://example.com/home0.mp4',
      ),
      VideoEvent(
        id: 'home-video-1',
        pubkey: 'pubkey-2',
        createdAt: nowUnix,
        content: 'Home Video 1',
        timestamp: now,
        title: 'Home Video 1',
        videoUrl: 'https://example.com/home1.mp4',
      ),
    ];

    final mockExploreVideos = [
      VideoEvent(
        id: 'explore-video-0',
        pubkey: 'pubkey-3',
        createdAt: nowUnix,
        content: 'Explore Video 0',
        timestamp: now,
        title: 'Explore Video 0',
        videoUrl: 'https://example.com/explore0.mp4',
      ),
      VideoEvent(
        id: 'explore-video-1',
        pubkey: 'pubkey-4',
        createdAt: nowUnix,
        content: 'Explore Video 1',
        timestamp: now,
        title: 'Explore Video 1',
        videoUrl: 'https://example.com/explore1.mp4',
      ),
    ];

    test(
      'activeVideoId changes to null when navigating to grid mode',
      () async {
        // Verify that navigating from video view to grid stops video playback
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              );
            }),
            homeFeedProvider.overrideWith(() {
              return _TestHomeFeedNotifier(
                AsyncData(
                  VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
                ),
              );
            }),
            // appForegroundProvider defaults to true (Notifier-based)
          ],
        );

        // Track active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        container.listen(
          pageContextProvider,
          (_, __) {},
          fireImmediately: true,
        );

        // Start at home video 0
        locationController.add(HomeScreenRouter.pathForIndex(0));
        await pumpEventQueue();

        expect(container.read(activeVideoIdProvider), equals('home-video-0'));
        expect(activeVideoIds.last, equals('home-video-0'));

        // Navigate to explore grid (no index)
        locationController.add(ExploreScreen.path);
        await pumpEventQueue();

        // Active video should be null (grid mode)
        expect(container.read(activeVideoIdProvider), isNull);
        expect(activeVideoIds.last, isNull);

        locationController.close();
        container.dispose();
      },
    );

    test(
      'activeVideoId changes when navigating between different feeds',
      () async {
        // Verify that navigating from home to explore changes active video
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              );
            }),
            homeFeedProvider.overrideWith(() {
              return _TestHomeFeedNotifier(
                AsyncData(
                  VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
                ),
              );
            }),
            videosForExploreRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(
                  videos: mockExploreVideos,
                  hasMoreContent: false,
                ),
              );
            }),
            // appForegroundProvider defaults to true (Notifier-based)
          ],
        );

        // Track active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        container.listen(
          pageContextProvider,
          (_, __) {},
          fireImmediately: true,
        );

        // Start at home video 0
        locationController.add(HomeScreenRouter.pathForIndex(0));
        await pumpEventQueue();

        expect(container.read(activeVideoIdProvider), equals('home-video-0'));

        // Navigate to explore video 0
        locationController.add(ExploreScreen.pathForIndex(0));
        await pumpEventQueue();

        // Active video should change to explore-video-0
        expect(
          container.read(activeVideoIdProvider),
          equals('explore-video-0'),
        );
        expect(activeVideoIds, contains('explore-video-0'));

        // Verify home video is no longer active
        final isHomeVideoActive = container.read(
          isVideoActiveProvider('home-video-0'),
        );
        final isExploreVideoActive = container.read(
          isVideoActiveProvider('explore-video-0'),
        );

        expect(isHomeVideoActive, isFalse);
        expect(isExploreVideoActive, isTrue);

        locationController.close();
        container.dispose();
      },
    );

    test('activeVideoId becomes null when app backgrounds', () async {
      // Verify that backgrounding the app stops video playback
      final locationController = StreamController<String>();

      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => locationController.stream,
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
            );
          }),
          homeFeedProvider.overrideWith(() {
            return _TestHomeFeedNotifier(
              AsyncData(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              ),
            );
          }),
          // appForegroundProvider defaults to true (Notifier-based)
        ],
      );

      // Track active video changes
      final activeVideoIds = <String?>[];
      container.listen(activeVideoIdProvider, (previous, next) {
        print('ACTIVE VIDEO: $previous → $next');
        activeVideoIds.add(next);
      }, fireImmediately: true);

      container.listen(pageContextProvider, (_, __) {}, fireImmediately: true);

      // Start with app in foreground (default) and navigate to video
      locationController.add(HomeScreenRouter.pathForIndex(0));
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), equals('home-video-0'));
      expect(activeVideoIds.last, equals('home-video-0'));

      // Background the app via the notifier
      container.read(appForegroundProvider.notifier).setForeground(false);
      await pumpEventQueue();

      // Active video should become null
      expect(container.read(activeVideoIdProvider), isNull);
      expect(activeVideoIds.last, isNull);

      // Foreground the app again
      container.read(appForegroundProvider.notifier).setForeground(true);
      await pumpEventQueue();

      // Video should become active again
      expect(container.read(activeVideoIdProvider), equals('home-video-0'));
      expect(activeVideoIds.last, equals('home-video-0'));

      locationController.close();
      container.dispose();
    });

    test('swiping between videos in same feed changes active video', () async {
      // Verify that swiping within home feed changes which video is active
      final locationController = StreamController<String>();

      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => locationController.stream,
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
            );
          }),
          homeFeedProvider.overrideWith(() {
            return _TestHomeFeedNotifier(
              AsyncData(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              ),
            );
          }),
          // appForegroundProvider defaults to true (Notifier-based)
        ],
      );

      // Track active video changes
      final activeVideoIds = <String?>[];
      container.listen(activeVideoIdProvider, (previous, next) {
        print('ACTIVE VIDEO: $previous → $next');
        activeVideoIds.add(next);
      }, fireImmediately: true);

      container.listen(pageContextProvider, (_, __) {}, fireImmediately: true);

      // Start at home video 0
      locationController.add(HomeScreenRouter.pathForIndex(0));
      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), equals('home-video-0'));
      expect(container.read(isVideoActiveProvider('home-video-0')), isTrue);
      expect(container.read(isVideoActiveProvider('home-video-1')), isFalse);

      // Swipe to home video 1
      locationController.add(HomeScreenRouter.pathForIndex(1));
      await pumpEventQueue();

      // Active video should change
      expect(container.read(activeVideoIdProvider), equals('home-video-1'));
      expect(container.read(isVideoActiveProvider('home-video-0')), isFalse);
      expect(container.read(isVideoActiveProvider('home-video-1')), isTrue);

      // Verify we saw both videos in the active video stream
      expect(
        activeVideoIds,
        containsAllInOrder(['home-video-0', 'home-video-1']),
      );

      locationController.close();
      container.dispose();
    });

    test(
      'activeVideoId becomes null when app is set to background state',
      () async {
        // Verify that setting foreground=false stops video playback
        final locationController = StreamController<String>();

        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => locationController.stream,
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
              return AsyncValue.data(
                VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
              );
            }),
            homeFeedProvider.overrideWith(() {
              return _TestHomeFeedNotifier(
                AsyncData(
                  VideoFeedState(videos: mockHomeVideos, hasMoreContent: false),
                ),
              );
            }),
            // Start with foreground=false to test background state
            appForegroundProvider.overrideWith(
              () => _TestAppForegroundNotifier(false),
            ),
          ],
        );

        // Track active video changes
        final activeVideoIds = <String?>[];
        container.listen(activeVideoIdProvider, (previous, next) {
          print('ACTIVE VIDEO: $previous → $next');
          activeVideoIds.add(next);
        }, fireImmediately: true);

        container.listen(
          pageContextProvider,
          (_, __) {},
          fireImmediately: true,
        );

        // Navigate to video while in background state
        locationController.add(HomeScreenRouter.pathForIndex(0));
        await pumpEventQueue();

        // Should be null because app is in background
        expect(container.read(activeVideoIdProvider), isNull);

        // Now set foreground state
        container.read(appForegroundProvider.notifier).setForeground(true);
        await pumpEventQueue();

        // Now video should be active
        expect(container.read(activeVideoIdProvider), equals('home-video-0'));

        locationController.close();
        container.dispose();
      },
    );
  });
}

/// Test notifier that returns a fixed state for homeFeedProvider overrides.
class _TestHomeFeedNotifier extends HomeFeed {
  _TestHomeFeedNotifier(this._state);

  final AsyncValue<VideoFeedState> _state;

  @override
  Future<VideoFeedState> build() async {
    return _state.when(
      data: (data) => data,
      loading: () => VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
        error: null,
        lastUpdated: null,
      ),
      error: (e, s) => throw e,
    );
  }
}

/// Test notifier for appForegroundProvider that starts with a custom value.
class _TestAppForegroundNotifier extends AppForeground {
  _TestAppForegroundNotifier(this._initialValue);

  final bool _initialValue;

  @override
  bool build() => _initialValue;
}
