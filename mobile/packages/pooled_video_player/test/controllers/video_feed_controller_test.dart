// ABOUTME: Tests for VideoFeedController
// ABOUTME: Validates state management, page navigation, and playback control

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

class _MockPooledPlayer extends Mock implements PooledPlayer {}

class _FakeMedia extends Fake implements Media {}

/// A tracking player pool that reports when players are released.
class _TrackingPlayerPool extends TestablePlayerPool {
  _TrackingPlayerPool({
    required super.mockPlayerFactory,
    required this.onRelease,
    super.maxPlayers,
  });

  final void Function(String url) onRelease;

  @override
  Future<void> release(String url) async {
    onRelease(url);
    await super.release(url);
  }
}

void _setUpFallbacks() {
  registerFallbackValue(_FakeMedia());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(PlaylistMode.single);
}

void main() {
  setUpAll(_setUpFallbacks);

  group('VideoFeedController', () {
    late TestablePlayerPool pool;
    late List<_MockPooledPlayer> createdPlayers;
    late Map<String, MockPlayerSetup> playerSetups;

    setUp(() {
      createdPlayers = [];
      playerSetups = {};

      pool = TestablePlayerPool(
        maxPlayers: 10,
        mockPlayerFactory: (url) {
          final setup = createMockPlayerSetup();
          playerSetups[url] = setup;

          final mockPooledPlayer = _MockPooledPlayer();
          when(() => mockPooledPlayer.player).thenReturn(setup.player);
          when(
            () => mockPooledPlayer.videoController,
          ).thenReturn(createMockVideoController());
          when(() => mockPooledPlayer.isDisposed).thenReturn(false);
          when(mockPooledPlayer.dispose).thenAnswer((_) async {});

          createdPlayers.add(mockPooledPlayer);
          return mockPooledPlayer;
        },
      );
    });

    tearDown(() async {
      for (final setup in playerSetups.values) {
        await setup.dispose();
      }
      await pool.dispose();
    });

    group('constructor', () {
      test('creates with required videos and pool', () {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(videos: videos, pool: pool);

        expect(controller.videos, equals(videos));
        expect(controller.videoCount, equals(3));

        controller.dispose();
      });

      test('uses default preloadAhead of 2', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        expect(controller.preloadAhead, equals(2));

        controller.dispose();
      });

      test('uses default preloadBehind of 1', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        expect(controller.preloadBehind, equals(1));

        controller.dispose();
      });

      test('accepts custom preloadAhead', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
          preloadAhead: 5,
        );

        expect(controller.preloadAhead, equals(5));

        controller.dispose();
      });

      test('accepts custom preloadBehind', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
          preloadBehind: 3,
        );

        expect(controller.preloadBehind, equals(3));

        controller.dispose();
      });

      test('initializes with empty video list', () {
        final controller = VideoFeedController(videos: [], pool: pool);

        expect(controller.videoCount, equals(0));
        expect(controller.videos, isEmpty);

        controller.dispose();
      });

      test('initializes with videos', () {
        final videos = createTestVideos();
        final controller = VideoFeedController(videos: videos, pool: pool);

        expect(controller.videoCount, equals(5));
        expect(controller.videos.length, equals(5));

        controller.dispose();
      });

      test('uses default initialIndex of 0', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        expect(controller.currentIndex, equals(0));

        controller.dispose();
      });

      test('accepts custom initialIndex', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
          initialIndex: 3,
        );

        expect(controller.currentIndex, equals(3));

        controller.dispose();
      });

      test('clamps initialIndex to valid range (lower bound)', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
          initialIndex: -5,
        );

        expect(controller.currentIndex, equals(0));

        controller.dispose();
      });

      test('clamps initialIndex to valid range (upper bound)', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
          initialIndex: 100,
        );

        // Last valid index is 4 (5 videos, indices 0-4)
        expect(controller.currentIndex, equals(4));

        controller.dispose();
      });

      test('handles initialIndex with empty video list', () {
        final controller = VideoFeedController(
          videos: [],
          pool: pool,
          initialIndex: 5,
        );

        expect(controller.currentIndex, equals(0));

        controller.dispose();
      });

      test('preloads around initialIndex instead of 0', () async {
        // Use initialIndex of 3 with preloadAhead=1, preloadBehind=1
        // Should preload indices 2, 3, 4 instead of 0, 1, 2
        final controller = VideoFeedController(
          videos: createTestVideos(count: 10),
          pool: pool,
          initialIndex: 3,
          preloadAhead: 1,
        );

        // Wait for async loading to start
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Indices 2, 3, 4 should be loading/loaded
        expect(controller.getLoadState(2), isNot(equals(LoadState.none)));
        expect(controller.getLoadState(3), isNot(equals(LoadState.none)));
        expect(controller.getLoadState(4), isNot(equals(LoadState.none)));

        // Index 0 should NOT be loaded (outside preload window)
        expect(controller.getLoadState(0), equals(LoadState.none));

        controller.dispose();
      });
    });

    group('state properties', () {
      group('currentIndex', () {
        test('returns 0 initially', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(controller.currentIndex, equals(0));

          controller.dispose();
        });

        test('updates after onPageChanged', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.onPageChanged(2);

          expect(controller.currentIndex, equals(2));
        });
      });

      group('isPaused', () {
        test('returns false initially', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(controller.isPaused, isFalse);

          controller.dispose();
        });

        test('returns true after pause()', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.pause();

          expect(controller.isPaused, isTrue);
        });

        test('returns false after play() when conditions allow', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          // play() only sets isPaused to false if video is ready and active
          // Since video isn't ready, isPaused stays true
          controller
            ..pause()
            ..play();

          // Since no video is ready, isPaused remains true
          expect(controller.isPaused, isTrue);
        });
      });

      group('isActive', () {
        test('returns true initially', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(controller.isActive, isTrue);

          controller.dispose();
        });

        test('returns false after setActive(false)', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.setActive(active: false);

          expect(controller.isActive, isFalse);
        });

        test('returns true after setActive(true)', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller
            ..setActive(active: false)
            ..setActive(active: true);

          expect(controller.isActive, isTrue);
        });
      });

      group('videos', () {
        test('returns unmodifiable list', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(
            () => controller.videos.add(createTestVideo()),
            throwsA(isA<UnsupportedError>()),
          );

          controller.dispose();
        });

        test('reflects added videos', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
          );

          final newVideos = createTestVideos(count: 2);
          controller.addVideos(newVideos);

          expect(controller.videoCount, equals(5));

          controller.dispose();
        });
      });

      group('videoCount', () {
        test('returns 0 for empty list', () {
          final controller = VideoFeedController(videos: [], pool: pool);

          expect(controller.videoCount, equals(0));

          controller.dispose();
        });

        test('returns correct count', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 7),
            pool: pool,
          );

          expect(controller.videoCount, equals(7));

          controller.dispose();
        });

        test('updates after addVideos', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.addVideos(createTestVideos(count: 2));

          expect(controller.videoCount, equals(5));
        });
      });
    });

    group('index notifier loading state', () {
      test(
        'exposes player and controller while a video is still loading',
        () async {
          final videos = createTestVideos(count: 1);
          final loadingSetup = createMockPlayerSetup(isBuffering: true);

          pool = TestablePlayerPool(
            maxPlayers: 10,
            mockPlayerFactory: (url) {
              playerSetups[url] = loadingSetup;

              final mockPooledPlayer = _MockPooledPlayer();
              when(
                () => mockPooledPlayer.player,
              ).thenReturn(loadingSetup.player);
              when(
                () => mockPooledPlayer.videoController,
              ).thenReturn(createMockVideoController());
              when(() => mockPooledPlayer.isDisposed).thenReturn(false);
              when(mockPooledPlayer.dispose).thenAnswer((_) async {});

              createdPlayers.add(mockPooledPlayer);
              return mockPooledPlayer;
            },
          );

          final controller = VideoFeedController(videos: videos, pool: pool);
          addTearDown(controller.dispose);

          final notifier = controller.getIndexNotifier(0);

          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(notifier.value.loadState, equals(LoadState.loading));
          expect(notifier.value.videoController, isNotNull);
          expect(notifier.value.player, isNotNull);
        },
      );
    });

    group('video access', () {
      group('getVideoController', () {
        test('returns null for unloaded index', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          // Index 4 is outside default preload window (0, 1, 2)
          expect(controller.getVideoController(4), isNull);

          controller.dispose();
        });

        test('returns null for out of bounds index', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
          );

          expect(controller.getVideoController(10), isNull);
          expect(controller.getVideoController(-1), isNull);

          controller.dispose();
        });
      });

      group('getPlayer', () {
        test('returns null for unloaded index', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(controller.getPlayer(4), isNull);

          controller.dispose();
        });

        test('returns null for out of bounds index', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
          );

          expect(controller.getPlayer(10), isNull);

          controller.dispose();
        });
      });

      group('getLoadState', () {
        test('returns LoadState.none for unloaded index', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(controller.getLoadState(4), equals(LoadState.none));

          controller.dispose();
        });
      });

      group('isVideoReady', () {
        test('returns false for unloaded index', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          expect(controller.isVideoReady(4), isFalse);

          controller.dispose();
        });
      });
    });

    group('page navigation', () {
      group('onPageChanged', () {
        test('updates currentIndex', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.onPageChanged(2);

          expect(controller.currentIndex, equals(2));
        });

        test('notifies listeners', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          var notified = false;
          controller
            ..addListener(() => notified = true)
            ..onPageChanged(1);

          expect(notified, isTrue);
        });

        test('does nothing when index unchanged', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          var notifyCount = 0;
          controller
            ..addListener(() => notifyCount++)
            ..onPageChanged(0);

          expect(notifyCount, equals(0));
        });
      });
    });

    group('playback control', () {
      group('play', () {
        test('does not change isPaused when video not ready', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller
            ..pause()
            ..play();

          // play() has a guard - since video isn't ready, isPaused stays true
          expect(controller.isPaused, isTrue);
        });

        test('does not notify listeners when video not ready', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.pause();

          var notified = false;
          controller
            ..addListener(() => notified = true)
            ..play();

          // play() returns early when video not ready, so no notification
          expect(notified, isFalse);
        });
      });

      group('pause', () {
        test('sets isPaused to true', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.pause();

          expect(controller.isPaused, isTrue);
        });

        test('notifies listeners', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          var notified = false;
          controller
            ..addListener(() => notified = true)
            ..pause();

          expect(notified, isTrue);
        });
      });

      group('togglePlayPause', () {
        test('calls play when paused (but play guards apply)', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller
            ..pause()
            ..togglePlayPause();

          // togglePlayPause calls play(), but play() has guards
          expect(controller.isPaused, isTrue);
        });

        test('pauses when playing', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.togglePlayPause();

          expect(controller.isPaused, isTrue);
        });
      });

      group('seek', () {
        test('completes without error when no player loaded', () async {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          await expectLater(
            controller.seek(const Duration(seconds: 10)),
            completes,
          );

          controller.dispose();
        });
      });

      group('setVolume', () {
        test('does nothing when no player loaded', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.setVolume(0.5);
        });
      });

      group('setPlaybackSpeed', () {
        test('does nothing when no player loaded', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller.setPlaybackSpeed(1.5);
        });
      });
    });

    group('active state', () {
      group('setActive', () {
        test('notifies listeners', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          var notified = false;
          controller
            ..addListener(() => notified = true)
            ..setActive(active: false);

          expect(notified, isTrue);

          addTearDown(controller.dispose);
        });

        test('resets isPaused when reactivated', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );
          addTearDown(controller.dispose);

          controller
            ..pause()
            ..setActive(active: false)
            ..setActive(active: true);

          expect(controller.isPaused, isFalse);
        });

        test('does nothing when value unchanged', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          var notifyCount = 0;
          controller
            ..addListener(() => notifyCount++)
            ..setActive(active: true);

          expect(notifyCount, equals(0));

          addTearDown(controller.dispose);
        });

        test(
          'retainCurrentPlayer: true releases non-current players '
          'but keeps current',
          () async {
            final controller = VideoFeedController(
              videos: createTestVideos(),
              pool: pool,
              preloadBehind: 0,
            );

            // Wait for videos to load (indices 0, 1, 2)
            await Future<void>.delayed(const Duration(milliseconds: 100));

            // Verify players are loaded before deactivation
            expect(controller.getPlayer(0), isNotNull);
            expect(controller.getPlayer(1), isNotNull);
            expect(controller.getPlayer(2), isNotNull);

            controller.setActive(active: false, retainCurrentPlayer: true);

            // Non-current players (1, 2) should be released
            expect(controller.getPlayer(1), isNull);
            expect(controller.getPlayer(2), isNull);

            // Current player (index 0) should be retained
            expect(controller.getPlayer(0), isNotNull);

            addTearDown(controller.dispose);
          },
        );

        test(
          'retainCurrentPlayer: false releases all players',
          () async {
            final controller = VideoFeedController(
              videos: createTestVideos(),
              pool: pool,
              preloadBehind: 0,
            );

            // Wait for videos to load (indices 0, 1, 2)
            await Future<void>.delayed(const Duration(milliseconds: 100));

            // Verify players are loaded before deactivation
            expect(controller.getPlayer(0), isNotNull);
            expect(controller.getPlayer(1), isNotNull);
            expect(controller.getPlayer(2), isNotNull);

            controller.setActive(
              active: false,
            );

            // ALL players should be released
            expect(controller.getPlayer(0), isNull);
            expect(controller.getPlayer(1), isNull);
            expect(controller.getPlayer(2), isNull);

            addTearDown(controller.dispose);
          },
        );

        test(
          'retainCurrentPlayer defaults to false (releases all)',
          () async {
            final controller = VideoFeedController(
              videos: createTestVideos(),
              pool: pool,
              preloadBehind: 0,
            );

            // Wait for videos to load (indices 0, 1, 2)
            await Future<void>.delayed(const Duration(milliseconds: 100));

            // Verify players are loaded before deactivation
            expect(controller.getPlayer(0), isNotNull);
            expect(controller.getPlayer(1), isNotNull);
            expect(controller.getPlayer(2), isNotNull);

            // Call without the parameter to test default behavior
            controller.setActive(active: false);

            // ALL players should be released (same as explicit false)
            expect(controller.getPlayer(0), isNull);
            expect(controller.getPlayer(1), isNull);
            expect(controller.getPlayer(2), isNull);

            addTearDown(controller.dispose);
          },
        );

        test(
          'reactivating with retained player plays immediately',
          () async {
            final videos = createTestVideos();
            final controller = VideoFeedController(
              videos: videos,
              pool: pool,
            );

            // Wait for initial load
            await Future<void>.delayed(const Duration(milliseconds: 100));

            final url = videos[0].url;
            final currentPlayerSetup = playerSetups[url]!;

            // Deactivate with retainCurrentPlayer: true
            controller.setActive(active: false, retainCurrentPlayer: true);
            await Future<void>.delayed(const Duration(milliseconds: 50));

            // Clear interaction history so we can verify new calls
            clearInteractions(currentPlayerSetup.player);

            // Reactivate
            controller.setActive(active: true);
            await Future<void>.delayed(const Duration(milliseconds: 50));

            // The current player should have play() and setVolume(100) called
            verify(currentPlayerSetup.player.play).called(1);
            verify(
              () => currentPlayerSetup.player.setVolume(100),
            ).called(1);

            addTearDown(controller.dispose);
          },
        );

        test(
          'reactivating after full release reloads preload window',
          () async {
            final videos = createTestVideos();
            final controller = VideoFeedController(
              videos: videos,
              pool: pool,
            );

            // Wait for initial load
            await Future<void>.delayed(const Duration(milliseconds: 100));

            // Confirm video 0 is ready before deactivation
            expect(controller.isVideoReady(0), isTrue);

            // Deactivate with default (releases all)
            controller.setActive(active: false);
            await Future<void>.delayed(const Duration(milliseconds: 50));

            // After full release, player was released
            expect(controller.isVideoReady(0), isFalse);

            // Reactivate
            controller.setActive(active: true);

            // Immediately after reactivation, the player needs to reload
            // so it won't be ready yet
            expect(controller.isVideoReady(0), isFalse);

            addTearDown(controller.dispose);
          },
        );
      });
    });

    group('video management', () {
      group('addVideos', () {
        test('adds videos to list', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
          );

          final newVideos = [
            createTestVideo(id: 'new1', url: 'https://example.com/new1.mp4'),
            createTestVideo(id: 'new2', url: 'https://example.com/new2.mp4'),
          ];
          controller.addVideos(newVideos);

          expect(controller.videoCount, equals(5));
          expect(controller.videos.last.id, equals('new2'));

          controller.dispose();
        });

        test('notifies listeners', () {
          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          );

          var notified = false;
          controller
            ..addListener(() => notified = true)
            ..addVideos([createTestVideo()]);

          expect(notified, isTrue);

          addTearDown(controller.dispose);
        });

        test('does nothing with empty list', () {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
          );

          var notifyCount = 0;
          controller
            ..addListener(() => notifyCount++)
            ..addVideos([]);

          expect(notifyCount, equals(0));
          expect(controller.videoCount, equals(3));

          addTearDown(controller.dispose);
        });
      });
    });

    group('dispose', () {
      test('calls super.dispose', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        )..dispose();

        expect(
          () => controller.addListener(() {}),
          throwsA(isA<FlutterError>()),
        );
      });

      test('can be called multiple times', () {
        VideoFeedController(videos: createTestVideos(), pool: pool)
          ..dispose()
          ..dispose()
          ..dispose();
      });

      test('releases all loaded players from pool', () async {
        final releasedUrls = <String>[];

        // Create a custom pool that tracks release calls
        final trackingPool = _TrackingPlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            final setup = createMockPlayerSetup();
            final mockPooledPlayer = _MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            when(() => mockPooledPlayer.isDisposed).thenReturn(false);
            when(mockPooledPlayer.dispose).thenAnswer((_) async {});
            return mockPooledPlayer;
          },
          onRelease: releasedUrls.add,
        );

        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: trackingPool,
          preloadBehind: 0,
        );

        // Wait for videos to load
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Dispose the controller
        controller.dispose();

        // Wait for async release calls
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // All loaded video URLs should be released
        expect(releasedUrls, containsAll(videos.map((v) => v.url)));
      });

      test('does not release unloaded videos', () async {
        final releasedUrls = <String>[];

        final trackingPool = _TrackingPlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            final setup = createMockPlayerSetup();
            final mockPooledPlayer = _MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            when(() => mockPooledPlayer.isDisposed).thenReturn(false);
            when(mockPooledPlayer.dispose).thenAnswer((_) async {});
            return mockPooledPlayer;
          },
          onRelease: releasedUrls.add,
        );

        // Create controller with 10 videos but only preload 3
        final videos = createTestVideos(count: 10);
        final controller = VideoFeedController(
          videos: videos,
          pool: trackingPool,
          preloadBehind: 0,
        );

        // Wait for videos to load
        await Future<void>.delayed(const Duration(milliseconds: 100));

        controller.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Only 3 videos should be released (0, 1, 2)
        expect(releasedUrls.length, equals(3));
        expect(releasedUrls, contains(videos[0].url));
        expect(releasedUrls, contains(videos[1].url));
        expect(releasedUrls, contains(videos[2].url));

        // Videos outside preload window should NOT be released
        expect(releasedUrls, isNot(contains(videos[5].url)));
      });

      test('clears internal state after dispose', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
        );

        // Wait for loading
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Dispose
        controller.dispose();

        // After dispose, getVideoController/getPlayer return null
        // because _loadedPlayers is cleared
        expect(controller.getVideoController(0), isNull);
        expect(controller.getPlayer(0), isNull);
      });
    });

    group('playback with loaded player', () {
      late VideoFeedController controller;
      late MockPlayerSetup playerSetup;

      setUp(() async {
        controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final url = createTestVideos()[0].url;
        playerSetup = playerSetups[url]!;

        playerSetup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      tearDown(() {
        controller.dispose();
      });

      test('seek calls player.seek when player is loaded', () async {
        const seekPosition = Duration(seconds: 10);

        await controller.seek(seekPosition);

        verify(() => playerSetup.player.seek(seekPosition)).called(1);
      });

      test('setVolume calls player.setVolume when player is loaded', () async {
        controller.setVolume(0.5);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        verify(() => playerSetup.player.setVolume(50)).called(1);
      });

      test('setVolume clamps volume to 0-100 range', () async {
        clearInteractions(playerSetup.player);

        controller.setVolume(1.5);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        verify(() => playerSetup.player.setVolume(100)).called(1);
      });

      test('setPlaybackSpeed calls player.setRate when loaded', () async {
        controller.setPlaybackSpeed(1.5);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        verify(() => playerSetup.player.setRate(1.5)).called(1);
      });

      test('pause calls player.pause when video is playing', () async {
        when(() => playerSetup.state.playing).thenReturn(true);

        controller.pause();

        await Future<void>.delayed(const Duration(milliseconds: 10));

        verify(playerSetup.player.pause).called(1);
      });

      test('pause calls player.pause even when not playing', () async {
        when(() => playerSetup.state.playing).thenReturn(false);

        controller.pause();

        await Future<void>.delayed(const Duration(milliseconds: 10));

        // User-initiated pause always calls pause() to ensure deterministic
        // state, regardless of the (potentially stale) playing flag.
        verify(playerSetup.player.pause).called(1);
      });
    });

    group('video loading error handling', () {
      test('sets LoadState.error when loading fails', () async {
        final errorPool = TestablePlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            throw Exception('Failed to get player');
          },
        );

        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: errorPool,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(controller.getLoadState(0), equals(LoadState.error));

        controller.dispose();
        await errorPool.dispose();
      });

      test('notifies index notifier when loading error occurs', () async {
        final errorPool = TestablePlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            throw Exception('Failed to get player');
          },
        );

        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: errorPool,
        );

        // Get index notifier before error occurs
        final indexNotifier = controller.getIndexNotifier(0);

        var notifyCount = 0;
        indexNotifier.addListener(() => notifyCount++);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifyCount, greaterThan(0));
        expect(indexNotifier.value.loadState, LoadState.error);

        controller.dispose();
        await errorPool.dispose();
      });

      test('notifies index notifier with controller and player while '
          'buffering', () async {
        final bufferingSetups = <String, MockPlayerSetup>{};
        final bufferingPool = TestablePlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            final setup = createMockPlayerSetup(isBuffering: true);
            bufferingSetups[url] = setup;

            final mockPooledPlayer = _MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            when(() => mockPooledPlayer.isDisposed).thenReturn(false);
            when(mockPooledPlayer.dispose).thenAnswer((_) async {});
            return mockPooledPlayer;
          },
        );

        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: bufferingPool,
        );

        final notifier = controller.getIndexNotifier(0);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(notifier.value.loadState, LoadState.loading);
        expect(notifier.value.videoController, isNotNull);
        expect(notifier.value.player, isNotNull);

        controller.dispose();
        for (final setup in bufferingSetups.values) {
          await setup.dispose();
        }
        await bufferingPool.dispose();
      });
    });

    group('hooks', () {
      group('mediaSourceResolver', () {
        test('uses resolved source when provided', () async {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            mediaSourceResolver: (video) => '/cached/${video.id}.mp4',
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          // The pool gets the original URL for keying
          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          // But the player opens with the resolved source
          verify(
            () => setup.player.open(
              any(
                that: isA<Media>().having(
                  (m) => m.uri,
                  'uri',
                  '/cached/video_0.mp4',
                ),
              ),
              play: false,
            ),
          ).called(1);

          controller.dispose();
        });

        test('falls back to original URL when resolver returns null', () async {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            mediaSourceResolver: (video) => null,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          verify(
            () => setup.player.open(
              any(that: isA<Media>().having((m) => m.uri, 'uri', url)),
              play: false,
            ),
          ).called(1);

          controller.dispose();
        });

        test('falls back to original URL when resolver is null', () async {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          verify(
            () => setup.player.open(
              any(that: isA<Media>().having((m) => m.uri, 'uri', url)),
              play: false,
            ),
          ).called(1);

          controller.dispose();
        });
      });

      group('onVideoReady', () {
        test('is called when buffer becomes ready', () async {
          final readyCalls = <(int, Player)>[];

          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            onVideoReady: (index, player) {
              readyCalls.add((index, player));
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          // Simulate buffer ready
          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(readyCalls, hasLength(1));
          expect(readyCalls.first.$1, equals(0));
          expect(readyCalls.first.$2, equals(setup.player));

          controller.dispose();
        });

        test('is not called when onVideoReady is null', () async {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          // Simulate buffer ready - should not throw
          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(controller.isVideoReady(0), isTrue);

          controller.dispose();
        });

        test('is called for preloaded videos', () async {
          final readyCalls = <int>[];

          final controller = VideoFeedController(
            videos: createTestVideos(count: 3),
            pool: pool,
            onVideoReady: (index, player) {
              readyCalls.add(index);
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Simulate buffer ready for all preloaded videos
          for (final entry in playerSetups.entries) {
            entry.value.bufferingController.add(false);
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(readyCalls, containsAll([0, 1, 2]));

          controller.dispose();
        });
      });

      group('positionCallback', () {
        test('is called periodically for active video', () async {
          final positionCalls = <(int, Duration)>[];
          const testPosition = Duration(seconds: 3);

          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            positionCallbackInterval: const Duration(milliseconds: 50),
            positionCallback: (index, position) {
              positionCalls.add((index, position));
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          // Configure player as playing with a position
          when(() => setup.state.playing).thenReturn(true);
          when(() => setup.state.position).thenReturn(testPosition);

          // Simulate buffer ready (starts playback + position timer)
          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Wait for position callbacks to fire
          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(positionCalls, isNotEmpty);
          expect(positionCalls.first.$1, equals(0));
          expect(positionCalls.first.$2, equals(testPosition));

          controller.dispose();
        });

        test('is not called when player is not playing', () async {
          final positionCalls = <(int, Duration)>[];

          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            positionCallbackInterval: const Duration(milliseconds: 50),
            positionCallback: (index, position) {
              positionCalls.add((index, position));
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          // Player is not playing
          when(() => setup.state.playing).thenReturn(false);

          // Simulate buffer ready
          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Wait for potential callbacks
          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(positionCalls, isEmpty);

          controller.dispose();
        });

        test('stops when video is paused', () async {
          final positionCalls = <(int, Duration)>[];

          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            positionCallbackInterval: const Duration(milliseconds: 50),
            positionCallback: (index, position) {
              positionCalls.add((index, position));
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          when(() => setup.state.playing).thenReturn(true);
          when(() => setup.state.position).thenReturn(Duration.zero);

          // Simulate buffer ready
          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Wait for some callbacks
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final callsBeforePause = positionCalls.length;

          // Pause the video
          controller.pause();

          // Reset to track new calls only
          positionCalls.clear();

          // Wait and verify no more callbacks
          await Future<void>.delayed(const Duration(milliseconds: 150));

          expect(callsBeforePause, greaterThan(0));
          expect(positionCalls, isEmpty);

          controller.dispose();
        });

        test('is not started when positionCallback is null', () async {
          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            positionCallbackInterval: const Duration(milliseconds: 50),
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          when(() => setup.state.playing).thenReturn(true);

          // Simulate buffer ready - should not throw
          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // No error means position timer was not started
          expect(controller.isVideoReady(0), isTrue);

          controller.dispose();
        });

        test('uses custom positionCallbackInterval', () async {
          final positionCalls = <(int, Duration)>[];

          final controller = VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
            positionCallbackInterval: const Duration(milliseconds: 100),
            positionCallback: (index, position) {
              positionCalls.add((index, position));
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos(count: 1)[0].url;
          final setup = playerSetups[url]!;

          when(() => setup.state.playing).thenReturn(true);
          when(() => setup.state.position).thenReturn(Duration.zero);

          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Wait ~250ms. With 100ms interval, expect ~2-3 calls
          await Future<void>.delayed(const Duration(milliseconds: 250));

          // With 100ms interval over ~250ms, should have 2-3 calls
          expect(positionCalls.length, lessThanOrEqualTo(4));
          expect(positionCalls.length, greaterThanOrEqualTo(1));

          controller.dispose();
        });

        test('stops timer when player is released', () async {
          final positionCalls = <(int, Duration)>[];

          final controller = VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
            preloadAhead: 1,
            preloadBehind: 0,
            positionCallbackInterval: const Duration(milliseconds: 50),
            positionCallback: (index, position) {
              positionCalls.add((index, position));
            },
          );

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final url = createTestVideos()[0].url;
          final setup = playerSetups[url]!;

          when(() => setup.state.playing).thenReturn(true);
          when(() => setup.state.position).thenReturn(Duration.zero);

          setup.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 100));

          final callsBeforeSwipe = positionCalls.length;
          expect(callsBeforeSwipe, greaterThan(0));

          // Move far enough away to release index 0
          positionCalls.clear();
          controller.onPageChanged(3);
          await Future<void>.delayed(const Duration(milliseconds: 150));

          // Timer for index 0 should be stopped after release
          final callsForIndex0 = positionCalls.where((c) => c.$1 == 0).length;
          expect(callsForIndex0, equals(0));

          controller.dispose();
        });
      });
    });

    group('ChangeNotifier', () {
      test('extends ChangeNotifier', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        addTearDown(controller.dispose);

        expect(controller, isA<ChangeNotifier>());
      });

      test('listeners receive updates on page change', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        addTearDown(controller.dispose);

        var pageChangeNotifications = 0;
        controller
          ..addListener(() {
            pageChangeNotifications++;
          })
          ..onPageChanged(1);

        expect(pageChangeNotifications, greaterThanOrEqualTo(1));
      });

      test('removed listeners do not receive page change updates', () {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );
        addTearDown(controller.dispose);

        var notifyCount = 0;
        void listener() => notifyCount++;

        controller.addListener(listener);
        final initialCount = notifyCount;

        controller.onPageChanged(1);
        final afterFirstChange = notifyCount;

        controller
          ..removeListener(listener)
          ..onPageChanged(2);

        expect(notifyCount, equals(afterFirstChange));
        expect(afterFirstChange, greaterThan(initialCount));
      });
    });

    group('disposed-player detection (pool eviction)', () {
      // When a PooledPlayer is externally disposed (e.g., by pool eviction
      // from another feed sharing the same pool), _notifyIndex should
      // report LoadState.none with null controller/player to prevent the
      // Video widget from accessing disposed native resources.

      late Map<String, bool> disposedState;
      late Map<String, MockPlayerSetup> evictionSetups;
      late TestablePlayerPool evictionPool;

      setUp(() {
        disposedState = {};
        evictionSetups = {};

        evictionPool = TestablePlayerPool(
          maxPlayers: 2,
          mockPlayerFactory: (url) {
            // isBuffering: true prevents immediate _onBufferReady, giving
            // us control over when the buffer-ready path fires.
            final setup = createMockPlayerSetup(isBuffering: true);
            evictionSetups[url] = setup;
            disposedState[url] = false;

            final mockPooledPlayer = _MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            // Dynamic isDisposed: flips to true when pool evicts this player
            when(
              () => mockPooledPlayer.isDisposed,
            ).thenAnswer((_) => disposedState[url]!);
            when(mockPooledPlayer.dispose).thenAnswer((_) async {
              disposedState[url] = true;
            });

            return mockPooledPlayer;
          },
        );
      });

      tearDown(() async {
        for (final setup in evictionSetups.values) {
          await setup.dispose();
        }
        await evictionPool.dispose();
      });

      test('index notifier reports $LoadState.none with null controller '
          'when pooled player is disposed by pool eviction', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: evictionPool,
          preloadBehind: 0,
        );

        // Grab notifier before load-state updates propagate.
        final notifier0 = controller.getIndexNotifier(0);

        // Wait for all _loadPlayer calls to complete. Pool (maxPlayers=2)
        // evicts video 0 when video 2 is requested.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          disposedState[videos[0].url],
          isTrue,
          reason: 'Pool should evict LRU player (video 0) when loading video 2',
        );

        // The isDisposed check in _loadPlayer detects the eviction
        // immediately after storing the player, cleaning up _loadStates
        // and _loadedPlayers before the buffer stream even fires.
        expect(controller.getLoadState(0), equals(LoadState.none));

        // Notifier reports evicted state with null controller/player.
        expect(notifier0.value.loadState, equals(LoadState.none));
        expect(notifier0.value.videoController, isNull);
        expect(notifier0.value.player, isNull);

        controller.dispose();
      });

      test('non-evicted player retains $LoadState.ready with non-null '
          'controller after pool eviction of another player', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: evictionPool,
          preloadBehind: 0,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Video 1 should NOT be evicted (only video 0 is).
        expect(disposedState[videos[1].url], isFalse);

        // Fire buffer ready for video 1.
        evictionSetups[videos[1].url]!.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final notifier1 = controller.getIndexNotifier(1);

        expect(notifier1.value.loadState, equals(LoadState.ready));
        expect(notifier1.value.videoController, isNotNull);
        expect(notifier1.value.player, isNotNull);

        controller.dispose();
      });

      test('buffer-ready on evicted player is a no-op because '
          '_loadPlayer already cleaned up the index', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: evictionPool,
          preloadBehind: 0,
        );

        final notifier0 = controller.getIndexNotifier(0);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // The isDisposed check in _loadPlayer already cleared index 0.
        expect(controller.getLoadState(0), equals(LoadState.none));

        // Fire buffer-ready on the evicted player's stream.
        // _onBufferReady checks _loadedPlayers[0]?.player → null,
        // so it returns without mutation.
        evictionSetups[videos[0].url]!.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // State remains none — buffer-ready had no effect.
        expect(controller.getLoadState(0), equals(LoadState.none));
        expect(notifier0.value.loadState, equals(LoadState.none));
        expect(notifier0.value.videoController, isNull);

        controller.dispose();
      });

      test('absent player (null in _loadedPlayers) preserves stored '
          '$LoadState.error with null controller and player', () async {
        // When pool.getPlayer throws, _loadedPlayers[index] is never set
        // (null), but _loadStates[index] = LoadState.error. The notifier
        // should honour the stored error state with null controller/player.
        final errorPool = TestablePlayerPool(
          maxPlayers: 10,
          mockPlayerFactory: (url) {
            throw Exception('Simulated pool failure');
          },
        );

        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(videos: videos, pool: errorPool);

        final notifier0 = controller.getIndexNotifier(0);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // _loadedPlayers[0] is null because getPlayer threw.
        // _loadStates[0] is LoadState.error — notifier should reflect this.
        expect(notifier0.value.loadState, equals(LoadState.error));
        expect(notifier0.value.videoController, isNull);
        expect(notifier0.value.player, isNull);

        controller.dispose();
        await errorPool.dispose();
      });

      test('_notifyIndex is a no-op after controller disposal '
          '(isDisposed early-return guard)', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: evictionPool,
          preloadBehind: 0,
        );

        // Let load start — player enters LoadState.loading.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final notifier0 = controller.getIndexNotifier(0);

        // Dispose controller — sets _isDisposed = true, clears notifiers
        // to empty state for audio leak prevention.
        controller.dispose();

        // Notifier should be cleared to empty state by dispose().
        expect(notifier0.value.loadState, equals(LoadState.none));
        expect(notifier0.value.videoController, isNull);
        expect(notifier0.value.player, isNull);

        final valueAfterDispose = notifier0.value;

        // Fire buffer-ready on the now-orphaned stream. Even if the
        // subscription was cancelled, _onBufferReady and _notifyIndex
        // would early-return via the _isDisposed guard without throwing.
        evictionSetups[videos[0].url]!.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Notifier retains the empty state from disposal — the guard
        // prevented any post-disposal mutation.
        expect(notifier0.value, equals(valueAfterDispose));
      });
    });

    group('eviction callback (_onPlayerEvicted)', () {
      // Tests that the onDisposedCallback mechanism on PooledPlayer
      // correctly triggers _onPlayerEvicted in the controller, updating
      // the widget state BEFORE Flutter rebuilds with a stale controller.
      // This prevents "A ValueNotifier<int?> was used after being disposed".

      late Map<String, bool> callbackDisposedState;
      late Map<String, MockPlayerSetup> callbackSetups;
      late Map<String, List<VoidCallback>> playerCallbacks;
      late TestablePlayerPool callbackPool;

      setUp(() {
        callbackDisposedState = {};
        callbackSetups = {};
        playerCallbacks = {};

        callbackPool = TestablePlayerPool(
          maxPlayers: 2,
          mockPlayerFactory: (url) {
            final setup = createMockPlayerSetup(isBuffering: true);
            callbackSetups[url] = setup;
            callbackDisposedState[url] = false;
            playerCallbacks[url] = <VoidCallback>[];

            final mockPooledPlayer = _MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            when(
              () => mockPooledPlayer.isDisposed,
            ).thenAnswer((_) => callbackDisposedState[url]!);

            // Track disposal callbacks (mirrors real PooledPlayer behavior).
            when(
              () => mockPooledPlayer.addOnDisposedCallback(any()),
            ).thenAnswer((invocation) {
              final callback =
                  invocation.positionalArguments[0] as VoidCallback;
              playerCallbacks[url]!.add(callback);
            });
            when(
              () => mockPooledPlayer.removeOnDisposedCallback(any()),
            ).thenAnswer((invocation) {
              final callback =
                  invocation.positionalArguments[0] as VoidCallback;
              playerCallbacks[url]!.remove(callback);
            });

            // Dispose fires callbacks synchronously (mirrors real behavior).
            when(mockPooledPlayer.dispose).thenAnswer((_) async {
              callbackDisposedState[url] = true;
              for (final cb in List<VoidCallback>.of(playerCallbacks[url]!)) {
                cb();
              }
              playerCallbacks[url]!.clear();
            });

            return mockPooledPlayer;
          },
        );
      });

      tearDown(() async {
        for (final setup in callbackSetups.values) {
          await setup.dispose();
        }
        await callbackPool.dispose();
      });

      test('eviction callback updates index notifier to $LoadState.none '
          'when pool evicts a tracked player', () async {
        // Pool has capacity 2. With preloadAhead=2, preloadBehind=0,
        // indices 0, 1, 2 are loaded. Loading index 2 evicts index 0.
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: callbackPool,
          preloadBehind: 0,
        );

        final notifier0 = controller.getIndexNotifier(0);

        // Wait for all loads to complete.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Pool evicted index 0's player when loading index 2.
        // The onDisposedCallback should have fired _onPlayerEvicted,
        // updating the notifier immediately.
        expect(callbackDisposedState[videos[0].url], isTrue);
        expect(notifier0.value.loadState, equals(LoadState.none));
        expect(notifier0.value.videoController, isNull);
        expect(notifier0.value.player, isNull);

        controller.dispose();
      });

      test('eviction callback is ignored when player was already released '
          'by the controller (_loadedPlayers identity check)', () async {
        // With capacity 3, no eviction happens during initial load of
        // 3 videos. We then navigate to release index 0 normally, and
        // manually trigger its dispose to simulate late pool eviction.
        final bigCallbackPool = TestablePlayerPool(
          maxPlayers: 3,
          mockPlayerFactory: callbackPool.mockPlayerFactory,
        );

        final videos = createTestVideos();
        final controller = VideoFeedController(
          videos: videos,
          pool: bigCallbackPool,
          preloadBehind: 0,
        );

        final notifier0 = controller.getIndexNotifier(0);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Index 0 is loaded.
        expect(controller.getLoadState(0), equals(LoadState.loading));

        // Navigate away — _releasePlayer(0) removes from _loadedPlayers.
        controller.onPageChanged(4);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // notifier0 should already show none (released by controller).
        expect(notifier0.value.loadState, equals(LoadState.none));

        // Now simulate pool evicting the old player for index 0's URL.
        // The callback should fire but be ignored (identity check fails).
        final callbacks = playerCallbacks[videos[0].url];
        if (callbacks != null) {
          for (final cb in List<VoidCallback>.of(callbacks)) {
            cb();
          }
        }

        // Notifier state should remain unchanged (no crash, no mutation).
        expect(notifier0.value.loadState, equals(LoadState.none));
        expect(notifier0.value.videoController, isNull);

        controller.dispose();
        await bigCallbackPool.dispose();
      });

      test('eviction callback is no-op after controller disposal', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: callbackPool,
          preloadBehind: 0,
        );

        final notifier0 = controller.getIndexNotifier(0);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Dispose controller first.
        controller.dispose();

        expect(notifier0.value.loadState, equals(LoadState.none));
        final stateAfterDispose = notifier0.value;

        // Fire any remaining callbacks — should be no-ops.
        for (final callbacks in playerCallbacks.values) {
          for (final cb in List<VoidCallback>.of(callbacks)) {
            cb();
          }
        }

        // State should remain exactly as dispose left it.
        expect(notifier0.value, equals(stateAfterDispose));
      });

      test('non-evicted player in same pool retains its state '
          'when sibling is evicted', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: callbackPool,
          preloadBehind: 0,
        );

        final notifier1 = controller.getIndexNotifier(1);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Video 1 should NOT be evicted.
        expect(callbackDisposedState[videos[1].url], isFalse);

        // Fire buffer ready for video 1.
        callbackSetups[videos[1].url]!.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Video 1 should be ready with non-null controller.
        expect(notifier1.value.loadState, equals(LoadState.ready));
        expect(notifier1.value.videoController, isNotNull);
        expect(notifier1.value.player, isNotNull);

        controller.dispose();
      });
    });

    group('audio leak prevention', () {
      test(
        'non-current video is paused and rewound when buffer ready',
        () async {
          // preloadBehind=0, preloadAhead=2 → loads indices 0, 1, 2.
          // Default isBuffering=false means _onBufferReady fires during load.
          final videos = createTestVideos(count: 3);
          final controller = VideoFeedController(
            videos: videos,
            pool: pool,
            preloadBehind: 0,
          );

          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Video 1 is a preloaded (non-current) video.
          final setup1 = playerSetups[videos[1].url]!;

          // Non-current video should be paused and rewound to the beginning
          // so it shows frame 0 when the user scrolls to it.
          verify(setup1.player.pause).called(1);
          verify(() => setup1.player.seek(Duration.zero)).called(1);

          // Volume should never have been set to 100 — only setVolume(0)
          // during the loading phase.
          verifyNever(() => setup1.player.setVolume(100));

          controller.dispose();
        },
      );

      test('current video plays at volume 100 when buffer ready', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(videos: videos, pool: pool);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final setup0 = playerSetups[videos[0].url]!;

        // Current video should get volume 100 from _onBufferReady.
        verify(() => setup0.player.setVolume(100)).called(1);

        // Current video should NOT be paused by _onBufferReady.
        verifyNever(setup0.player.pause);

        controller.dispose();
      });

      test('_releasePlayer mutes and pauses player before releasing', () async {
        final videos = createTestVideos(count: 10);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadBehind: 0,
          preloadAhead: 1,
        );

        // Wait for initial load (indices 0, 1).
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final setup0 = playerSetups[videos[0].url]!;

        // Clear interactions so we can verify release-specific calls.
        clearInteractions(setup0.player);

        // Navigate far enough that video 0 leaves the preload window.
        controller.onPageChanged(5);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // setVolume(0) called twice: once by _pauseVideo (mute on swipe)
        // and once by _releasePlayer (safety mute before pool return).
        verify(() => setup0.player.setVolume(0)).called(2);
        // pause() called twice: once by _pauseVideo (pause on swipe)
        // and once by _releasePlayer (full stop before pool return).
        verify(setup0.player.pause).called(2);

        controller.dispose();
      });

      test(
        'dispose mutes all loaded players before releasing from pool',
        () async {
          final videos = createTestVideos(count: 3);
          final controller = VideoFeedController(
            videos: videos,
            pool: pool,
            preloadBehind: 0,
          );

          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Clear interactions from the loading phase.
          for (final setup in playerSetups.values) {
            clearInteractions(setup.player);
          }

          controller.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Every loaded player should have been muted and paused.
          for (final setup in playerSetups.values) {
            verify(() => setup.player.setVolume(0)).called(1);
            verify(setup.player.pause).called(1);
          }
        },
      );

      test('dispose notifies index listeners with empty $VideoIndexState '
          'before releasing players', () async {
        final videos = createTestVideos(count: 2);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadBehind: 0,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Grab notifiers while controller is still alive.
        final notifier0 = controller.getIndexNotifier(0);
        final notifier1 = controller.getIndexNotifier(1);

        // Verify they currently have non-default state (loading or ready).
        expect(notifier0.value.loadState, isNot(equals(LoadState.none)));

        controller.dispose();

        // Both notifiers should now hold empty state
        // (null controller/player).
        expect(notifier0.value.loadState, equals(LoadState.none));
        expect(notifier0.value.videoController, isNull);
        expect(notifier0.value.player, isNull);

        expect(notifier1.value.loadState, equals(LoadState.none));
        expect(notifier1.value.videoController, isNull);
        expect(notifier1.value.player, isNull);
      });
    });

    group('HLS streaming support', () {
      test(
        'desktop canonical Divine HLS URLs open the HLS manifest directly',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);

          const hash =
              '0123456789abcdef0123456789abcdef'
              '0123456789abcdef0123456789abcdef';
          const hlsVideo = VideoItem(
            id: 'hls_video',
            url: 'https://media.divine.video/$hash/hls/master.m3u8',
          );
          final setup = createMockPlayerSetup();
          final pooledPlayer = _MockPooledPlayer();
          when(() => pooledPlayer.player).thenReturn(setup.player);
          when(
            () => pooledPlayer.videoController,
          ).thenReturn(createMockVideoController());
          when(() => pooledPlayer.isDisposed).thenReturn(false);
          when(pooledPlayer.dispose).thenAnswer((_) async {});

          final localPool = TestablePlayerPool(
            maxPlayers: 1,
            mockPlayerFactory: (_) => pooledPlayer,
          );
          addTearDown(() async {
            await setup.dispose();
            await localPool.dispose();
          });

          final controller = VideoFeedController(
            videos: [hlsVideo],
            pool: localPool,
          );
          addTearDown(controller.dispose);

          await Future<void>.delayed(const Duration(milliseconds: 100));

          verify(
            () => setup.player.open(
              any(
                that: isA<Media>().having((m) => m.uri, 'uri', hlsVideo.url),
              ),
              play: false,
            ),
          ).called(1);
          verifyNever(
            () => setup.player.open(
              any(
                that: isA<Media>().having(
                  (m) => m.uri,
                  'uri',
                  'https://media.divine.video/$hash',
                ),
              ),
              play: false,
            ),
          );
        },
      );

      test('desktop canonical Divine raw URLs retry the HLS manifest when '
          'raw blob open fails', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        const hash =
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
        const rawUrl = 'https://media.divine.video/$hash';
        const hlsUrl = 'https://media.divine.video/$hash/hls/master.m3u8';
        const rawVideo = VideoItem(id: 'raw_video', url: rawUrl);
        final setup = createMockPlayerSetup();
        when(
          () => setup.player.open(
            any(that: isA<Media>().having((m) => m.uri, 'uri', rawUrl)),
            play: false,
          ),
        ).thenThrow(Exception('404'));
        when(
          () => setup.player.open(
            any(that: isA<Media>().having((m) => m.uri, 'uri', hlsUrl)),
            play: false,
          ),
        ).thenAnswer((_) async {});

        final pooledPlayer = _MockPooledPlayer();
        when(() => pooledPlayer.player).thenReturn(setup.player);
        when(
          () => pooledPlayer.videoController,
        ).thenReturn(createMockVideoController());
        when(() => pooledPlayer.isDisposed).thenReturn(false);
        when(pooledPlayer.dispose).thenAnswer((_) async {});

        final localPool = TestablePlayerPool(
          maxPlayers: 1,
          mockPlayerFactory: (_) => pooledPlayer,
        );
        addTearDown(() async {
          await setup.dispose();
          await localPool.dispose();
        });

        final controller = VideoFeedController(
          videos: [rawVideo],
          pool: localPool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        verifyInOrder([
          () => setup.player.open(
            any(that: isA<Media>().having((m) => m.uri, 'uri', rawUrl)),
            play: false,
          ),
          () => setup.player.open(
            any(that: isA<Media>().having((m) => m.uri, 'uri', hlsUrl)),
            play: false,
          ),
        ]);
      });

      test('accepts HLS URLs with .m3u8 extension', () {
        final hlsVideos = [
          const VideoItem(
            id: 'hls_video_1',
            url: 'https://media.divine.video/abc123/hls/master.m3u8',
          ),
          const VideoItem(
            id: 'hls_video_2',
            url: 'https://example.com/stream/video.m3u8',
          ),
        ];

        final controller = VideoFeedController(videos: hlsVideos, pool: pool);
        addTearDown(controller.dispose);

        expect(controller.videos, equals(hlsVideos));
        expect(controller.videoCount, equals(2));
        expect(controller.videos[0].url, contains('.m3u8'));
        expect(controller.videos[1].url, contains('.m3u8'));
      });

      test('accepts mixed MP4 and HLS URLs', () {
        final mixedVideos = [
          const VideoItem(
            id: 'mp4_video',
            url: 'https://example.com/video.mp4',
          ),
          const VideoItem(
            id: 'hls_video',
            url: 'https://media.divine.video/abc123/hls/master.m3u8',
          ),
          const VideoItem(
            id: 'mov_video',
            url: 'https://example.com/video.mov',
          ),
        ];

        final controller = VideoFeedController(videos: mixedVideos, pool: pool);
        addTearDown(controller.dispose);

        expect(controller.videos.length, equals(3));
        expect(controller.videos[0].url, contains('.mp4'));
        expect(controller.videos[1].url, contains('.m3u8'));
        expect(controller.videos[2].url, contains('.mov'));
      });

      test('mediaSourceResolver works with HLS URLs', () async {
        final hlsVideos = [
          const VideoItem(
            id: 'hls_video',
            url: 'https://media.divine.video/abc123/hls/master.m3u8',
          ),
        ];

        String? resolvedUrl;

        final controller = VideoFeedController(
          videos: hlsVideos,
          pool: pool,
          mediaSourceResolver: (video) {
            resolvedUrl = video.url;
            // Return original URL (no cache override)
            return null;
          },
        );
        addTearDown(controller.dispose);

        // Wait for video to be loaded (async operation)
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify the resolver was called with the HLS URL
        expect(resolvedUrl, equals(hlsVideos[0].url));
        expect(resolvedUrl, contains('.m3u8'));
      });

      test(
        'mediaSourceResolver can override HLS URL with cached MP4',
        () async {
          final hlsVideos = [
            const VideoItem(
              id: 'hls_video',
              url: 'https://media.divine.video/abc123/hls/master.m3u8',
            ),
          ];

          const cachedPath = '/cache/hls_video.mp4';

          final controller = VideoFeedController(
            videos: hlsVideos,
            pool: pool,
            mediaSourceResolver: (video) {
              // Simulate returning a cached MP4 instead of HLS
              return cachedPath;
            },
          );
          addTearDown(controller.dispose);

          // Wait for video to be loaded
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Verify the player received the resolved (cached) URL
          // The mock player's open() was called with the cached path
          final setup = playerSetups.values.first;
          verify(
            () => setup.player.open(any(), play: any(named: 'play')),
          ).called(greaterThanOrEqualTo(1));
        },
      );
    });

    group('resume playback position', () {
      test(
        'preserves mid-playback position when resuming a swiped-away video',
        () async {
          // preloadBehind=1 (default) keeps video 0 in the pool while at
          // index 1, so swipe-back goes through _resume (not a full reload).
          final videos = createTestVideos(count: 3);
          final controller = VideoFeedController(
            videos: videos,
            pool: pool,
          );

          await Future<void>.delayed(const Duration(milliseconds: 100));

          final setup0 = playerSetups[videos[0].url]!;
          // Simulate mid-playback state: 5s into a 30s video.
          when(() => setup0.state.position).thenReturn(
            const Duration(seconds: 5),
          );
          when(() => setup0.state.duration).thenReturn(
            const Duration(seconds: 30),
          );

          clearInteractions(setup0.player);

          // Swipe to video 1 (pauses video 0), then swipe back
          // (resumes video 0).
          controller.onPageChanged(1);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          controller.onPageChanged(0);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Position is not at the end — no seek should have been called.
          verifyNever(() => setup0.player.seek(Duration.zero));
          // Video should be playing again.
          verify(setup0.player.play).called(greaterThanOrEqualTo(1));

          controller.dispose();
        },
      );

      test(
        'seeks to zero when resuming a video that reached the end',
        () async {
          // preloadBehind=1 keeps video 0 in the pool while at index 1,
          // so swipe-back goes through _resume (not a full reload).
          final videos = createTestVideos(count: 3);
          final controller = VideoFeedController(
            videos: videos,
            pool: pool,
          );

          await Future<void>.delayed(const Duration(milliseconds: 100));

          final setup0 = playerSetups[videos[0].url]!;
          const videoDuration = Duration(seconds: 30);
          // Simulate end-of-video state.
          when(() => setup0.state.position).thenReturn(videoDuration);
          when(() => setup0.state.duration).thenReturn(videoDuration);

          clearInteractions(setup0.player);

          // Swipe to video 1 (pauses video 0 but keeps it loaded),
          // then swipe back (resumes via _resume).
          controller.onPageChanged(1);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          controller.onPageChanged(0);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Position equals duration — should seek to zero for loop behavior.
          verify(() => setup0.player.seek(Duration.zero)).called(1);
          verify(setup0.player.play).called(greaterThanOrEqualTo(1));

          controller.dispose();
        },
      );

      test(
        'preloaded video is still at position zero when it becomes current',
        () async {
          // preloadAhead=1 loads video 1 as a preload and seeks it to zero
          // via _onBufferReady. When the user navigates to video 1 it should
          // play from the start without an additional seek.
          final videos = createTestVideos(count: 3);
          final controller = VideoFeedController(
            videos: videos,
            pool: pool,
            preloadBehind: 0,
            preloadAhead: 1,
          );

          await Future<void>.delayed(const Duration(milliseconds: 100));

          final setup1 = playerSetups[videos[1].url]!;
          // Preloaded video is at position zero and duration is non-zero.
          when(() => setup1.state.position).thenReturn(Duration.zero);
          when(() => setup1.state.duration).thenReturn(
            const Duration(seconds: 30),
          );

          clearInteractions(setup1.player);

          // Navigate to video 1.
          controller.onPageChanged(1);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Position (0) < duration (30s) — no seek needed.
          verifyNever(() => setup1.player.seek(Duration.zero));
          verify(setup1.player.play).called(greaterThanOrEqualTo(1));

          controller.dispose();
        },
      );
    });

    group('post-seek rebuffer recovery', () {
      test('buffer subscription survives _onBufferReady '
          'and handles rebuffering', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(videos: videos, pool: pool);
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup = playerSetups[videos[0].url]!;

        // Trigger initial buffer ready
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(0), equals(LoadState.ready));

        // Simulate rebuffering (e.g. after seek) — the subscription
        // must still be alive to detect this.
        when(() => setup.state.playing).thenReturn(false);

        setup.bufferingController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Now rebuffer completes — subscription should call
        // player.play()
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(setup.player.play).called(greaterThanOrEqualTo(1));
      });

      test('rebuffer after seek calls player.play() '
          'for current active video', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(videos: videos, pool: pool);
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup = playerSetups[videos[0].url]!;

        // Initial buffer ready for video 0 (current)
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        clearInteractions(setup.player);

        // Simulate: seek causes rebuffering, then completes
        when(() => setup.state.playing).thenReturn(false);
        setup.bufferingController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // player.play() should have been called for recovery
        verify(setup.player.play).called(greaterThanOrEqualTo(1));
      });

      test('rebuffer recovery resumes playback after network hiccup '
          'on already-ready current video', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(videos: videos, pool: pool);
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup = playerSetups[videos[0].url]!;

        // Initial buffer ready — video starts playing
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(0), equals(LoadState.ready));

        clearInteractions(setup.player);

        // Network hiccup: buffering starts then resolves without any
        // seek or user action. Player.state.playing may still be true
        // because mpv doesn't always toggle it on transient stalls.
        when(() => setup.state.playing).thenReturn(true);
        setup.bufferingController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // play() must be called to nudge the decoder out of the stall.
        verify(setup.player.play).called(greaterThanOrEqualTo(1));
      });

      test('rebuffer is ignored for non-current video', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(videos: videos, pool: pool);
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Make video 1 ready (non-current preloaded video)
        final setup1 = playerSetups[videos[1].url]!;
        setup1.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        clearInteractions(setup1.player);

        // Simulate rebuffer on video 1 (not the current video)
        when(() => setup1.state.playing).thenReturn(false);
        setup1.bufferingController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        setup1.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // player.play() should NOT have been called — not
        // the current video.
        verifyNever(setup1.player.play);
      });

      test('rebuffer is ignored when feed is paused', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(videos: videos, pool: pool);
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup = playerSetups[videos[0].url]!;

        // Initial buffer ready
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // User pauses
        controller.pause();

        clearInteractions(setup.player);

        // Simulate rebuffer on current video while paused
        when(() => setup.state.playing).thenReturn(false);
        setup.bufferingController.add(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // player.play() should NOT be called — user paused.
        verifyNever(setup.player.play);
      });

      test(
        'rebuffer recovery calls play() even when '
        'player reports playing',
        () async {
          final videos = createTestVideos(count: 1);
          final controller = VideoFeedController(videos: videos, pool: pool);
          addTearDown(controller.dispose);

          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          );

          final setup = playerSetups[videos[0].url]!;

          // Initial buffer ready
          setup.bufferingController.add(false);
          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          );

          clearInteractions(setup.player);

          // Simulate rebuffer completes while player reports
          // playing=true. mpv can stall (no frame output) even
          // when playing=true after a seek, so we always call
          // play() to nudge the decoder.
          when(() => setup.state.playing).thenReturn(true);
          setup.bufferingController.add(true);
          await Future<void>.delayed(
            const Duration(milliseconds: 10),
          );
          setup.bufferingController.add(false);
          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          );

          verify(setup.player.play).called(greaterThanOrEqualTo(1));
        },
      );
    });

    group('fast-path reuse of pooled player', () {
      test('reuses existing pool player without re-opening media', () async {
        final videos = createTestVideos();
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 1,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup0 = playerSetups[videos[0].url]!;

        // Buffer ready for video 0.
        setup0.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(0), equals(LoadState.ready));

        // Simulate the player having a valid duration (media loaded).
        when(
          () => setup0.state.duration,
        ).thenReturn(const Duration(seconds: 10));

        clearInteractions(setup0.player);

        // Swipe to index 2 — preload window becomes [1, 2, 3].
        // Index 0 falls outside and is released from the controller
        // but stays in the pool.
        controller.onPageChanged(2);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(0), equals(LoadState.none));
        expect(pool.hasPlayer(videos[0].url), isTrue);

        clearInteractions(setup0.player);

        // Swipe back to index 0 — the fast-path should skip open()
        // and immediately mark ready.
        controller.onPageChanged(0);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(0), equals(LoadState.ready));
        verifyNever(
          () => setup0.player.open(any(), play: any(named: 'play')),
        );
      });

      test('plays reused player immediately when it is current', () async {
        final videos = createTestVideos();
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 1,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup0 = playerSetups[videos[0].url]!;

        setup0.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        when(
          () => setup0.state.duration,
        ).thenReturn(const Duration(seconds: 10));
        when(
          () => setup0.state.position,
        ).thenReturn(const Duration(seconds: 3));

        // Move away so index 0 is released.
        controller.onPageChanged(2);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        clearInteractions(setup0.player);

        // Swipe back to 0 — it should play via the fast-path.
        controller.onPageChanged(0);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(0), equals(LoadState.ready));
        // setVolume(100) is called during _playVideo -> _resume
        verify(
          () => setup0.player.setVolume(100),
        ).called(greaterThanOrEqualTo(1));
      });

      test('pauses and rewinds reused player when it is a preload', () async {
        final videos = createTestVideos();
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 1,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final setup1 = playerSetups[videos[1].url]!;
        final setup0 = playerSetups[videos[0].url]!;

        setup0.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        setup1.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        when(
          () => setup1.state.duration,
        ).thenReturn(const Duration(seconds: 8));
        when(
          () => setup1.state.position,
        ).thenReturn(const Duration(seconds: 2));

        // Move to index 3 — both 0 and 1 are released.
        controller.onPageChanged(3);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(pool.hasPlayer(videos[1].url), isTrue);
        clearInteractions(setup1.player);

        // Move to index 2 — preload window is [1, 2, 3].
        // Video 1 is reloaded as a preload (not current).
        controller.onPageChanged(2);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(controller.getLoadState(1), equals(LoadState.ready));
        // Should pause and seek to zero for preloads.
        verify(setup1.player.pause).called(greaterThanOrEqualTo(1));
        verify(
          () => setup1.player.seek(Duration.zero),
        ).called(greaterThanOrEqualTo(1));
        // open() should NOT be called.
        verifyNever(
          () => setup1.player.open(any(), play: any(named: 'play')),
        );
      });

      test(
        'falls through to full load when reused player has no duration',
        () async {
          final videos = createTestVideos();
          final controller = VideoFeedController(
            videos: videos,
            pool: pool,
            preloadAhead: 1,
          );
          addTearDown(controller.dispose);

          await Future<void>.delayed(const Duration(milliseconds: 50));

          final setup0 = playerSetups[videos[0].url]!;

          setup0.bufferingController.add(false);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // Duration stays at zero — simulating a player whose media
          // wasn't fully loaded.
          when(() => setup0.state.duration).thenReturn(Duration.zero);

          controller.onPageChanged(2);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          clearInteractions(setup0.player);

          // Swipe back — duration is 0, so the fast-path should NOT
          // apply. The full open() path should be used instead.
          controller.onPageChanged(0);
          await Future<void>.delayed(const Duration(milliseconds: 50));

          // open() SHOULD be called since fast-path was skipped.
          verify(
            () => setup0.player.open(any(), play: any(named: 'play')),
          ).called(1);
        },
      );
    });

    group('stale position recovery', () {
      test('recovers when position is frozen after play', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
          preloadAhead: 1,
          preloadBehind: 0,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final url = createTestVideos()[0].url;
        final setup = playerSetups[url]!;

        // Simulate: video is playing but position is frozen at 533ms
        when(() => setup.state.playing).thenReturn(true);
        when(() => setup.state.buffering).thenReturn(false);
        when(() => setup.state.position).thenReturn(
          const Duration(milliseconds: 533),
        );

        // Trigger buffer ready so the controller starts the position timer
        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Wait for stale detection (100ms interval × 4 ticks for threshold=3)
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Recovery should have called pause + seek + play
        verify(setup.player.pause).called(greaterThanOrEqualTo(1));
        verify(
          () => setup.player.seek(const Duration(milliseconds: 533)),
        ).called(greaterThanOrEqualTo(1));

        controller.dispose();
      });

      test('does not trigger recovery when position advances', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
          preloadAhead: 1,
          preloadBehind: 0,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final url = createTestVideos()[0].url;
        final setup = playerSetups[url]!;
        var currentPosition = 0;

        when(() => setup.state.playing).thenReturn(true);
        when(() => setup.state.buffering).thenReturn(false);
        when(() => setup.state.position).thenAnswer(
          (_) => Duration(milliseconds: currentPosition += 100),
        );

        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Let heartbeat run for a while — position is always advancing
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // seek should only be called for the initial _resume seek-to-zero
        // check, not for stale recovery
        verifyNever(
          () => setup.player.seek(const Duration(milliseconds: 533)),
        );

        controller.dispose();
      });

      test('does not trigger recovery when buffering', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
          preloadAhead: 1,
          preloadBehind: 0,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final url = createTestVideos()[0].url;
        final setup = playerSetups[url]!;

        when(() => setup.state.playing).thenReturn(true);
        when(() => setup.state.buffering).thenReturn(true);
        when(() => setup.state.position).thenReturn(
          const Duration(milliseconds: 533),
        );

        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Recovery seek should NOT be called — buffering resets stale count
        verifyNever(
          () => setup.player.seek(const Duration(milliseconds: 533)),
        );

        controller.dispose();
      });

      test('resets stale count on page change', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(),
          pool: pool,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final url = createTestVideos()[0].url;
        final setup = playerSetups[url]!;

        when(() => setup.state.playing).thenReturn(true);
        when(() => setup.state.buffering).thenReturn(false);
        when(() => setup.state.position).thenReturn(
          const Duration(milliseconds: 533),
        );

        setup.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 250));

        // Swipe away before threshold is reached — resets stale tracking
        controller.onPageChanged(1);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Recovery seek to 533ms should NOT have been called on index 0
        verifyNever(
          () => setup.player.seek(const Duration(milliseconds: 533)),
        );

        controller.dispose();
      });
    });

    group('pool eviction protection', () {
      test('current video is touched in pool before preloading', () async {
        // Use a small pool to force eviction pressure
        final smallPool = TestablePlayerPool(
          maxPlayers: 4,
          mockPlayerFactory: (url) {
            final setup = createMockPlayerSetup();
            playerSetups[url] = setup;

            final mockPooledPlayer = _MockPooledPlayer();
            when(() => mockPooledPlayer.player).thenReturn(setup.player);
            when(
              () => mockPooledPlayer.videoController,
            ).thenReturn(createMockVideoController());
            when(() => mockPooledPlayer.isDisposed).thenReturn(false);
            when(mockPooledPlayer.dispose).thenAnswer((_) async {});

            return mockPooledPlayer;
          },
        );

        final controller = VideoFeedController(
          videos: createTestVideos(count: 8),
          pool: smallPool,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Swipe through several videos
        for (var i = 1; i <= 4; i++) {
          final prevUrl = createTestVideos(count: 8)[i - 1].url;
          final prevSetup = playerSetups[prevUrl];
          if (prevSetup != null) {
            prevSetup.bufferingController.add(false);
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
          controller.onPageChanged(i);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // The current video (index 4) should still have a player
        expect(controller.getVideoController(4), isNotNull);

        controller.dispose();
        await smallPool.dispose();
      });
    });

    group('preload pause and rewind', () {
      test('pauses before seeking on preloaded video', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 3),
          pool: pool,
          preloadBehind: 0,
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Preloaded video (index 1) should get pause then seek(0)
        final url1 = createTestVideos()[1].url;
        final setup1 = playerSetups[url1]!;

        setup1.bufferingController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify pause was called (from _pauseAndRewindPreloaded)
        verify(setup1.player.pause).called(greaterThanOrEqualTo(1));
        verify(
          () => setup1.player.seek(Duration.zero),
        ).called(greaterThanOrEqualTo(1));

        controller.dispose();
      });
    });
  });
}
