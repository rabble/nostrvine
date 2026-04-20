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
  /// [shouldEnforceLoopForDuration].
  static const maxLoopDuration = Duration(milliseconds: 6300);

  /// Tail grace period above [maxLoopDuration] in which the natural end
  /// of the video is still honored instead of force-seeking to zero.
  ///
  /// Why: editor-captured clips land on the 6.3s cap exactly, and
  /// transcoder drift can push the container a few hundred milliseconds
  /// past it (e.g. a 6.4s file produced from a 6.3s capture). Without
  /// this margin the final ~0-300 ms gets clipped on every loop, which
  /// users perceive as "the video restarts early"
  /// (see divinevideo/divine-mobile#1845).
  static const loopTolerance = Duration(milliseconds: 500);

  /// Returns `true` when feed loop enforcement should seek to zero on
  /// videos of this natural [duration] once playback passes [maxLoop].
  ///
  /// The decision is a property of the video, not of the current
  /// playback position: any video with `duration > maxLoop + tolerance`
  /// is long enough that the Vine loop cap has to apply; anything
  /// at-or-below that threshold is short enough that the native player
  /// can wrap the loop on its own without clipping the final frames.
  ///
  /// When [duration] is unknown (zero), falls back to enforcing the cap
  /// — the safer default for metadata-less streams.
  static bool shouldEnforceLoopForDuration({
    required Duration duration,
    Duration maxLoop = maxLoopDuration,
    Duration tolerance = loopTolerance,
  }) {
    if (duration.inMilliseconds <= 0) return true;
    return duration > maxLoop + tolerance;
  }
}
