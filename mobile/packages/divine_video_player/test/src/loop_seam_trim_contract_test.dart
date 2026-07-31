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
        contains('boundedCommonTrackEnd('),
        reason:
            'The clip must end where both tracks still have content only when '
            'the mismatch is small enough to be a seam, not a malformed asset.',
      );
      expect(
        source,
        contains('CMTimeMinimum(endTime, commonEnd)'),
        reason:
            'Clamping may only ever shorten a clip — an explicit trim that '
            'ends earlier still wins.',
      );
      expect(
        source,
        contains('catch {'),
        reason:
            'A failure to read optional track ranges must leave the clip '
            'untrimmed rather than failing composition playback.',
      );
      expect(
        source,
        contains('maxCommonTrackEndTrimMs = 500.0'),
        reason:
            'The clamp must be bounded so stub audio tracks do not collapse a '
            'normal-length video into a tiny loop.',
      );
      expect(
        source,
        contains('maxCommonTrackEndTrimRatio = 0.10'),
        reason:
            'The clamp must also be relative to playable duration so short '
            'clips cannot lose an excessive fraction of content.',
      );
      expect(
        source,
        contains('if CMTimeCompare(audioEnd, videoEnd) > 0 {'),
        reason:
            'The bound only guards against discarding visible video, so it '
            'must not apply when the audio track is the longer one — that '
            'excess is a frozen frame at every loop restart.',
      );
    });

    test('Android clamps the clipping configuration, not just endMs', () {
      final source = _androidSourceFile().readAsStringSync();

      expect(
        source,
        contains('boundedCommonTrackEndMs'),
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
        contains('buildMediaItem(uri, startMs, effectiveEndMs)'),
        reason:
            'The clamped end must reach ExoPlayer; setting the raw endMs '
            'would leave the seam in place.',
      );
      expect(
        source,
        contains('MAX_COMMON_TRACK_END_TRIM_MS = 500L'),
        reason:
            'The clamp must be bounded so stub audio tracks do not collapse a '
            'normal-length video into a tiny loop.',
      );
      expect(
        source,
        contains('MAX_COMMON_TRACK_END_TRIM_RATIO = 0.10'),
        reason:
            'The clamp must also be relative to playable duration so short '
            'clips cannot lose an excessive fraction of content.',
      );
      expect(
        source,
        contains('if (audioEndMs > videoEndMs) return commonEndMs'),
        reason:
            'The bound only guards against discarding visible video, so it '
            'must not apply when the audio track is the longer one — that '
            'excess is a frozen frame at every loop restart.',
      );
    });

    test('Android probes remote sources too, off the platform thread', () {
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
        contains(RegExp(r'uri\.startsWith\("https://"\)')),
        reason:
            'Remote clips are the ones the feed loops. Probing local files '
            'only left every https source ending at the container duration, '
            'so 46% of feed videos replayed a frozen last frame at every '
            'loop restart on Android while iOS looped cleanly.',
      );
      expect(
        source,
        contains('metadataExecutor.execute'),
        reason:
            'The probe blocks on I/O, so it may never run on the platform '
            'thread — which is why it used to be skipped for remote sources.',
      );
      expect(
        source,
        contains('warmTrackDurationsInBackground'),
        reason:
            'Uncached remote probes must warm the cache without serializing '
            'the feed first-frame path ahead of ExoPlayer.',
      );
      expect(
        source,
        matches(
          RegExp(
            r'mainHandler\.postDelayed\(\s*deferredSetClipsTimeout,\s*'
            'TRACK_DURATION_RESOLVE_TIMEOUT_MS',
          ),
        ),
        reason:
            'MediaHTTPConnection sets a connect timeout and no read timeout, '
            'so a host that stalls mid-response would hold `await setClips()` '
            'open forever. The wait has to be bounded, and expiring it plays '
            'unclamped rather than not at all.',
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
