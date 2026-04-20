/// Constants governing Vine-style loop enforcement during feed playback.
///
/// These are intentionally separate from `VideoEditorConstants.maxDuration`
/// (the recording/editor cap). Capture-time limits and playback loop
/// semantics are distinct product concerns — coupling them means a single
/// change to the editor (e.g. raising the capture ceiling) silently
/// reshapes every feed in the app.
class FeedPlaybackConstants {
  FeedPlaybackConstants._(); // coverage:ignore-line

  /// Maximum playback window before force-seeking back to zero on videos
  /// that are materially longer than a Vine loop.
  ///
  /// Value: 6.3 s = original 6 s Vine loop length + 300 ms tail buffer. The
  /// buffer is forgiving for natural duration variation (encoder drift,
  /// transcode padding on derivative assets) so content authored at the 6 s
  /// intent isn't clipped by a tight cap.
  ///
  /// Applies to every video surfaced in feed — new captures trimmed by the
  /// editor, imported videos, and legacy uploads alike. That scope is what
  /// makes this distinct from `VideoEditorConstants.maxDuration`, which only
  /// gates in-app recording.
  static const maxLoopDuration = Duration(milliseconds: 6300);
}
