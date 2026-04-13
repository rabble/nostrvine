import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

extension VideoEditorHistoryExtensions on StateManager {
  List<AudioTrack> get audioTracks {
    final raw = activeMeta[VideoEditorConstants.audioStateHistoryKey];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>().map((map) {
      final sound = AudioEvent.fromJson(map);
      return AudioTrack(
        id: sound.id,
        title: sound.title ?? '',
        subtitle: sound.source ?? '',
        duration: Duration(seconds: sound.duration?.toInt() ?? 0),
        audio: sound.isBundled
            ? EditorAudio.asset(sound.assetPath!)
            : EditorAudio.network(sound.url!),
        startTime: sound.startOffset,
        volumeBalance: sound.volume,
      );
    }).toList();
  }
}
