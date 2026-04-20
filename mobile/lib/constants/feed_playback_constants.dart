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
  /// Why: editor-captured clips land on the 6.3s cap exactly on the raw
  /// blob, but the 720p.mp4 derivative served to the feed reports a
  /// longer container duration because the aac audio track is padded to
  /// the next frame boundary past the video track. Measured on the
  /// `/<hash>/720p.mp4` assets cited in #1845: container = 6.339s,
  /// video stream = 6.300s, audio stream = 6.339s — a consistent ~39 ms
  /// overshoot. Pre-tolerance enforcement fires `seek(Duration.zero)` at
  /// `position >= 6.300s`, beating the native 6.339s EOS and clipping
  /// the final frame on every loop.
  ///
  /// 500 ms is generous versus the ~39 ms observed. The margin absorbs
  /// future transcoder variants (different aac frame sizes, different
  /// sample rates) without weakening the cap for long-form imports —
  /// anything with a natural duration > 6.8s still loops at 6.3s via
  /// [shouldEnforceLoopForDuration].
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
