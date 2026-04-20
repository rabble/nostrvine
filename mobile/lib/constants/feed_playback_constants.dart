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
  static const maxLoopDuration = Duration(milliseconds: 6300);
}
