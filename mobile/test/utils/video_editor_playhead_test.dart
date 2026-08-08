// ABOUTME: Tests for the video editor playhead position helpers
// ABOUTME: Covers speed-scaled interpolation and stop-motion loop wrapping

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/video_editor_playhead.dart';

void main() {
  group('interpolatePlayheadPosition', () {
    const maxDuration = Duration(seconds: 10);

    test('advances from the anchor by the elapsed wall-clock at 1x', () {
      expect(
        interpolatePlayheadPosition(
          anchor: const Duration(seconds: 2),
          elapsed: const Duration(milliseconds: 100),
          speed: 1,
          maxDuration: maxDuration,
        ),
        const Duration(milliseconds: 2100),
      );
    });

    test('scales the elapsed by the playback speed', () {
      expect(
        interpolatePlayheadPosition(
          anchor: const Duration(seconds: 1),
          elapsed: const Duration(milliseconds: 200),
          speed: 2,
          maxDuration: maxDuration,
        ),
        const Duration(milliseconds: 1400),
      );
    });

    test('clamps to the max duration past the end', () {
      expect(
        interpolatePlayheadPosition(
          anchor: const Duration(seconds: 9, milliseconds: 950),
          elapsed: const Duration(milliseconds: 200),
          speed: 1,
          maxDuration: maxDuration,
        ),
        maxDuration,
      );
    });

    test('never returns a negative position', () {
      expect(
        interpolatePlayheadPosition(
          anchor: Duration.zero,
          elapsed: const Duration(milliseconds: 100),
          speed: -1,
          maxDuration: maxDuration,
        ),
        Duration.zero,
      );
    });
  });

  group('stopMotionLoopPosition', () {
    const total = Duration(milliseconds: 300);

    test('advances from the anchor by the elapsed wall-clock', () {
      expect(
        stopMotionLoopPosition(
          anchor: const Duration(milliseconds: 100),
          elapsed: const Duration(milliseconds: 50),
          total: total,
        ),
        const Duration(milliseconds: 150),
      );
    });

    test('wraps around the total so playback loops', () {
      // 250 + 100 = 350, 350 % 300 = 50.
      expect(
        stopMotionLoopPosition(
          anchor: const Duration(milliseconds: 250),
          elapsed: const Duration(milliseconds: 100),
          total: total,
        ),
        const Duration(milliseconds: 50),
      );
    });

    test('returns zero exactly at a full loop boundary', () {
      expect(
        stopMotionLoopPosition(
          anchor: Duration.zero,
          elapsed: total,
          total: total,
        ),
        Duration.zero,
      );
    });

    test('returns zero when total is non-positive', () {
      expect(
        stopMotionLoopPosition(
          anchor: const Duration(milliseconds: 100),
          elapsed: const Duration(milliseconds: 50),
          total: Duration.zero,
        ),
        Duration.zero,
      );
    });
  });
}
