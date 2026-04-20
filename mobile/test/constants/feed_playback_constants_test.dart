// ABOUTME: Tests for FeedPlaybackConstants — shared Vine-loop cap + tolerance.
// ABOUTME: Covers constant values and the shouldEnforceLoopSeek decision helper.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/feed_playback_constants.dart';

void main() {
  group(FeedPlaybackConstants, () {
    group('constants', () {
      test('maxLoopDuration is 6.3 seconds', () {
        expect(
          FeedPlaybackConstants.maxLoopDuration,
          equals(const Duration(milliseconds: 6300)),
        );
      });

      test('loopTolerance is 500ms', () {
        expect(
          FeedPlaybackConstants.loopTolerance,
          equals(const Duration(milliseconds: 500)),
        );
      });
    });

    group('shouldEnforceLoopSeek', () {
      test('returns false when position is below the cap', () {
        final result = FeedPlaybackConstants.shouldEnforceLoopSeek(
          position: const Duration(milliseconds: 5000),
          duration: const Duration(seconds: 60),
        );

        expect(result, isFalse);
      });

      test(
        'returns false when the natural end is inside the tolerance band',
        () {
          // Video is 6.4s, position reached 6.3s → tail = 100ms < 500ms.
          // Native looping should wrap cleanly instead of a forced seek.
          final result = FeedPlaybackConstants.shouldEnforceLoopSeek(
            position: const Duration(milliseconds: 6300),
            duration: const Duration(milliseconds: 6400),
          );

          expect(result, isFalse);
        },
      );

      test(
        'returns true when the natural end is beyond the tolerance band',
        () {
          // Video is 10s, position reached 6.3s → tail = 3.7s > 500ms.
          final result = FeedPlaybackConstants.shouldEnforceLoopSeek(
            position: const Duration(milliseconds: 6300),
            duration: const Duration(seconds: 10),
          );

          expect(result, isTrue);
        },
      );

      test('returns true when duration is unknown (zero) past the cap', () {
        // Metadata-less streams: safer default is to enforce the cap.
        final result = FeedPlaybackConstants.shouldEnforceLoopSeek(
          position: const Duration(milliseconds: 6400),
          duration: Duration.zero,
        );

        expect(result, isTrue);
      });

      test('honors a caller-provided maxLoop', () {
        // With a 4s cap, a 3s position should not trigger.
        final below = FeedPlaybackConstants.shouldEnforceLoopSeek(
          position: const Duration(seconds: 3),
          duration: const Duration(seconds: 10),
          maxLoop: const Duration(seconds: 4),
        );
        expect(below, isFalse);

        // With a 4s cap, a 4s position with a 10s video should seek.
        final above = FeedPlaybackConstants.shouldEnforceLoopSeek(
          position: const Duration(seconds: 4),
          duration: const Duration(seconds: 10),
          maxLoop: const Duration(seconds: 4),
          tolerance: Duration.zero,
        );
        expect(above, isTrue);
      });

      test('zero tolerance reproduces the pre-fix hard-cap behavior', () {
        // Position exactly at cap, zero tolerance → must seek regardless
        // of how close the natural end is.
        final result = FeedPlaybackConstants.shouldEnforceLoopSeek(
          position: const Duration(milliseconds: 6300),
          duration: const Duration(milliseconds: 6400),
          tolerance: Duration.zero,
        );

        expect(result, isTrue);
      });
    });
  });
}
