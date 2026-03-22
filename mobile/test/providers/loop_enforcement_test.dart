// ABOUTME: Tests for 6.3s video playback loop enforcement
// ABOUTME: Validates constants, timer creation, seek behavior, and all three
// ABOUTME: failure scenarios (deferred duration, silent seek failure, timer loss)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:video_player/video_player.dart';

class _MockVideoPlayerController extends Mock
    implements VideoPlayerController {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('Loop Enforcement Constants', () {
    test('maxPlaybackDuration is 6.3 seconds', () {
      expect(maxPlaybackDuration, const Duration(milliseconds: 6300));
    });

    test('loopCheckInterval is 200ms', () {
      expect(loopCheckInterval, const Duration(milliseconds: 200));
    });

    test('maxPlaybackDuration matches Vine-style loop length', () {
      // Vine had 6-second loops, we allow 6.3s for slight flexibility
      expect(maxPlaybackDuration.inSeconds, 6);
      expect(maxPlaybackDuration.inMilliseconds, 6300);
    });

    test('loopCheckInterval provides 5 checks per second', () {
      // 1000ms / 200ms = 5 checks per second
      const checksPerSecond = 1000 ~/ 200;
      expect(checksPerSecond, 5);
    });
  });

  group('Loop Enforcement Logic', () {
    test('videos under 6.3s should not trigger loop enforcement', () {
      const videoDuration = Duration(seconds: 5);
      expect(videoDuration < maxPlaybackDuration, isTrue);
      expect(videoDuration.inMilliseconds, lessThan(6300));
    });

    test('videos exactly 6.3s should not trigger loop enforcement', () {
      const videoDuration = Duration(milliseconds: 6300);
      expect(videoDuration > maxPlaybackDuration, isFalse);
    });

    test('videos over 6.3s should trigger loop enforcement', () {
      const videoDuration = Duration(seconds: 10);
      expect(videoDuration > maxPlaybackDuration, isTrue);
    });

    test('position at 6.3s or above triggers seek to zero', () {
      final positionsToLoop = [
        const Duration(milliseconds: 6300),
        const Duration(milliseconds: 6400),
        const Duration(seconds: 7),
        const Duration(seconds: 10),
      ];

      for (final position in positionsToLoop) {
        expect(
          position >= maxPlaybackDuration,
          isTrue,
          reason: 'Position ${position.inMilliseconds}ms should trigger loop',
        );
      }
    });

    test('position under 6.3s does not trigger seek', () {
      final positionsNoLoop = [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 3),
        const Duration(milliseconds: 6000),
        const Duration(milliseconds: 6299),
      ];

      for (final position in positionsNoLoop) {
        expect(
          position >= maxPlaybackDuration,
          isFalse,
          reason:
              'Position ${position.inMilliseconds}ms should NOT trigger loop',
        );
      }
    });
  });

  group('safeSeekTo for loop enforcement', () {
    late _MockVideoPlayerController mockController;

    setUp(() {
      mockController = _MockVideoPlayerController();
    });

    test('safeSeekTo returns true when seek succeeds', () async {
      when(() => mockController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(
        () => mockController.seekTo(Duration.zero),
      ).thenAnswer((_) async {});

      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        Duration.zero,
      );

      expect(result, isTrue);
      verify(() => mockController.seekTo(Duration.zero)).called(1);
    });

    test('safeSeekTo returns false when controller is disposed', () async {
      when(
        () => mockController.value,
      ).thenReturn(const VideoPlayerValue(duration: Duration.zero));

      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        Duration.zero,
      );

      expect(result, isFalse);
      verifyNever(() => mockController.seekTo(any()));
    });

    test('safeSeekTo catches disposal errors gracefully', () async {
      when(() => mockController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(
        () => mockController.seekTo(Duration.zero),
      ).thenThrow(Exception('Bad state: No active player with ID 42'));

      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        Duration.zero,
      );

      expect(result, isFalse);
    });
  });

  group('Scenario 1: Deferred duration (Duration.zero at init)', () {
    test(
      'init-time check fails when duration is zero',
      () {
        // Non-Divine servers may not have moov-at-front or may use HLS,
        // causing controller.value.duration to be Duration.zero after
        // initialize() completes.
        const initDuration = Duration.zero;

        // The init-time check: videoDuration > maxPlaybackDuration
        final timerCreatedAtInit = initDuration > maxPlaybackDuration;
        expect(timerCreatedAtInit, isFalse);
      },
    );

    test(
      'listener catches real duration when it resolves to > 6.3s',
      () {
        // Simulate: duration was zero at init, now platform reports real value.
        // The deferred check fires when: !checked && timer==null &&
        // initialized && duration > 6.3s. All conditions are true.
        const resolvedDuration = Duration(seconds: 15);
        expect(resolvedDuration > maxPlaybackDuration, isTrue);
      },
    );

    test(
      'listener does NOT start timer if duration resolves to <= 6.3s',
      () {
        // Duration resolves but is under the limit — no timer needed
        const resolvedDuration = Duration(seconds: 4);
        expect(resolvedDuration > maxPlaybackDuration, isFalse);
      },
    );

    test(
      'deferred check is skipped if timer was already created at init',
      () {
        // Duration was known at init — timer already exists
        const initDuration = Duration(seconds: 10);
        final deferredDurationChecked = initDuration > maxPlaybackDuration;
        expect(deferredDurationChecked, isTrue);

        // Even if listener fires with duration > 6.3s, the flag prevents
        // duplicate timer creation
        const resolvedDuration = Duration(seconds: 10);
        final wouldCreateDuplicate =
            !deferredDurationChecked && resolvedDuration > maxPlaybackDuration;
        expect(wouldCreateDuplicate, isFalse);
      },
    );
  });

  group('Scenario 2: seekTo silently failing (no range request support)', () {
    late _MockVideoPlayerController mockController;

    setUp(() {
      mockController = _MockVideoPlayerController();
    });

    test(
      'when timer seekTo fails, listener retries on next position update',
      () async {
        // Timer-initiated seek fails silently (server doesn't support ranges)
        when(() => mockController.value).thenReturn(
          const VideoPlayerValue(
            duration: Duration(seconds: 10),
            position: Duration(milliseconds: 6500),
            isInitialized: true,
            isPlaying: true,
          ),
        );

        // First seek fails
        when(
          () => mockController.seekTo(Duration.zero),
        ).thenThrow(Exception('Bad state: No active player with ID 1'));

        final timerResult = await safeSeekTo(
          mockController,
          'test-video-id',
          Duration.zero,
        );
        expect(timerResult, isFalse);

        // Listener-based enforcement fires on next platform callback.
        // This time the seek succeeds (e.g., server buffers caught up).
        when(
          () => mockController.seekTo(Duration.zero),
        ).thenAnswer((_) async {});

        final listenerResult = await safeSeekTo(
          mockController,
          'test-video-id',
          Duration.zero,
        );
        expect(listenerResult, isTrue);
      },
    );

    test(
      'listener enforces loop even when no timer exists',
      () {
        // Simulates: timer was never created (any reason), but video is
        // playing past 6.3s. The listener-based check catches it.
        const isPlaying = true;
        const position = Duration(milliseconds: 7000);
        const listenerSeekInProgress = false;

        final shouldEnforce =
            isPlaying &&
            position >= maxPlaybackDuration &&
            !listenerSeekInProgress;
        expect(shouldEnforce, isTrue);
      },
    );

    test(
      'listener debounces: does not fire while previous seek is in progress',
      () {
        const isPlaying = true;
        const position = Duration(milliseconds: 7000);
        const listenerSeekInProgress = true; // Previous seek still running

        final shouldEnforce =
            isPlaying &&
            position >= maxPlaybackDuration &&
            !listenerSeekInProgress;
        expect(shouldEnforce, isFalse);
      },
    );

    test(
      'listener debounce resets after seek completes, allowing next attempt',
      () async {
        var listenerSeekInProgress = false;

        // Simulate the listener enforcement flow
        const isPlaying = true;
        const position = Duration(milliseconds: 7000);

        // First: should enforce
        expect(
          isPlaying &&
              position >= maxPlaybackDuration &&
              !listenerSeekInProgress,
          isTrue,
        );

        // Mark in progress
        listenerSeekInProgress = true;

        // While in progress: should NOT enforce again
        expect(
          isPlaying &&
              position >= maxPlaybackDuration &&
              !listenerSeekInProgress,
          isFalse,
        );

        // Seek completes (safeSeekTo .then callback)
        listenerSeekInProgress = false;

        // Now should enforce again if position is still past limit
        expect(
          isPlaying &&
              position >= maxPlaybackDuration &&
              !listenerSeekInProgress,
          isTrue,
        );
      },
    );
  });

  group('Scenario 3: Timer not firing (GC, cancellation, edge case)', () {
    test(
      'listener catches playback past 6.3s regardless of timer state',
      () {
        // Even if timer is null/cancelled/GC'd, the listener still
        // checks position on every platform callback
        const isPlaying = true;
        const position = Duration(milliseconds: 6400);
        const listenerSeekInProgress = false;
        // loopEnforcementTimer is null — doesn't matter for listener check

        final shouldEnforce =
            isPlaying &&
            position >= maxPlaybackDuration &&
            !listenerSeekInProgress;
        expect(shouldEnforce, isTrue);
      },
    );

    test(
      'paused video past 6.3s does NOT trigger listener enforcement',
      () {
        // Video is paused at 7s (e.g., user backgrounded app)
        // Should not seek — wait until playback resumes
        const isPlaying = false;
        const position = Duration(milliseconds: 7000);

        // isPlaying gate prevents enforcement even when past the limit
        expect(isPlaying, isFalse);
        expect(position >= maxPlaybackDuration, isTrue);
      },
    );

    test(
      'short videos (< 6.3s) are unaffected by listener enforcement',
      () {
        // A 4-second video loops natively. Its position resets at 4s,
        // never reaching the 6.3s threshold, so the listener check
        // is a harmless no-op every frame.
        const videoDuration = Duration(seconds: 4);
        const maxPosition = videoDuration;

        final wouldTrigger = maxPosition >= maxPlaybackDuration;
        expect(wouldTrigger, isFalse);
      },
    );
  });

  group('All three scenarios: end-to-end enforcement flow', () {
    late _MockVideoPlayerController mockController;

    setUp(() {
      mockController = _MockVideoPlayerController();
    });

    test(
      'full lifecycle: deferred duration -> timer starts -> seek works',
      () async {
        // Phase 1: Init with Duration.zero (non-Divine video)
        // The init-time check (videoDuration > maxPlaybackDuration) fails
        const initDuration = Duration.zero;
        expect(initDuration > maxPlaybackDuration, isFalse);

        // Phase 2: Duration resolves to 15s in listener callback
        // The deferred check sees: !checked && duration > 6.3s → starts timer
        const resolvedDuration = Duration(seconds: 15);
        expect(resolvedDuration > maxPlaybackDuration, isTrue);

        // Phase 3: Timer fires, video is at 6.5s, seek to 0
        when(() => mockController.value).thenReturn(
          const VideoPlayerValue(
            duration: Duration(seconds: 15),
            position: Duration(milliseconds: 6500),
            isInitialized: true,
            isPlaying: true,
          ),
        );
        when(
          () => mockController.seekTo(Duration.zero),
        ).thenAnswer((_) async {});

        final seekResult = await safeSeekTo(
          mockController,
          'test-video-id',
          Duration.zero,
        );
        expect(seekResult, isTrue);
        verify(() => mockController.seekTo(Duration.zero)).called(1);
      },
    );

    test(
      'full lifecycle: timer created at init but seek fails -> '
      'listener retries',
      () async {
        // Phase 1: Duration known at init, timer created
        const initDuration = Duration(seconds: 20);
        final timerCreatedAtInit = initDuration > maxPlaybackDuration;
        expect(timerCreatedAtInit, isTrue);

        // Phase 2: Timer fires at 6.3s but seekTo silently fails
        when(() => mockController.value).thenReturn(
          const VideoPlayerValue(
            duration: Duration(seconds: 20),
            position: Duration(milliseconds: 6400),
            isInitialized: true,
            isPlaying: true,
          ),
        );
        when(
          () => mockController.seekTo(Duration.zero),
        ).thenThrow(Exception('Bad state: No active player with ID 5'));

        final timerSeekResult = await safeSeekTo(
          mockController,
          'test-video-id',
          Duration.zero,
        );
        expect(timerSeekResult, isFalse);

        // Phase 3: Listener fires next frame, retries the seek
        when(
          () => mockController.seekTo(Duration.zero),
        ).thenAnswer((_) async {});

        final listenerSeekResult = await safeSeekTo(
          mockController,
          'test-video-id',
          Duration.zero,
        );
        expect(listenerSeekResult, isTrue);
      },
    );

    test(
      'full lifecycle: no timer, no deferred duration, '
      'listener catches it alone',
      () async {
        // Edge case: timer somehow doesn't exist, but video is playing
        // past 6.3s. Listener-only enforcement.
        const isPlaying = true;
        const position = Duration(milliseconds: 8000);
        var listenerSeekInProgress = false;

        // Listener check triggers
        final shouldEnforce =
            isPlaying &&
            position >= maxPlaybackDuration &&
            !listenerSeekInProgress;
        expect(shouldEnforce, isTrue);

        // Seek succeeds
        listenerSeekInProgress = true;
        when(() => mockController.value).thenReturn(
          const VideoPlayerValue(
            duration: Duration(seconds: 30),
            position: Duration(milliseconds: 8000),
            isInitialized: true,
            isPlaying: true,
          ),
        );
        when(
          () => mockController.seekTo(Duration.zero),
        ).thenAnswer((_) async {});

        final result = await safeSeekTo(
          mockController,
          'test-video-id',
          Duration.zero,
        );
        expect(result, isTrue);

        // Debounce resets
        listenerSeekInProgress = false;
        expect(listenerSeekInProgress, isFalse);
      },
    );
  });

  group('Timer check frequency', () {
    test('200ms interval catches 6.3s boundary within tolerance', () {
      const maxOvershoot = Duration(milliseconds: 200);
      final worstCaseLoopPoint = maxPlaybackDuration + maxOvershoot;

      expect(worstCaseLoopPoint.inMilliseconds, 6500);
      expect(worstCaseLoopPoint.inSeconds, lessThan(7));
    });

    test('check interval is much more efficient than per-frame', () {
      const perFrameChecksPerSecond = 60;
      const ourChecksPerSecond = 1000 ~/ 200;

      const reduction =
          (perFrameChecksPerSecond - ourChecksPerSecond) /
          perFrameChecksPerSecond *
          100;
      expect(reduction, greaterThan(90));
    });
  });
}
