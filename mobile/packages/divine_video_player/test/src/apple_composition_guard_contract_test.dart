import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// -[AVPlayerItem setVideoComposition:] and AVMutableComposition.scaleTimeRange
/// validate synchronously and raise an Objective-C NSInvalidArgumentException
/// (not a Swift Error) on a malformed composition. A Swift do/catch cannot
/// catch that exception, so a bad value aborts the process (SIGABRT) — the
/// TestFlight crash on 1.0.16 (804). These invariants have no Dart runtime
/// surface, so they are pinned as a source contract: a future refactor that
/// drops a guard or moves it after the throwing call keeps the runtime tests
/// green while restoring the crash, and only this test catches it.
void main() {
  group('Apple native composition guard contract', () {
    test('falls back to 30fps for a non-numeric-positive minFrameDuration', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('minFrameDuration.isNumeric, minFrameDuration.seconds > 0'),
        reason:
            'minFrameDuration can be valid-but-zero (or infinite) on assets '
            'without frame-timing metadata; .isValid alone accepts those and '
            'setVideoComposition then rejects the zero/non-numeric duration.',
      );
      expect(
        source,
        contains(
          'mutableVideoComposition.frameDuration = '
          'CMTime(value: 1, timescale: 30)',
        ),
        reason:
            'A non-numeric-positive minFrameDuration must fall back to a valid '
            '30fps frame duration, not be assigned as-is.',
      );
    });

    test('validates render size and frame duration before assigning '
        'videoComposition', () {
      final source = _appleSourceFile().readAsStringSync();

      final renderSizeGuard = source.indexOf(
        'throw CompositionError.invalidRenderSize',
      );
      final frameDurationGuard = source.indexOf(
        'throw CompositionError.invalidFrameDuration',
      );
      final assignment = source.indexOf(
        'playerItem.videoComposition = videoComposition',
      );

      expect(renderSizeGuard, greaterThanOrEqualTo(0));
      expect(frameDurationGuard, greaterThanOrEqualTo(0));
      expect(assignment, greaterThanOrEqualTo(0));
      expect(
        renderSizeGuard,
        lessThan(assignment),
        reason:
            'The render-size guard must run before setVideoComposition: — the '
            'crash it prevents happens during the assignment.',
      );
      expect(
        frameDurationGuard,
        lessThan(assignment),
        reason:
            'The frame-duration guard must run before setVideoComposition: — '
            'the crash it prevents happens during the assignment.',
      );
    });

    test('guards scaled duration before scaleTimeRange', () {
      final source = _appleSourceFile().readAsStringSync();

      final scaledGuard = source.indexOf(
        'candidate.isNumeric, candidate.seconds > 0',
      );
      final scaleCall = source.indexOf('composition.scaleTimeRange');

      expect(scaledGuard, greaterThanOrEqualTo(0));
      expect(scaleCall, greaterThanOrEqualTo(0));
      expect(
        scaledGuard,
        lessThan(scaleCall),
        reason:
            'A pathological playbackSpeed can drive the scaled duration to '
            'zero or non-numeric; scaleTimeRange raises the same uncatchable '
            'NSInvalidArgumentException, so it must be guarded first.',
      );
    });
  });
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the composition contract
/// is asserted once.
File _appleSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'DivineVideoPlayerInstance.swift',
  );
}
