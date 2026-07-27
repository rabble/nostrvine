import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `insertTimeRange` silently inserts only the media that exists, so an
/// out-of-range clip end never truncates playback — but it does inflate the
/// `clipDuration` the Swift side derives from the *requested* end, and that
/// value becomes the reported `totalDuration`. Callers that cap playback
/// without knowing the source length (the feed's `maxFeedPlaybackDuration`)
/// depend on the clamp: without it every shorter video reports the cap as its
/// duration, corrupting the progress fraction and the loop-completion timing
/// that arms on `duration - endThreshold`.
///
/// ExoPlayer clamps the equivalent `ClippingConfiguration` inside
/// `ClippingTimeline`, so the guarantee documented on `VideoClip.end` holds on
/// Android without repo code. On Apple it is this branch and nothing else, and
/// it has no Dart runtime surface — the package's CI runs Dart and Kotlin
/// tests only, so a refactor that drops it keeps every other test green.
void main() {
  group('Apple native clip-end clamp contract', () {
    test('clamps a requested clip end to the asset duration', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('CMTimeCompare(requestedEnd, assetDuration) > 0'),
        reason:
            'A requested end past the asset must resolve to the asset '
            'duration, not to the requested value.',
      );
      expect(
        source,
        contains('assetDuration.isNumeric'),
        reason:
            'A non-numeric asset duration (indefinite/unloaded) cannot be '
            'compared against, so the requested end has to stand there.',
      );
    });

    test('clamps before deriving the clip duration', () {
      final source = _appleSourceFile().readAsStringSync();

      final clamp = source.indexOf(
        'CMTimeCompare(requestedEnd, assetDuration) > 0',
      );
      final clipDuration = source.indexOf(
        'CMTimeSubtract(endTime, startTime)',
      );

      expect(clamp, greaterThanOrEqualTo(0));
      expect(clipDuration, greaterThanOrEqualTo(0));
      expect(
        clamp,
        lessThan(clipDuration),
        reason:
            'clipDuration feeds the reported totalDuration, so it must be '
            'derived from the clamped end rather than the requested one.',
      );
    });
  });
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the clamp contract is asserted
/// once.
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
