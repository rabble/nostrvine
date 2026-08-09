// ABOUTME: Playhead position math for the video editor timeline
// ABOUTME: Interpolates between coarse player reports and loops stop-motion

/// Interpolates a composite playback position forward from [anchor] by the
/// wall-clock [elapsed] since the anchor was captured, scaled by playback
/// [speed], and clamped to `[Duration.zero, maxDuration]`.
///
/// Drives the layer overlay's play time at display refresh rate between the
/// native player's coarse (~5 Hz) position reports so enter/leave animations
/// animate smoothly during playback instead of stepping.
Duration interpolatePlayheadPosition({
  required Duration anchor,
  required Duration elapsed,
  required double speed,
  required Duration maxDuration,
}) {
  final raw = anchor + elapsed * speed;
  if (raw < Duration.zero) return Duration.zero;
  if (raw > maxDuration) return maxDuration;
  return raw;
}

/// Advances the frames-only stop-motion playhead forward from [anchor] by the
/// wall-clock [elapsed], wrapping around [total] so playback loops seamlessly.
///
/// A frames-only stop-motion clip has no native player to report position, so
/// this drives the editor timeline directly. Returns [Duration.zero] when
/// [total] is non-positive.
Duration stopMotionLoopPosition({
  required Duration anchor,
  required Duration elapsed,
  required Duration total,
}) {
  if (total <= Duration.zero) return Duration.zero;
  final raw = (anchor + elapsed).inMicroseconds;
  return Duration(microseconds: raw % total.inMicroseconds);
}
