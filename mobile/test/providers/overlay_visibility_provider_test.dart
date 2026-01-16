// ABOUTME: Tests for overlay visibility provider (drawer, settings, modal tracking)
// ABOUTME: Verifies overlays pause video playback via activeVideoIdProvider integration

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group('OverlayVisibilityState', () {
    test('hasVisibleOverlay returns false when no overlays are open', () {
      const state = OverlayVisibilityState();
      expect(state.hasVisibleOverlay, isFalse);
    });

    test('hasVisibleOverlay returns true when drawer is open', () {
      const state = OverlayVisibilityState(isDrawerOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('hasVisibleOverlay returns true when settings is open', () {
      const state = OverlayVisibilityState(isSettingsOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('hasVisibleOverlay returns true when modal is open', () {
      const state = OverlayVisibilityState(isModalOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('copyWith creates correct copy', () {
      const state = OverlayVisibilityState();
      final withDrawer = state.copyWith(isDrawerOpen: true);

      expect(state.isDrawerOpen, isFalse);
      expect(withDrawer.isDrawerOpen, isTrue);
      expect(withDrawer.isSettingsOpen, isFalse);
      expect(withDrawer.isModalOpen, isFalse);
    });
  });

  group('OverlayVisibility notifier', () {
    test('setDrawerOpen updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(overlayVisibilityProvider).isDrawerOpen, isFalse);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      expect(container.read(overlayVisibilityProvider).isDrawerOpen, isTrue);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
      expect(container.read(overlayVisibilityProvider).isDrawerOpen, isFalse);
    });

    test('setSettingsOpen updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(overlayVisibilityProvider).isSettingsOpen, isFalse);

      container.read(overlayVisibilityProvider.notifier).setSettingsOpen(true);
      expect(container.read(overlayVisibilityProvider).isSettingsOpen, isTrue);
    });

    test('setModalOpen updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(overlayVisibilityProvider).isModalOpen, isFalse);

      container.read(overlayVisibilityProvider.notifier).setModalOpen(true);
      expect(container.read(overlayVisibilityProvider).isModalOpen, isTrue);
    });
  });

  group('hasVisibleOverlayProvider', () {
    test('returns false when no overlays are open', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hasVisibleOverlayProvider), isFalse);
    });

    test('returns true when drawer is opened', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);
    });
  });

  group('activeVideoIdProvider integration', () {
    late List<VideoEvent> mockVideos;
    late int nowUnix;

    setUp(() {
      final now = DateTime.now();
      nowUnix = now.millisecondsSinceEpoch ~/ 1000;
      mockVideos = [
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
    });

    test(
      'activeVideoIdProvider returns video ID when no overlays are visible',
      () {
        final container = ProviderContainer(
          overrides: [
            appForegroundProvider.overrideWithValue(
              const AsyncValue.data(true),
            ),
            pageContextProvider.overrideWithValue(
              const AsyncValue.data(
                RouteContext(type: RouteType.home, videoIndex: 0),
              ),
            ),
            videosForHomeRouteProvider.overrideWith((ref) {
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
        addTearDown(container.dispose);

        // No overlays - video should play
        expect(container.read(activeVideoIdProvider), 'v0');
      },
    );

    test('activeVideoIdProvider returns null when drawer is open', () {
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.home, videoIndex: 0),
            ),
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
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
      addTearDown(container.dispose);

      // Open drawer - video should pause (return null)
      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);
    });

    test('activeVideoIdProvider returns null when settings is open', () {
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.home, videoIndex: 0),
            ),
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
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
      addTearDown(container.dispose);

      // Open settings - video should pause (return null)
      container.read(overlayVisibilityProvider.notifier).setSettingsOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);
    });

    test('activeVideoIdProvider returns null when modal is open', () {
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.home, videoIndex: 0),
            ),
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
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
      addTearDown(container.dispose);

      // Open modal - video should pause (return null)
      container.read(overlayVisibilityProvider.notifier).setModalOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);
    });

    test('video resumes when overlay is closed', () {
      final container = ProviderContainer(
        overrides: [
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.home, videoIndex: 0),
            ),
          ),
          videosForHomeRouteProvider.overrideWith((ref) {
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
      addTearDown(container.dispose);

      // Initially video plays
      expect(container.read(activeVideoIdProvider), 'v0');

      // Open drawer - video pauses
      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);

      // Close drawer - video resumes
      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(false);
      expect(container.read(activeVideoIdProvider), 'v0');
    });
  });
}
