import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:pro_image_editor/pro_image_editor.dart' hide AudioTrack;

extension VideoEditorExtensions on ProImageEditorState {
  void setSoundTimeline({
    required int index,
    Duration? startTime,
    Duration? endTime,
    Map<String, dynamic>? meta,
    bool skipUpdateHistory = false,
  }) {
    final audioTracks = skipUpdateHistory
        ? stateManager.audioTracks
        : List<AudioEvent>.from(stateManager.audioTracks);
    if (index < 0 || index >= audioTracks.length) return;

    audioTracks[index] = audioTracks[index].copyWith(
      startOffset: startTime,
      duration:
          ((endTime ?? Duration.zero) - (startTime ?? Duration.zero))
              .inMilliseconds /
          1000,
    );

    if (!skipUpdateHistory) {
      addHistory(
        meta: {
          ...stateManager.activeMeta,
          VideoEditorConstants.audioStateHistoryKey: audioTracks
              .map((e) => e.toJson())
              .toList(),
        },
      );
    }
    setState(() {});
  }
}
