// ABOUTME: Tests for app lifecycle provider (foreground/background state)
// ABOUTME: Verifies reactive lifecycle tracking and activeVideoIdProvider integration

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
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

        // URL context: explore index 1
        pageContextProvider.overrideWithValue(
          const AsyncValue.data(
            RouteContext(type: RouteType.explore, videoIndex: 1),
          ),
        ),

        // Feed (two items) — activeVideoIdProvider reads
        // videosForExploreRouteProvider for explore routes
        videosForExploreRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );

    // Create active subscription to force reactive chain evaluation
    container.listen(activeVideoIdProvider, (_, __) {}, fireImmediately: true);

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

        // URL context: explore index 0
        pageContextProvider.overrideWithValue(
          const AsyncValue.data(
            RouteContext(type: RouteType.explore, videoIndex: 0),
          ),
        ),

        // Feed (one item)
        videosForExploreRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );

    // Create active subscription to force reactive chain evaluation
    container.listen(activeVideoIdProvider, (_, __) {}, fireImmediately: true);

    await pumpEventQueue();

    // Should return null when backgrounded
    expect(container.read(activeVideoIdProvider), isNull);

    container.dispose();
  });
}

/// Test notifier for appForegroundProvider that starts with a custom value.
class _TestAppForegroundNotifier extends AppForeground {
  _TestAppForegroundNotifier(this._initialValue);

  final bool _initialValue;

  @override
  bool build() => _initialValue;
}
