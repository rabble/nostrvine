import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerTestFallbackValues);

  group('VideoFeedController', () {
    setUp(() async {
      await initializeTestPoolManager();
    });

    tearDown(() async {
      await cleanupPoolManager();
    });

    group('Constructor', () {
      test('creates with feedId and empty videos', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.feedId, 'test-feed');
        expect(controller.videoCount, 0);
      });

      test('registers with PlayerPoolManager', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(
          PlayerPoolManager.instance.registeredFeeds,
          contains(controller),
        );
      });

      test('accepts custom preloadAhead', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
          preloadAhead: 5,
        );
        addTearDown(controller.dispose);

        expect(controller, isNotNull);
      });

      test('accepts custom preloadBehind', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
          preloadBehind: 3,
        );
        addTearDown(controller.dispose);

        expect(controller, isNotNull);
      });
    });

    group('State Getters', () {
      test('currentIndex starts at 0', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.currentIndex, 0);
      });

      test('isPaused starts as false', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.isPaused, false);
      });

      test('scrollDirection starts as none', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.scrollDirection, ScrollDirection.none);
      });

      test('videos returns unmodifiable list', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(
          () => controller.videos.add(createTestVideo()),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('videoCount returns correct count', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.videoCount, 0);
      });
    });

    group('Video Controller Access', () {
      test('getVideoController returns null for invalid index', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.getVideoController(0), isNull);
      });

      test('getPlayer returns null for invalid index', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.getPlayer(0), isNull);
      });

      test('getPreloadState returns none for invalid index', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.getPreloadState(0), PreloadState.none);
      });

      test('isVideoReady returns false for invalid index', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.isVideoReady(0), false);
      });
    });

    group('Error Handling', () {
      test('getError returns null when no error', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.getError(0), isNull);
      });

      test('errors returns empty map initially', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.errors, isEmpty);
      });

      test('hasError returns false when no error', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.hasError(0), false);
      });

      test('clearError does not throw for index without error', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        // Should not throw
        controller.clearError(0);
      });

      test('clearAllErrors does not throw when no errors', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        // Should not throw
        controller.clearAllErrors();
      });
    });

    group('Playback Control', () {
      test('play does not throw without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        // Should not throw
        controller.play();
        expect(controller.isPaused, false);
      });

      test('pause does not throw without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        // Should not throw - but pause() only sets isPaused when there's a lease
        controller.pause();
      });

      test('togglePlayPause works without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.isPaused, false);
        controller.togglePlayPause();
        // Without lease, isPaused won't be set
      });

      test('setVolume does not throw without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        controller.setVolume(0.5);
      });

      test('setMute does not throw without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        controller.setMute(muted: true);
      });

      test('setPlaybackSpeed does not throw without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        controller.setPlaybackSpeed(1.5);
      });
    });

    group('Stream Access', () {
      test('currentPosition returns null without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.currentPosition, isNull);
      });

      test('duration returns null without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.duration, isNull);
      });

      test('buffered returns null without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.buffered, isNull);
      });

      test('positionStream returns null without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.positionStream, isNull);
      });

      test('playingStream returns null without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.playingStream, isNull);
      });

      test('bufferingStream returns null without lease', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.bufferingStream, isNull);
      });
    });

    group('Navigation', () {
      group('onPageChanged', () {
        test('updates currentIndex', () {
          final videos = createTestVideos(5);
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          // Add videos without triggering preloading
          controller.addVideos(videos);

          expect(controller.currentIndex, 0);
          controller.onPageChanged(2);
          expect(controller.currentIndex, 2);
        });

        test('detects forward scroll direction', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(3));
          controller.onPageChanged(1);

          expect(controller.scrollDirection, ScrollDirection.forward);
        });

        test('detects backward scroll direction', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(5));
          controller.onPageChanged(3);
          controller.onPageChanged(1);

          expect(controller.scrollDirection, ScrollDirection.backward);
        });

        test('notifies listeners', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(3));

          var notified = false;
          controller.addListener(() => notified = true);

          controller.onPageChanged(1);

          expect(notified, true);
        });
      });
    });

    group('Video Management', () {
      group('addVideos', () {
        test('appends videos to list', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          expect(controller.videoCount, 0);

          controller.addVideos(createTestVideos(3));

          expect(controller.videoCount, 3);
        });

        test('notifies listeners', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          var notified = false;
          controller.addListener(() => notified = true);

          controller.addVideos([createTestVideo()]);

          expect(notified, true);
        });

        test('no-op for empty list', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          var notified = false;
          controller.addListener(() => notified = true);

          controller.addVideos([]);

          expect(notified, false);
        });
      });

      group('addVideo', () {
        test('adds single video', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          expect(controller.videoCount, 0);

          controller.addVideo(createTestVideo(id: 'new-video'));

          expect(controller.videoCount, 1);
        });
      });

      group('removeVideo', () {
        test('removes video at index', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(5));
          expect(controller.videoCount, 5);

          controller.removeVideo(2);

          expect(controller.videoCount, 4);
        });

        test('notifies listeners', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(3));

          var notified = false;
          controller.addListener(() => notified = true);

          controller.removeVideo(0);

          expect(notified, true);
        });

        test('no-op for invalid index (negative)', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(3));

          controller.removeVideo(-1);

          expect(controller.videoCount, 3);
        });

        test('no-op for invalid index (out of bounds)', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(3));

          controller.removeVideo(100);

          expect(controller.videoCount, 3);
        });

        test('adjusts currentIndex when removing before current', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(5));
          controller.onPageChanged(3);
          expect(controller.currentIndex, 3);

          controller.removeVideo(1);

          expect(controller.currentIndex, 2);
        });
      });
    });

    group('Handoff API', () {
      group('extractPlayerForHandoff', () {
        test('returns null if not loaded', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );
          addTearDown(controller.dispose);

          final lease = controller.extractPlayerForHandoff(0);

          expect(lease, isNull);
        });
      });
    });

    group('Memory Pressure', () {
      test('onMemoryPressure does not throw', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        // Should not throw
        controller.onMemoryPressure();
      });

      test('isMemoryConstrained reflects pool manager state', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(
          controller.isMemoryConstrained,
          PlayerPoolManager.instance.isMemoryConstrained,
        );
      });
    });

    group('Lifecycle', () {
      group('dispose', () {
        test('unregisters from PlayerPoolManager', () {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );

          expect(
            PlayerPoolManager.instance.registeredFeeds,
            contains(controller),
          );

          controller.dispose();

          expect(
            PlayerPoolManager.instance.registeredFeeds,
            isNot(contains(controller)),
          );
        });
      });

      group('disposeAsync', () {
        test('unregisters from PlayerPoolManager', () async {
          final controller = VideoFeedController(
            feedId: 'test-feed',
            videos: const [],
          );

          expect(
            PlayerPoolManager.instance.registeredFeeds,
            contains(controller),
          );

          await controller.disposeAsync();

          expect(
            PlayerPoolManager.instance.registeredFeeds,
            isNot(contains(controller)),
          );
        });
      });
    });

    group('onPreloadError callback', () {
      test('callback is optional', () {
        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
        );
        addTearDown(controller.dispose);

        expect(controller.onPreloadError, isNull);
      });

      test('callback can be provided', () {
        void errorCallback(int index, VideoLoadError error) {}

        final controller = VideoFeedController(
          feedId: 'test-feed',
          videos: const [],
          onPreloadError: errorCallback,
        );
        addTearDown(controller.dispose);

        expect(controller.onPreloadError, errorCallback);
      });
    });
  });

  group('PreloadState enum', () {
    test('has all expected values', () {
      expect(PreloadState.values, hasLength(6));
      expect(PreloadState.values, contains(PreloadState.none));
      expect(PreloadState.values, contains(PreloadState.opening));
      expect(PreloadState.values, contains(PreloadState.buffering));
      expect(PreloadState.values, contains(PreloadState.ready));
      expect(PreloadState.values, contains(PreloadState.playing));
      expect(PreloadState.values, contains(PreloadState.error));
    });
  });

  group('ScrollDirection enum', () {
    test('has all expected values', () {
      expect(ScrollDirection.values, hasLength(3));
      expect(ScrollDirection.values, contains(ScrollDirection.none));
      expect(ScrollDirection.values, contains(ScrollDirection.forward));
      expect(ScrollDirection.values, contains(ScrollDirection.backward));
    });
  });
}
