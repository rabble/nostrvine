import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loop declick fade contract', () {
    test('Apple fades the video, not each clip', () {
      final source = _appleSourceFile().readAsStringSync();

      expect(
        source,
        contains('edgeDeclickFadeSeconds = 0.030'),
        reason:
            'AVPlayerLooper joins the video end to its start on every '
            'restart. Without a fade that step is audible as a click — and '
            'AVFoundation stretches any volume ramp shorter than about 25 ms '
            'to that floor, so it never reaches zero where it was asked to. '
            'Measured on the last sample: 10 ms leaves gain 0.60, 30 ms '
            'leaves 0.0008. Shortening this back re-introduces the click.',
      );
      expect(
        source,
        matches(
          RegExp(
            r'if i == 0, fadeInTicks > 0 \{[\s\S]{0,120}?'
            r'flatStart = CMTimeAdd\(t, fadeIn\)[\s\S]{0,120}?'
            r'params\.setVolumeRamp\([\s\S]{0,120}?'
            r'fromStartVolume: 0,\s*toEndVolume: vol,',
          ),
        ),
        reason:
            'Only the first clip carries the fade in — fading every clip '
            'would notch the audio at each cut inside the video. The slack '
            'is bounded rather than bare whitespace so an interleaved '
            'comment does not read as a missing fade.',
      );
      expect(
        source,
        matches(
          RegExp(
            r'params\.setVolumeRamp\([\s\S]{0,80}?'
            r'fromStartVolume: vol,\s*toEndVolume: 0,\s*'
            r'timeRange: CMTimeRange\(start: flatEnd, end: clipEnd\)',
          ),
        ),
        reason:
            'The last clip carries the fade out, and it has to land on the '
            "composition's own end; fading only the start still leaves the "
            'step at the join.',
      );
      expect(
        source,
        contains('let clipEnd = CMTimeAdd(t, clipDuration)'),
        reason:
            'The ramps must be laid out on the CMTimes the composition was '
            'built from. Round-tripping them through seconds moves the last '
            "clip's end off the composition's end by up to a tick, and the "
            'fade out then stops short of the sample the loop joins.',
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
        matches(
          RegExp(
            r'playbackState == Player\.STATE_READY\) \{[\s\S]{0,400}?'
            r'updateDeclickDuration\(\)',
          ),
        ),
        reason:
            'The length bounds how long the fade may be on a video too short '
            'to carry two of them, and it is only readable once the timeline '
            'is populated. Naming the field alone is not enough — setClips '
            'also writes it, with DURATION_UNKNOWN.',
      );
      expect(
        source,
        contains(
          'declickProcessor.videoDurationUs = if (durationMs == C.TIME_UNSET)',
        ),
        reason:
            'An unknown length has to stay unknown rather than become a '
            'negative duration the fade would wrap on.',
      );

      // Both anchors occur exactly once, so their order in the file is the
      // order they run in.
      final publishIndex = source.indexOf(
        'declickProcessor.nextStreamStartUs = startLocalMs * 1000L',
      );
      final swapIndex = source.indexOf('exoPlayer.setMediaItems(');
      expect(publishIndex, isNonNegative);
      expect(swapIndex, isNonNegative);
      expect(
        publishIndex,
        lessThan(swapIndex),
        reason:
            'The playlist swap disables the audio renderer, which flushes the '
            'pipeline on the playback thread. A start position published after '
            'it is read too late, and the lap after a resume loses its fade '
            'out. Presence assertions alone do not catch the reordering.',
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
        contains(
          'let fadeInTicks = min(maxFadeTicks, '
          'Self.halfFadeTicks(scaledDurations.first))',
        ),
        reason:
            'A video shorter than the two fades combined must get shorter '
            'ones, capped by the clip each fade sits in. Capping both by one '
            'minimum lets a short clip at either end shorten the fade at the '
            'other — and under the ~25 ms floor AVFoundation stretches the '
            'ramp so it never reaches zero, silently un-fixing that edge.',
      );
      expect(
        source,
        contains(
          'let fadeOutTicks = min(maxFadeTicks, '
          'Self.halfFadeTicks(scaledDurations.last))',
        ),
        reason:
            'The fade out is capped by the last clip, and by the exact CMTime '
            'the composition was built from rather than a Double round trip.',
      );
      expect(
        source,
        contains('method: .roundTowardZero'),
        reason:
            'The no-overlap proof rests on the cap understating its clip. '
            'CMTime.h does not specify which direction CMTimeMakeWithSeconds '
            'rounds, so the conversion names the direction rather than '
            'relying on the behaviour that happens to ship — a half that '
            'rounded up while the clip rounded down would put the two fades '
            'over each other, and AVFoundation rejects overlapping ramps '
            'with an Objective-C exception that aborts the process.',
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
