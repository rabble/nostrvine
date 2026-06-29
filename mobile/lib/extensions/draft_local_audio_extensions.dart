import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';

/// Extraction of draft-local audio file paths for draft-delete cleanup.
extension DraftLocalAudioPaths on DivineVideoDraft {
  /// Absolute file paths of draft-local audio referenced by this draft.
  ///
  /// Covers imported audio created by `LocalAudioImportService` (stored under
  /// `draft_audio_imports/<draftId>`) and committed voice-over recordings, both
  /// persisted as draft-local [AudioEvent]s. Sweeps every history entry's audio
  /// metadata in [DivineVideoDraft.editorStateHistory] plus the legacy
  /// [DivineVideoDraft.selectedSound], collecting [AudioEvent.localFilePath] for
  /// each [AudioEvent.isLocalImport] track. Used by draft deletion to remove
  /// audio files that would otherwise persist after the draft is gone.
  Set<String> get localAudioFilePaths {
    final paths = <String>{};

    void addIfLocal(AudioEvent event) {
      // localFilePath is non-null only for a local import with a non-empty
      // url, so the null check alone covers the import and emptiness guards.
      final path = event.localFilePath;
      if (path != null) {
        paths.add(path);
      }
    }

    final selected = selectedSound;
    if (selected != null) addIfLocal(selected);

    final history = editorStateHistory['history'];
    if (history is! Iterable) return paths;

    for (final item in history) {
      if (item is! Map) continue;
      final meta = item['meta'];
      if (meta is! Map) continue;
      final audio = meta[VideoEditorConstants.audioStateHistoryKey];
      if (audio is! Iterable) continue;
      for (final raw in audio) {
        if (raw is! Map) continue;
        try {
          addIfLocal(AudioEvent.fromJson(Map<String, dynamic>.from(raw)));
        } catch (_) {
          // Skip malformed audio entries; cleanup must never throw.
        }
      }
    }

    return paths;
  }
}
