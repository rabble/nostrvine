// ABOUTME: Tests for FeedPlaybackConstants — shared Vine-loop cap + tolerance.
// ABOUTME: Covers constant values and the shouldEnforceLoopForDuration helper.

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

    group('shouldEnforceLoopForDuration', () {
      test('returns false for a short video well under the cap', () {
        final result = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(seconds: 5),
        );

        expect(result, isFalse);
      });

      test('returns false for an exact-cap video (editor capture at 6.3s)', () {
        // The 6.3s editor cap must not trigger enforcement — native
        // looping handles the wrap without clipping the final frame
        // (divinevideo/divine-mobile#1845).
        final result = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(milliseconds: 6300),
        );

        expect(result, isFalse);
      });

      test('returns false for a video inside the tolerance band', () {
        // Encoder drift: 6.3s capture transcoded to 6.4s. Still short
        // enough that the native loop wraps cleanly.
        final result = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(milliseconds: 6400),
        );

        expect(result, isFalse);
      });

      test('returns false for a video at the exact tolerance boundary', () {
        // 6.3s cap + 500ms tolerance = 6.8s. A 6.8s video is the last
        // one that still gets native looping; 6.801s would flip over.
        final boundary = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(milliseconds: 6800),
        );
        expect(boundary, isFalse);

        final justOver = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(milliseconds: 6801),
        );
        expect(justOver, isTrue);
      });

      test('returns true for a video materially longer than the cap', () {
        final result = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(seconds: 10),
        );

        expect(result, isTrue);
      });

      test('returns true when duration is unknown (zero)', () {
        // Metadata-less streams: safer default is to enforce the cap so
        // the feed doesn't accidentally play an arbitrarily long video
        // uninterrupted. Per-tick callers will re-evaluate once the
        // duration populates.
        final result = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: Duration.zero,
        );

        expect(result, isTrue);
      });

      test('honors caller-provided maxLoop and tolerance', () {
        // 4s cap + zero tolerance → a 5s video must enforce.
        final enforce = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(seconds: 5),
          maxLoop: const Duration(seconds: 4),
          tolerance: Duration.zero,
        );
        expect(enforce, isTrue);

        // 4s cap + 2s tolerance → a 5s video stays inside the band.
        final skip = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(seconds: 5),
          maxLoop: const Duration(seconds: 4),
          tolerance: const Duration(seconds: 2),
        );
        expect(skip, isFalse);
      });

      test('zero tolerance reproduces the pre-fix hard-cap behavior', () {
        // Any video >= cap triggers enforcement, so the exact-cap
        // Vine-editor case is back to the #1845 tail-clip symptom.
        final atCap = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(milliseconds: 6300),
          tolerance: Duration.zero,
        );
        expect(atCap, isFalse);

        final justOver = FeedPlaybackConstants.shouldEnforceLoopForDuration(
          duration: const Duration(milliseconds: 6301),
          tolerance: Duration.zero,
        );
        expect(justOver, isTrue);
      });
    });
  });
}
