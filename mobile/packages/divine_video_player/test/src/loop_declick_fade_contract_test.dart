import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loop declick fade contract', () {
    test('Apple fades the video, not each clip', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('edgeDeclickFadeSeconds = 0.010'),
        reason:
            'AVPlayerLooper joins the video end to its start on every '
            'restart. Without a fade that step is audible as a click.',
      );
      expect(
        source,
        matches(
          RegExp(
            r'if i == 0, fadeSeconds > 0 \{[\s\S]*?'
            r'fromStartVolume: 0,\s*toEndVolume: vol,',
          ),
        ),
        reason:
            'Only the first clip carries the fade in — fading every clip '
            'would notch the audio at each cut inside the video.',
      );
      expect(
        source,
        matches(
          RegExp(
            r'if i == lastIndex, fadeSeconds > 0 \{[\s\S]*?'
            r'fromStartVolume: vol,\s*toEndVolume: 0,',
          ),
        ),
        reason:
            'The last clip carries the fade out; fading only the start '
            'still leaves the step at the join.',
      );
    });

    test('Android reaches the audio path at all', () {
      final source = _androidSourceFile().readAsStringSync();

      expect(
        source,
        contains('LoopDeclickRenderersFactory(context, declickProcessor)'),
        reason:
            'The processor only ever runs if it is built into the audio sink. '
            'A DefaultRenderersFactory here leaves the fade as dead code.',
      );
      expect(
        source,
        contains('declickProcessor.enabled = clipCount == 1'),
        reason:
            'On a multi-clip timeline a stream is one clip rather than the '
            'whole video, so fading every stream would notch each cut.',
      );
      expect(
        source,
        contains('declickProcessor.videoDurationUs'),
        reason:
            'The fade out has to know where the loop join is; without a '
            'duration only the video start can be faded.',
      );
    });

    test('Apple never writes ramps that overlap', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('CMTimeCompare(flatEnd, flatStart) > 0'),
        reason:
            'A ramp that crosses an existing one is rejected with an '
            'Objective-C NSInvalidArgumentException, which is not a Swift '
            'Error and aborts the process. The flat gain may only be '
            'written where the two fades have not already claimed the time.',
      );
      expect(
        source,
        matches(
          RegExp(
            r'min\(\s*Self\.edgeDeclickFadeSeconds,\s*'
            r'\(durations\.first \?\? 0\) / 2,\s*'
            r'\(durations\.last \?\? 0\) / 2',
          ),
        ),
        reason:
            'A video shorter than the two fades combined must get shorter '
            'ones, otherwise the fade in and fade out overlap.',
      );
    });
  });
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
