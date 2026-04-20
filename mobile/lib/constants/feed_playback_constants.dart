/// Constants governing Vine-style loop enforcement during feed playback.
///
/// These are intentionally separate from `VideoEditorConstants.maxDuration`
/// (the recording/editor cap). Capture-time limits and playback loop
/// semantics are distinct product concerns — coupling them means a single
/// change to the editor (e.g. raising the capture ceiling) silently
/// reshapes every feed in the app.
class FeedPlaybackConstants {
  FeedPlaybackConstants._();

  /// Maximum playback window before force-seeking back to zero on videos
  /// that are materially longer than a Vine loop.
  ///
  /// Matches the original Vine loop length (~6s with a small buffer).
  /// Only enforced when the underlying video is longer than
  /// [maxLoopDuration] by more than [loopTolerance] — see
  /// [shouldEnforceLoopSeek].
  static const maxLoopDuration = Duration(milliseconds: 6300);

  /// Tail grace period near the natural end of a video during which we
  /// do NOT force a seek to zero.
  ///
  /// Why: feed videos occasionally clock in just over [maxLoopDuration]
  /// due to encoder/transcoder drift (e.g. a 6.4s file produced from a
  /// 6.3s capture). Without this tolerance the final ~100-200 ms of
  /// playback gets clipped on every loop, which users perceive as "the
  /// video restarts early" (see divinevideo/divine-mobile#1845).
  static const loopTolerance = Duration(milliseconds: 500);

  /// Returns `true` when loop enforcement should force a seek to zero for
  /// a video at [position], given its natural [duration].
  ///
  /// Returns `false` when the natural end is within [tolerance] of the
  /// current position. In that case the native player loop wraps cleanly
  /// and preserves the last frames.
  ///
  /// When [duration] is unknown (zero), falls back to enforcing the cap
  /// — the safer default for metadata-less streams.
  static bool shouldEnforceLoopSeek({
    required Duration position,
    required Duration duration,
    Duration maxLoop = maxLoopDuration,
    Duration tolerance = loopTolerance,
  }) {
    if (position < maxLoop) return false;
    if (duration.inMilliseconds <= 0) return true;
    return (duration - position) > tolerance;
  }
}
