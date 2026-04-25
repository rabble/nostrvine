// ABOUTME: Tests for overlay visibility provider (settings, modal tracking)
// ABOUTME: Verifies overlays pause video playback via activeVideoIdProvider integration

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group(OverlayVisibilityState, () {
    test('hasVisibleOverlay returns false when no overlays are open', () {
      const state = OverlayVisibilityState();
      expect(state.hasVisibleOverlay, isFalse);
    });

    test('hasVisibleOverlay returns true when page is open', () {
      const state = OverlayVisibilityState(isPageOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('hasVisibleOverlay returns true when bottom sheet is open', () {
      const state = OverlayVisibilityState(isBottomSheetOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('shouldRetainPlayer returns true for bottom sheet overlays', () {
      // Only bottom sheet - retain player
      const onlyBottomSheet = OverlayVisibilityState(isBottomSheetOpen: true);
      expect(onlyBottomSheet.shouldRetainPlayer, isTrue);

      // Bottom sheet with page - do NOT retain (page takes precedence)
      const withPage = OverlayVisibilityState(
        isBottomSheetOpen: true,
        isPageOpen: true,
      );
      expect(withPage.shouldRetainPlayer, isFalse);

      // No overlays - do NOT retain
      const noOverlays = OverlayVisibilityState();
      expect(noOverlays.shouldRetainPlayer, isFalse);

      // Only page - do NOT retain
      const onlyPage = OverlayVisibilityState(isPageOpen: true);
      expect(onlyPage.shouldRetainPlayer, isFalse);
    });

    test('copyWith creates correct copy', () {
      const state = OverlayVisibilityState();
      final withPage = state.copyWith(isPageOpen: true);

      expect(state.isPageOpen, isFalse);
      expect(withPage.isPageOpen, isTrue);
      expect(withPage.isBottomSheetOpen, isFalse);
    });
  });

  group('OverlayVisibility notifier', () {
    test('setPageOpen updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);

      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);
    });

    test('setBottomSheetOpen updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isFalse,
      );

      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(true);
      expect(
        container.read(overlayVisibilityProvider).isBottomSheetOpen,
        isTrue,
      );
    });
  });

  group('hasVisibleOverlayProvider', () {
    test('returns false when no overlays are open', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hasVisibleOverlayProvider), isFalse);
    });

    test('returns true when page is opened', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);
    });

    test('returns true when bottom sheet is opened', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);
    });

    test('page open/close cycle returns to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hasVisibleOverlayProvider), isFalse);

      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);

      container.read(overlayVisibilityProvider.notifier).setPageOpen(false);
      expect(container.read(hasVisibleOverlayProvider), isFalse);
    });

    test('bottom sheet open/close cycle returns to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hasVisibleOverlayProvider), isFalse);

      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);

      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(false);
      expect(container.read(hasVisibleOverlayProvider), isFalse);
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

    ProviderContainer createTestContainer(List<VideoEvent> videos) {
      return ProviderContainer(
        overrides: [
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.explore, videoIndex: 0),
            ),
          ),
          videosForExploreRouteProvider.overrideWith((ref) {
            return AsyncValue.data(
              VideoFeedState(videos: videos, hasMoreContent: false),
            );
          }),
        ],
      );
    }

    test(
      'activeVideoIdProvider returns video ID when no overlays are visible',
      () async {
        final container = createTestContainer(mockVideos);
        addTearDown(container.dispose);

        container.listen(
          activeVideoIdProvider,
          (_, _) {},
          fireImmediately: true,
        );

        await pumpEventQueue();

        expect(container.read(activeVideoIdProvider), 'v0');
      },
    );

    test('activeVideoIdProvider returns null when page is open', () async {
      final container = createTestContainer(mockVideos);
      addTearDown(container.dispose);

      container.listen(activeVideoIdProvider, (_, _) {}, fireImmediately: true);

      await pumpEventQueue();

      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);
    });

    test(
      'activeVideoIdProvider returns null when bottom sheet is open',
      () async {
        final container = createTestContainer(mockVideos);
        addTearDown(container.dispose);

        container.listen(
          activeVideoIdProvider,
          (_, _) {},
          fireImmediately: true,
        );

        await pumpEventQueue();

        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpen(true);
        expect(container.read(activeVideoIdProvider), isNull);
      },
    );

    test('video resumes when overlay is closed', () async {
      final container = createTestContainer(mockVideos);
      addTearDown(container.dispose);

      container.listen(activeVideoIdProvider, (_, _) {}, fireImmediately: true);

      await pumpEventQueue();

      expect(container.read(activeVideoIdProvider), 'v0');

      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);

      container.read(overlayVisibilityProvider.notifier).setPageOpen(false);
      expect(container.read(activeVideoIdProvider), 'v0');
    });
  });
}
