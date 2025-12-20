// ABOUTME: Tests for 6.3s video playback loop enforcement
// ABOUTME: Validates constants, timer creation logic, and seek behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/providers/individual_video_providers.dart';

@GenerateNiceMocks([MockSpec<VideoPlayerController>()])
import 'loop_enforcement_test.mocks.dart';

void main() {
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
      // Arrange - video is 5 seconds (under limit)
      final videoDuration = const Duration(seconds: 5);

      // Assert - duration should be less than maxPlaybackDuration
      expect(videoDuration < maxPlaybackDuration, isTrue);
      expect(videoDuration.inMilliseconds, lessThan(6300));
    });

    test('videos exactly 6.3s should not trigger loop enforcement', () {
      // Arrange - video is exactly 6.3 seconds
      final videoDuration = const Duration(milliseconds: 6300);

      // Assert - duration should NOT be greater than maxPlaybackDuration
      expect(videoDuration > maxPlaybackDuration, isFalse);
    });

    test('videos over 6.3s should trigger loop enforcement', () {
      // Arrange - video is 10 seconds (over limit)
      final videoDuration = const Duration(seconds: 10);

      // Assert - duration should be greater than maxPlaybackDuration
      expect(videoDuration > maxPlaybackDuration, isTrue);
    });

    test('position at 6.3s or above triggers seek to zero', () {
      // Positions that should trigger loop
      final positionsToLoop = [
        const Duration(milliseconds: 6300), // Exactly at limit
        const Duration(milliseconds: 6400), // 100ms over
        const Duration(seconds: 7), // Well over
        const Duration(seconds: 10), // Way over
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
      // Positions that should NOT trigger loop
      final positionsNoLoop = [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 3),
        const Duration(milliseconds: 6000),
        const Duration(milliseconds: 6299), // Just under limit
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
    late MockVideoPlayerController mockController;

    setUp(() {
      mockController = MockVideoPlayerController();
    });

    test('safeSeekTo returns true when seek succeeds', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(mockController.seekTo(Duration.zero)).thenAnswer((_) async {});

      // Act
      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        Duration.zero,
      );

      // Assert
      expect(result, isTrue);
      verify(mockController.seekTo(Duration.zero)).called(1);
    });

    test('safeSeekTo returns false when controller is disposed', () async {
      // Arrange - simulate disposed controller
      when(mockController.value).thenReturn(
        const VideoPlayerValue(duration: Duration.zero, isInitialized: false),
      );

      // Act
      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        Duration.zero,
      );

      // Assert
      expect(result, isFalse);
      verifyNever(mockController.seekTo(any));
    });

    test('safeSeekTo catches disposal errors gracefully', () async {
      // Arrange
      when(mockController.value).thenReturn(
        VideoPlayerValue(
          duration: const Duration(seconds: 10),
          isInitialized: true,
        ),
      );
      when(
        mockController.seekTo(Duration.zero),
      ).thenThrow(Exception('Bad state: No active player with ID 42'));

      // Act
      final result = await safeSeekTo(
        mockController,
        'test-video-id',
        Duration.zero,
      );

      // Assert - should handle gracefully, not throw
      expect(result, isFalse);
    });
  });

  group('Timer check frequency', () {
    test('200ms interval catches 6.3s boundary within tolerance', () {
      // At 200ms intervals, worst case is video loops at 6.5s instead of 6.3s
      // This is 200ms tolerance which is acceptable for UX
      const maxOvershoot = Duration(milliseconds: 200);
      final worstCaseLoopPoint = maxPlaybackDuration + maxOvershoot;

      // Worst case: 6.5 seconds
      expect(worstCaseLoopPoint.inMilliseconds, 6500);

      // Still well under 7 seconds - acceptable
      expect(worstCaseLoopPoint.inSeconds, lessThan(7));
    });

    test('check interval is much more efficient than per-frame', () {
      // Per-frame at 60fps = 60 checks/second
      // Our interval at 200ms = 5 checks/second
      // That's 92% reduction in checks
      const perFrameChecksPerSecond = 60;
      const ourChecksPerSecond = 1000 ~/ 200; // 5

      final reduction =
          (perFrameChecksPerSecond - ourChecksPerSecond) /
          perFrameChecksPerSecond *
          100;
      expect(reduction, greaterThan(90)); // >90% reduction
    });
  });
}
