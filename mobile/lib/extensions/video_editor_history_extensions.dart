import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

extension VideoEditorHistoryExtensions on StateManager {
  List<AudioEvent> get audioTracks {
    final raw = activeMeta[VideoEditorConstants.audioStateHistoryKey];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>().map(AudioEvent.fromJson).toList();
  }
}
