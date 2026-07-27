import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loop seam trim contract', () {
    test('Apple clamps the clip to the shorter of the two tracks', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('trimToCommonTrackEnd'),
        reason:
            'Apple must honour the flag; without it a looping clip replays '
            'the tail where one track has already ended.',
      );
      expect(
        source,
        contains('CMTimeMinimum(videoRange.end, audioRange.end)'),
        reason:
            'The clip must end where both tracks still have content, not at '
            'the asset duration, which is the longest track.',
      );
      expect(
        source,
        contains('CMTimeMinimum(endTime, commonEnd)'),
        reason:
            'Clamping may only ever shorten a clip — an explicit trim that '
            'ends earlier still wins.',
      );
    });

    test('Android clamps the clipping configuration, not just endMs', () {
      final source = _androidSourceFile().readAsStringSync();

      expect(
        source,
        contains('commonTrackEndMs'),
        reason:
            'Android must resolve the point where both tracks still have '
            'content before building the clipping configuration.',
      );
      expect(
        source,
        contains('listOfNotNull(endMs, commonEndMs).minOrNull()'),
        reason:
            'Clamping may only ever shorten a clip — an explicit trim that '
            'ends earlier still wins.',
      );
      expect(
        source,
        contains('setEndPositionMs(effectiveEndMs)'),
        reason:
            'The clamped end must reach ExoPlayer; setting the raw endMs '
            'would leave the seam in place.',
      );
    });

    test('Android probes local files only', () {
      final source = _androidSourceFile().readAsStringSync();

      expect(
        source,
        contains('MediaExtractor'),
        reason:
            'Per-track durations are not exposed by the ExoPlayer '
            'timeline, which reports the longest track.',
      );
      expect(
        source,
        contains(RegExp(r'uri\.startsWith\("file://"\)')),
        reason:
            'Probing a remote source would block playback start on a network '
            'round trip, so only local files may be read.',
      );
    });
  });
}

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

File _androidSourceFile() {
  final packageRelative = File(
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
}
