// ABOUTME: Tests for overlay visibility provider (drawer, settings, modal tracking)
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
  group('OverlayVisibilityState', () {
    test('hasVisibleOverlay returns false when no overlays are open', () {
      const state = OverlayVisibilityState();
      expect(state.hasVisibleOverlay, isFalse);
    });

    test('hasVisibleOverlay returns true when drawer is open', () {
      const state = OverlayVisibilityState(isDrawerOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('hasVisibleOverlay returns true when page is open', () {
      const state = OverlayVisibilityState(isPageOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test('hasVisibleOverlay returns true when bottom sheet is open', () {
      const state = OverlayVisibilityState(isBottomSheetOpen: true);
      expect(state.hasVisibleOverlay, isTrue);
    });

    test(
      'shouldRetainPlayer returns true for drawer and bottom sheet overlays',
      () {
        // Only bottom sheet - retain player
        const onlyBottomSheet = OverlayVisibilityState(isBottomSheetOpen: true);
        expect(onlyBottomSheet.shouldRetainPlayer, isTrue);

        // Only drawer - retain player
        const onlyDrawer = OverlayVisibilityState(isDrawerOpen: true);
        expect(onlyDrawer.shouldRetainPlayer, isTrue);

        // Bottom sheet with drawer - retain player
        const withDrawer = OverlayVisibilityState(
          isBottomSheetOpen: true,
          isDrawerOpen: true,
        );
        expect(withDrawer.shouldRetainPlayer, isTrue);

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
      },
    );

    test('copyWith creates correct copy', () {
      const state = OverlayVisibilityState();
      final withDrawer = state.copyWith(isDrawerOpen: true);

      expect(state.isDrawerOpen, isFalse);
      expect(withDrawer.isDrawerOpen, isTrue);
      expect(withDrawer.isPageOpen, isFalse);
      expect(withDrawer.isBottomSheetOpen, isFalse);
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
          .setBottomSheetOpen(
            true,
          );
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

    test('returns true when drawer is opened', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);
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
          .setBottomSheetOpen(
            true,
          );
      expect(container.read(hasVisibleOverlayProvider), isTrue);
    });

    test('page open/close cycle returns to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially no overlay
      expect(container.read(hasVisibleOverlayProvider), isFalse);

      // Open page (e.g., settings page)
      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(hasVisibleOverlayProvider), isTrue);

      // Close page
      container.read(overlayVisibilityProvider.notifier).setPageOpen(false);
      expect(container.read(hasVisibleOverlayProvider), isFalse);
    });

    test('bottom sheet open/close cycle returns to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially no overlay
      expect(container.read(hasVisibleOverlayProvider), isFalse);

      // Open bottom sheet (e.g., comments)
      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(
            true,
          );
      expect(container.read(hasVisibleOverlayProvider), isTrue);

      // Close bottom sheet
      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(
            false,
          );
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

    /// Creates a ProviderContainer with standard overrides for
    /// activeVideoIdProvider integration tests.
    ProviderContainer createTestContainer(List<VideoEvent> videos) {
      return ProviderContainer(
        overrides: [
          // appForegroundProvider defaults to true (Notifier-based)
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

        // Create active subscription to force reactive chain evaluation
        container.listen(
          activeVideoIdProvider,
          (_, _) {},
          fireImmediately: true,
        );

        await pumpEventQueue();

        // No overlays - video should play
        expect(container.read(activeVideoIdProvider), 'v0');
      },
    );

    test('activeVideoIdProvider returns null when drawer is open', () async {
      final container = createTestContainer(mockVideos);
      addTearDown(container.dispose);

      // Create active subscription to force reactive chain evaluation
      container.listen(activeVideoIdProvider, (_, _) {}, fireImmediately: true);

      await pumpEventQueue();

      // Open drawer - video should pause (return null)
      container.read(overlayVisibilityProvider.notifier).setDrawerOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);
    });

    test('activeVideoIdProvider returns null when page is open', () async {
      final container = createTestContainer(mockVideos);
      addTearDown(container.dispose);

      // Create active subscription to force reactive chain evaluation
      container.listen(activeVideoIdProvider, (_, _) {}, fireImmediately: true);

      await pumpEventQueue();

      // Open page - video should pause (return null)
      container.read(overlayVisibilityProvider.notifier).setPageOpen(true);
      expect(container.read(activeVideoIdProvider), isNull);
    });

    test(
      'activeVideoIdProvider returns null when bottom sheet is open',
      () async {
        final container = createTestContainer(mockVideos);
        addTearDown(container.dispose);

        // Create active subscription to force reactive chain evaluation
        container.listen(
          activeVideoIdProvider,
          (_, _) {},
          fireImmediately: true,
        );

        await pumpEventQueue();

        // Open bottom sheet - video should pause (return null)
        container
            .read(overlayVisibilityProvider.notifier)
            .setBottomSheetOpen(
              true,
            );
        expect(container.read(activeVideoIdProvider), isNull);
      },
    );

    test('video resumes when overlay is closed', () async {
      final container = createTestContainer(mockVideos);
      addTearDown(container.dispose);

      // Create active subscription to force reactive chain evaluation
      container.listen(activeVideoIdProvider, (_, _) {}, fireImmediately: true);

      await pumpEventQueue();

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
