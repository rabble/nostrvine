import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

extension VideoEditorHistoryExtensions on StateManager {
  List<AudioEvent> get audioTracks {
    final raw = activeMeta[VideoEditorConstants.audioStateHistoryKey];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>().map(AudioEvent.fromJson).toList();
  }

  /// Restores timeline marker positions from the current history metadata.
  List<Duration> get timelineMarkers {
    final raw = activeMeta[VideoEditorConstants.timelineMarkersStateHistoryKey];
    if (raw is! List) return [];

    return raw
        .whereType<num>()
        .map((value) => Duration(milliseconds: value.round()))
        .toList()
      ..sort();
  }

  /// Restores [DivineVideoClip] objects from the current history entry's
  /// metadata.
  ///
  /// [documentsPath] is required to resolve relative file paths stored in
  /// the serialized JSON back to absolute paths.
  /// The list order represents the clip playback order.
  List<DivineVideoClip> clipSnapshots(String documentsPath) {
    final raw = activeMeta[VideoEditorConstants.clipsStateHistoryKey];
    if (raw is! List) return [];
    return raw
        .cast<Map<String, dynamic>>()
        .map((json) => DivineVideoClip.fromJson(json, documentsPath))
        .toList();
  }
}
