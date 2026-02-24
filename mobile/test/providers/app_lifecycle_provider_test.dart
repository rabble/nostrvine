// ABOUTME: Tests for app lifecycle provider (foreground/background state)
// ABOUTME: Verifies reactive lifecycle tracking and activeVideoIdProvider integration

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  test('activeVideoIdProvider returns video ID when in foreground', () async {
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockVideos = [
      VideoEvent(
        id: 'v0',
        pubkey: 'pubkey-0',
        createdAt: nowUnix,
        content: 'Video 0',
        timestamp: now,
        title: 'Video 0',
        videoUrl: 'https://example.com/v0.mp4',
      ),
      VideoEvent(
        id: 'v1',
        pubkey: 'pubkey-1',
        createdAt: nowUnix,
        content: 'Video 1',
        timestamp: now,
        title: 'Video 1',
        videoUrl: 'https://example.com/v1.mp4',
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        // appForegroundProvider defaults to true (Notifier-based)

        // URL context: home index 1
        pageContextProvider.overrideWithValue(
          const AsyncValue.data(
            RouteContext(type: RouteType.home, videoIndex: 1),
          ),
        ),

        // Feed (two items) — activeVideoIdProvider reads homeFeedProvider
        // directly for home routes
        videosForHomeRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
        homeFeedProvider.overrideWith(() {
          return _TestHomeFeedNotifier(
            AsyncData(
              VideoFeedState(
                videos: mockVideos,
                hasMoreContent: false,
                isLoadingMore: false,
              ),
            ),
          );
        }),
      ],
    );

    // Create active subscription to force reactive chain evaluation
    container.listen(activeVideoIdProvider, (_, __) {}, fireImmediately: true);

    // Allow async homeFeedProvider to resolve
    await pumpEventQueue();

    // Should return video at index 1
    expect(container.read(activeVideoIdProvider), 'v1');

    container.dispose();
  });

  test('activeVideoIdProvider returns null when backgrounded', () async {
    final now = DateTime.now();
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    final mockVideos = [
      VideoEvent(
        id: 'v0',
        pubkey: 'pubkey-0',
        createdAt: nowUnix,
        content: 'Video 0',
        timestamp: now,
        title: 'Video 0',
        videoUrl: 'https://example.com/v0.mp4',
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        // Foreground FALSE - backgrounded
        appForegroundProvider.overrideWith(
          () => _TestAppForegroundNotifier(false),
        ),

        // URL context: home index 0
        pageContextProvider.overrideWithValue(
          const AsyncValue.data(
            RouteContext(type: RouteType.home, videoIndex: 0),
          ),
        ),

        // Feed (one item)
        videosForHomeRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
        homeFeedProvider.overrideWith(() {
          return _TestHomeFeedNotifier(
            AsyncData(
              VideoFeedState(
                videos: mockVideos,
                hasMoreContent: false,
                isLoadingMore: false,
              ),
            ),
          );
        }),
      ],
    );

    // Create active subscription to force reactive chain evaluation
    container.listen(activeVideoIdProvider, (_, __) {}, fireImmediately: true);

    // Allow async homeFeedProvider to resolve
    await pumpEventQueue();

    // Should return null when backgrounded
    expect(container.read(activeVideoIdProvider), isNull);

    container.dispose();
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
