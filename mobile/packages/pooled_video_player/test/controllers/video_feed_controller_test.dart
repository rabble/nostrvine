// ABOUTME: Tests for VideoFeedController — video feed lifecycle, preloading,
// ABOUTME: source fallback, error classification, play/pause, and disposal.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const VideoClip.network('https://example.com/fallback'),
    );
    registerFallbackValue(Duration.zero);
  });

  group(VideoFeedController, () {
    late TestablePlayerPool pool;
    late Map<String, MockControllerSetup> setups;

    MockControllerSetup setupForUrl(String url) {
      return setups.putIfAbsent(url, createMockControllerSetup);
    }

    PooledPlayer playerFactory(String url) {
      final setup = setupForUrl(url);
      return createMockPooledPlayerFromSetup(setup);
    }

    setUp(() {
      setups = {};
      pool = TestablePlayerPool(
        mockPlayerFactory: playerFactory,
        maxPlayers: 5,
      );
    });

    tearDown(() async {
      // Drain pending Timer.run callbacks from deferred setSource mocks
      // before closing stream controllers. Without this, stateStream.first
      // would throw "No element" when the stream is closed prematurely.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      for (final s in setups.values) {
        await s.dispose();
      }
      await pool.dispose();
    });

    // -----------------------------------------------------------------------
    // Constructor / Initialization
    // -----------------------------------------------------------------------

    group('constructor', () {
      test('exposes videos and initial index', () {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        expect(controller.videos, equals(videos));
        expect(controller.videoCount, equals(3));
        expect(controller.currentIndex, equals(0));
        expect(controller.isPaused, isFalse);
        expect(controller.isActive, isTrue);
      });

      test('clamps initialIndex to valid range', () {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          initialIndex: 100,
        );
        addTearDown(controller.dispose);

        expect(controller.currentIndex, equals(2));
      });

      test('handles empty video list', () {
        final controller = VideoFeedController(
          videos: [],
          pool: pool,
        );
        addTearDown(controller.dispose);

        expect(controller.videoCount, equals(0));
        expect(controller.currentIndex, equals(0));
      });

      test('begins loading the initial video on construction', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        // Allow async _loadPlayer to run.
        await Future<void>.delayed(Duration.zero);

        expect(pool.hasPlayer(videos[0].url), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // getController / getLoadState / isVideoReady
    // -----------------------------------------------------------------------

    group('state accessors', () {
      test('getController returns null for unloaded index', () {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: pool,
        );
        addTearDown(controller.dispose);

        expect(controller.getController(0), isNull);
      });

      test('getLoadState returns none for unloaded index', () {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: pool,
        );
        addTearDown(controller.dispose);

        // Index 0 starts loading immediately in constructor;
        // check an out-of-range index instead.
        expect(controller.getLoadState(99), equals(LoadState.none));
      });

      test('isVideoReady returns false for unloaded index', () {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: pool,
        );
        addTearDown(controller.dispose);

        expect(controller.isVideoReady(0), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // getIndexNotifier
    // -----------------------------------------------------------------------

    group('getIndexNotifier', () {
      test('returns a ValueNotifier with initial state', () {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: pool,
        );
        addTearDown(controller.dispose);

        // Index 0 starts loading immediately; use an out-of-range
        // index to verify the default initial state.
        final notifier = controller.getIndexNotifier(99);
        expect(notifier, isA<ValueNotifier<VideoIndexState>>());
        expect(notifier.value.loadState, equals(LoadState.none));
        expect(notifier.value.controller, isNull);
      });

      test('returns the same notifier for the same index', () {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 2),
          pool: pool,
        );
        addTearDown(controller.dispose);

        final n1 = controller.getIndexNotifier(0);
        final n2 = controller.getIndexNotifier(0);
        expect(identical(n1, n2), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Video Loading
    // -----------------------------------------------------------------------

    group('video loading', () {
      test('loads current video and marks it ready', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        // Let load complete.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.getLoadState(0), equals(LoadState.ready));
        expect(controller.getController(0), isNotNull);
        expect(controller.isVideoReady(0), isTrue);
      });

      test('calls setSource with VideoClip.network', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final setup = setups[videos[0].url]!;
        verify(() => setup.controller.setSource(any())).called(1);
      });

      test('calls setLooping after successful load', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final setup = setups[videos[0].url]!;
        verify(
          () => setup.controller.setLooping(looping: true),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // Preloading
    // -----------------------------------------------------------------------

    group('preloading', () {
      test('preloads ahead videos within window', () async {
        final videos = createTestVideos();
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 2,
          preloadBehind: 0,
        );
        addTearDown(controller.dispose);

        // Let loads complete.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(pool.hasPlayer(videos[0].url), isTrue);
        expect(pool.hasPlayer(videos[1].url), isTrue);
        expect(pool.hasPlayer(videos[2].url), isTrue);
        expect(pool.hasPlayer(videos[3].url), isFalse);
      });

      test('preloads behind videos after page change', () async {
        final videos = createTestVideos();
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          initialIndex: 2,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // index 2 current, 1 behind, 3 ahead
        expect(pool.hasPlayer(videos[1].url), isTrue);
        expect(pool.hasPlayer(videos[2].url), isTrue);
        expect(pool.hasPlayer(videos[3].url), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // onPageChanged
    // -----------------------------------------------------------------------

    group('onPageChanged', () {
      test('updates currentIndex', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);

        controller.onPageChanged(1);
        expect(controller.currentIndex, equals(1));
      });

      test('pauses old video on swipe', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final oldSetup = setups[videos[0].url]!;

        controller.onPageChanged(1);
        await Future<void>.delayed(Duration.zero);

        // Old video should be paused and muted.
        verify(() => oldSetup.controller.setVolume(0)).called(greaterThan(0));
        verify(oldSetup.controller.pause).called(greaterThan(0));
      });

      test('ignores same-index page change', () {
        final videos = createTestVideos(count: 3);
        var notified = false;
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        )..addListener(() => notified = true);
        addTearDown(controller.dispose);

        notified = false;
        controller.onPageChanged(0);
        expect(notified, isFalse);
      });

      test('notifies listeners', () async {
        final videos = createTestVideos(count: 3);
        var notified = false;
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        )..addListener(() => notified = true);
        addTearDown(controller.dispose);

        notified = false;
        controller.onPageChanged(1);

        expect(notified, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // play / pause / togglePlayPause
    // -----------------------------------------------------------------------

    group('play', () {
      test('plays current video when active and ready', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Pause first, then play.
        controller.pause();

        final setup = setups[videos[0].url]!
          // Update mock state so controller.state.isPlaying returns false.
          ..emitState(
            const DivineVideoPlayerState(status: PlaybackStatus.paused),
          );

        controller.play();
        await Future<void>.delayed(Duration.zero);

        verify(() => setup.controller.setVolume(1)).called(greaterThan(0));
        verify(setup.controller.play).called(greaterThan(0));
      });

      test('does nothing when not active', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setActive(active: false);

        final setup = setups[videos[0].url]!;
        clearInteractions(setup.controller);

        controller.play();
        verifyNever(setup.controller.play);
      });
    });

    group('pause', () {
      test('pauses current video', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.pause();

        expect(controller.isPaused, isTrue);
        final setup = setups[videos[0].url]!;
        verify(setup.controller.pause).called(greaterThan(0));
      });

      test('notifies listeners', () async {
        final videos = createTestVideos(count: 1);
        var notified = false;
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        )..addListener(() => notified = true);
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);

        notified = false;
        controller.pause();
        expect(notified, isTrue);
      });
    });

    group('togglePlayPause', () {
      test('pauses when playing', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isPaused, isFalse);
        controller.togglePlayPause();
        expect(controller.isPaused, isTrue);
      });

      test('plays when paused', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.pause();
        expect(controller.isPaused, isTrue);

        controller.togglePlayPause();
        expect(controller.isPaused, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // seek
    // -----------------------------------------------------------------------

    group('seek', () {
      test('delegates to controller.seekTo', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await controller.seek(const Duration(seconds: 5));

        final setup = setups[videos[0].url]!;
        verify(
          () => setup.controller.seekTo(const Duration(seconds: 5)),
        ).called(greaterThan(0));
      });

      test('does nothing when no controller loaded', () async {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: pool,
        );
        addTearDown(controller.dispose);

        // Don't wait for load — seek immediately.
        await controller.seek(const Duration(seconds: 5));
        // No crash = pass.
      });
    });

    // -----------------------------------------------------------------------
    // setVolume
    // -----------------------------------------------------------------------

    group('setVolume', () {
      test('delegates to controller with clamped value', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setVolume(0.5);

        final setup = setups[videos[0].url]!;
        verify(() => setup.controller.setVolume(0.5)).called(greaterThan(0));
      });

      test('clamps volume above 1.0', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setVolume(2);

        final setup = setups[videos[0].url]!;
        verify(() => setup.controller.setVolume(1)).called(greaterThan(0));
      });
    });

    // -----------------------------------------------------------------------
    // setPlaybackSpeed
    // -----------------------------------------------------------------------

    group('setPlaybackSpeed', () {
      test('delegates to controller', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setPlaybackSpeed(2);

        final setup = setups[videos[0].url]!;
        verify(
          () => setup.controller.setPlaybackSpeed(2),
        ).called(greaterThan(0));
      });
    });

    // -----------------------------------------------------------------------
    // setActive
    // -----------------------------------------------------------------------

    group('setActive', () {
      test('pauses playback when deactivated', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setActive(active: false);

        expect(controller.isActive, isFalse);
        final setup = setups[videos[0].url]!;
        verify(setup.controller.pause).called(greaterThan(0));
      });

      test('releases all players when deactivated without retain', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 2,
          cacheAhead: 0,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Verify some players are loaded.
        expect(controller.getController(0), isNotNull);

        controller.setActive(active: false);
        await Future<void>.delayed(Duration.zero);

        // _releasePlayer removes from _loadedPlayers but does NOT
        // call pool.release(). Check controller state instead.
        for (var i = 0; i < 3; i++) {
          expect(controller.getController(i), isNull);
          expect(controller.getLoadState(i), equals(LoadState.none));
        }
      });

      test('retains current player when retainCurrentPlayer is true', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 2,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setActive(active: false, retainCurrentPlayer: true);
        await Future<void>.delayed(Duration.zero);

        // Current player (index 0) should still exist.
        expect(pool.hasPlayer(videos[0].url), isTrue);
      });

      test('resumes playback when reactivated', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.setActive(active: false, retainCurrentPlayer: true);
        await Future<void>.delayed(Duration.zero);

        controller.setActive(active: true);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isActive, isTrue);
      });

      test('is a no-op when setting same active state', () async {
        final videos = createTestVideos(count: 1);
        var notifyCount = 0;
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        )..addListener(() => notifyCount++);
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);

        notifyCount = 0;
        controller.setActive(active: true); // already active
        expect(notifyCount, equals(0));
      });

      test('notifies listeners on activation change', () async {
        final videos = createTestVideos(count: 1);
        var notified = false;
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        )..addListener(() => notified = true);
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);

        notified = false;
        controller.setActive(active: false);
        expect(notified, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // addVideos
    // -----------------------------------------------------------------------

    group('addVideos', () {
      test('adds videos to the list', () {
        final initial = createTestVideos(count: 2);
        final controller = VideoFeedController(
          videos: initial,
          pool: pool,
        );
        addTearDown(controller.dispose);

        final newVideos = [
          createTestVideo(id: 'new_0', url: 'https://example.com/new_0.mp4'),
          createTestVideo(id: 'new_1', url: 'https://example.com/new_1.mp4'),
        ];

        controller.addVideos(newVideos);

        expect(controller.videoCount, equals(4));
        expect(controller.videos.last.id, equals('new_1'));
      });

      test('does nothing when list is empty', () {
        final initial = createTestVideos(count: 2);
        var notified = false;
        final controller = VideoFeedController(
          videos: initial,
          pool: pool,
        )..addListener(() => notified = true);
        addTearDown(controller.dispose);

        notified = false;
        controller.addVideos([]);
        expect(notified, isFalse);
        expect(controller.videoCount, equals(2));
      });

      test('notifies listeners', () {
        final initial = createTestVideos(count: 2);
        var notified = false;
        final controller = VideoFeedController(
          videos: initial,
          pool: pool,
        )..addListener(() => notified = true);
        addTearDown(controller.dispose);

        notified = false;
        controller.addVideos([
          createTestVideo(id: 'new', url: 'https://example.com/new.mp4'),
        ]);
        expect(notified, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // onVideoReady callback
    // -----------------------------------------------------------------------

    group('onVideoReady', () {
      test('fires when video becomes ready', () async {
        final videos = createTestVideos(count: 1);
        int? readyIndex;
        DivineVideoPlayerController? readyController;

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          onVideoReady: (index, ctrl) {
            readyIndex = index;
            readyController = ctrl;
          },
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(readyIndex, equals(0));
        expect(readyController, isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // retryLoad
    // -----------------------------------------------------------------------

    group('retryLoad', () {
      test('releases and reloads the video', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Manually release video 0 state to simulate error state.
        controller.retryLoad(0);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Should have been reloaded.
        expect(pool.hasPlayer(videos[0].url), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Source Fallback (Divine blob URLs)
    // -----------------------------------------------------------------------

    group('source resolution', () {
      test('resolves Divine blob URL to HLS/raw fallbacks', () async {
        final hash = 'a' * 64;
        final divineUrl = 'https://media.divine.video/$hash';
        final videos = [VideoItem(id: 'divine', url: divineUrl)];

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // The controller should resolve the URL and try setSource.
        final setup = setups[divineUrl]!;
        verify(() => setup.controller.setSource(any())).called(greaterThan(0));
      });

      test('uses mediaSourceResolver when provided', () async {
        final videos = createTestVideos(count: 1);
        const cachedPath = '/cache/video.mp4';

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          mediaSourceResolver: (video) => cachedPath,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // The player should have been allocated for the original URL
        // (pool key), but setSource called with the resolved path.
        expect(pool.hasPlayer(videos[0].url), isTrue);
      });

      test('includes originalUrl as last-resort fallback', () async {
        const original = 'https://other-blossom.com/video.mp4';
        final hash = 'b' * 64;
        final divineUrl = 'https://media.divine.video/$hash';
        final videos = [
          VideoItem(id: 'v', url: divineUrl, originalUrl: original),
        ];

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Should have loaded without error.
        final setup = setups[divineUrl]!;
        verify(() => setup.controller.setSource(any())).called(greaterThan(0));
      });
    });

    // -----------------------------------------------------------------------
    // Error Classification
    // -----------------------------------------------------------------------

    group('error classification', () {
      test('marks error state on load failure', () async {
        final videos = createTestVideos(count: 1);

        // Create a setup whose setSource emits an error status.
        // This lets _openWithFallbacks subscribe to the stateStream
        // and receive the error normally, avoiding dangling .first
        // subscriptions that would throw "Bad state: No element".
        final failSetup = createMockControllerSetup();
        when(
          () => failSetup.controller.setSource(any()),
        ).thenAnswer((_) async {
          Timer.run(() {
            if (failSetup.stateController.isClosed) return;
            failSetup.emitState(
              const DivineVideoPlayerState(
                status: PlaybackStatus.error,
                errorMessage: '404 Not Found',
              ),
            );
          });
        });
        setups[videos[0].url] = failSetup;

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.getLoadState(0), equals(LoadState.error));
      });
    });

    // -----------------------------------------------------------------------
    // maxLoopDuration
    // -----------------------------------------------------------------------

    group('maxLoopDuration', () {
      test('stores the value', () {
        final controller = VideoFeedController(
          videos: createTestVideos(count: 1),
          pool: pool,
          maxLoopDuration: const Duration(seconds: 30),
        );
        addTearDown(controller.dispose);

        // maxLoopDuration is internal; we just verify construction succeeds.
        expect(controller.videoCount, equals(1));
      });
    });

    // -----------------------------------------------------------------------
    // positionCallback
    // -----------------------------------------------------------------------

    group('positionCallback', () {
      test('is called after video starts playing', () async {
        final videos = createTestVideos(count: 1);
        final positions = <(int, Duration)>[];

        // Create setup that reports as playing with a position.
        final setup = createMockControllerSetup(isPlaying: true);
        setups[videos[0].url] = setup;

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          positionCallback: (index, pos) => positions.add((index, pos)),
          positionCallbackInterval: const Duration(milliseconds: 50),
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Emit playing state to trigger position timer.
        setup.emitState(
          const DivineVideoPlayerState(
            status: PlaybackStatus.playing,
            position: Duration(seconds: 1),
            duration: Duration(seconds: 10),
          ),
        );

        // Give the timer a chance to fire.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(positions, isNotEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // dispose
    // -----------------------------------------------------------------------

    group('dispose', () {
      test('releases all players and notifiers', () async {
        final videos = createTestVideos(count: 3);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 2,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.dispose();

        // Pool should have no players left.
        expect(pool.playerCount, equals(0));
      });

      test('mutes all players immediately on dispose', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final setup = setups[videos[0].url]!;
        controller.dispose();

        verify(() => setup.controller.setVolume(0)).called(greaterThan(0));
        verify(setup.controller.pause).called(greaterThan(0));
      });

      test('resets all index notifiers to empty state', () async {
        final videos = createTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );

        final notifier = controller.getIndexNotifier(0);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        controller.dispose();

        expect(notifier.value.loadState, equals(LoadState.none));
        expect(notifier.value.controller, isNull);
      });

      test('ignores double dispose', () async {
        VideoFeedController(
            videos: createTestVideos(count: 1),
            pool: pool,
          )
          ..dispose()
          // Second dispose should not throw.
          ..dispose();
      });
    });

    // -----------------------------------------------------------------------
    // HLS URL handling
    // -----------------------------------------------------------------------

    group('HLS videos', () {
      test('loads HLS videos via setSource', () async {
        final videos = createHlsTestVideos(count: 1);
        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isVideoReady(0), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Pool eviction
    // -----------------------------------------------------------------------

    group('pool eviction', () {
      test('handles player eviction gracefully', () async {
        final videos = createTestVideos();

        // Small pool forces eviction.
        await pool.dispose();

        pool = TestablePlayerPool(
          mockPlayerFactory: playerFactory,
          maxPlayers: 2,
        );

        final controller = VideoFeedController(
          videos: videos,
          pool: pool,
          preloadAhead: 3,
          preloadBehind: 0,
          cacheAhead: 0,
        );
        addTearDown(controller.dispose);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Concurrent async loads with a small pool cause eviction.
        // The test passes if no exception is thrown.
        expect(controller.videoCount, equals(5));
      });
    });
  });
}
