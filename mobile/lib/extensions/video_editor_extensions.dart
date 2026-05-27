import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
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
      startTime: startTime,
      endTime: endTime ?? Duration.zero,
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
    } else {
      // Mutate the meta map in-place so the current history entry is updated
      // directly — matching how setLayerTimeline mutates activeLayers
      // in-place when skipUpdateHistory is true.
      stateManager.activeMeta[VideoEditorConstants.audioStateHistoryKey] =
          audioTracks.map((e) => e.toJson()).toList();
    }
    setState(() {});
  }

  /// Persists updated audio track volumes in the editor's history metadata.
  ///
  /// Creates a new undo point with the given [audioTracks] list.  Use this
  /// when only volume has changed and no start/end-time move is in progress.
  void setSoundVolumes(List<AudioEvent> audioTracks) {
    addHistory(
      meta: {
        ...stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: audioTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    setState(() {});
  }

  /// Persists timeline marker positions in the editor's history metadata.
  void setTimelineMarkers(List<Duration> markers) {
    addHistory(
      meta: {
        ...stateManager.activeMeta,
        VideoEditorConstants.timelineMarkersStateHistoryKey: markers
            .map((marker) => marker.inMilliseconds)
            .toList(),
      },
    );
    setState(() {});
  }

  /// Persists both clip and audio-track volumes in a single history entry.
  ///
  /// Canonical history write for volume changes. Creates one undo point that
  /// captures both tracks, whether a single volume source changed or clips and
  /// audio volumes were updated together (e.g. mute-all toggle).
  void setVolumeState({
    required List<DivineVideoClip> clips,
    required List<AudioEvent> audioTracks,
  }) {
    addHistory(
      meta: {
        ...stateManager.activeMeta,
        VideoEditorConstants.clipsStateHistoryKey: clips
            .map((c) => c.toJson())
            .toList(),
        VideoEditorConstants.audioStateHistoryKey: audioTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    setState(() {});
  }

  /// Persists clip trim and order state in the editor's history metadata.
  ///
  /// When [skipUpdateHistory] is `false` (default), creates a new history
  /// entry (undo point). When `true`, mutates the current meta in-place
  /// — use this during ongoing drags to keep the meta current without
  /// polluting the undo stack.
  void setClipState(
    List<DivineVideoClip> clips, {
    bool skipUpdateHistory = false,
  }) {
    final serialized = clips.map((c) => c.toJson()).toList();

    if (!skipUpdateHistory) {
      addHistory(
        meta: {
          ...stateManager.activeMeta,
          VideoEditorConstants.clipsStateHistoryKey: serialized,
        },
      );
    } else {
      stateManager.activeMeta[VideoEditorConstants.clipsStateHistoryKey] =
          serialized;
    }
    setState(() {});
  }
}
