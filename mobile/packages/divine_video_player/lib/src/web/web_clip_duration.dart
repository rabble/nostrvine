import 'dart:math' as math;

/// Resolves the playback duration the web backend reports for a clip, in
/// seconds.
///
/// [sourceDurationSeconds] is the `<video>` element's own duration, which is
/// `NaN` until the browser has loaded metadata and `Infinity` for a live
/// stream.
///
/// A [clipEndSeconds] past the source is clamped to the source, matching the
/// Android and Apple backends, so a caller capping playback without knowing
/// the source length still reports the natural end for shorter sources.
/// Without the clamp a blind cap makes every shorter video report the cap as
/// its duration, which breaks any consumer that arms on `duration - epsilon`.
double resolveClipDurationSeconds({
  required double clipStartSeconds,
  required double? clipEndSeconds,
  required double sourceDurationSeconds,
}) {
  final hasSourceDuration =
      !sourceDurationSeconds.isNaN && sourceDurationSeconds.isFinite;

  final double? endSeconds;
  if (clipEndSeconds == null) {
    endSeconds = hasSourceDuration ? sourceDurationSeconds : null;
  } else {
    endSeconds = hasSourceDuration
        ? math.min(clipEndSeconds, sourceDurationSeconds)
        : clipEndSeconds;
  }
  if (endSeconds == null) return 0;

  return math.max(0, endSeconds - clipStartSeconds);
}
