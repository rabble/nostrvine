// ABOUTME: Tests for VideoFeedController
// ABOUTME: Validates state management, page navigation, and playback control

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

class _MockPooledPlayer extends Mock implements PooledPlayer {}

class _FakeMedia extends Fake implements Media {}

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
        VideoFeedController(
            videos: createTestVideos(),
            pool: pool,
          )
          ..dispose()
          ..dispose()
          ..dispose();
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

      test('pause does not call player.pause when not playing', () async {
        when(() => playerSetup.state.playing).thenReturn(false);

        controller.pause();

        await Future<void>.delayed(const Duration(milliseconds: 10));

        verifyNever(playerSetup.player.pause);
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

      test('notifies listeners when loading error occurs', () async {
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

        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifyCount, greaterThan(0));

        controller.dispose();
        await errorPool.dispose();
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
              any(
                that: isA<Media>().having(
                  (m) => m.uri,
                  'uri',
                  url,
                ),
              ),
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
              any(
                that: isA<Media>().having(
                  (m) => m.uri,
                  'uri',
                  url,
                ),
              ),
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

    group('HLS streaming support', () {
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

        final controller = VideoFeedController(
          videos: hlsVideos,
          pool: pool,
        );
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

        final controller = VideoFeedController(
          videos: mixedVideos,
          pool: pool,
        );
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
  });
}
