/// Constants for the video editor feature.
class VideoEditorConstants {
  /// Key used to identify autosaved drafts in storage.
  static String autoSaveId = 'draft_autosave';

  /// Maximum number of tags allowed per video.
  static int tagLimit = 1 << 30; // ~1 billion

  /// Whether to enforce the tag limit in the UI.
  static bool enableTagLimit = false;

  /// Maximum recording duration for videos.
  static const maxDuration = Duration(seconds: 6, milliseconds: 300);
}
