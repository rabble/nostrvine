import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart' hide AudioTrack;

extension VideoEditorExtensions on ProImageEditorState {
  void setSoundTimeline({
    required int index,
    Duration? startTime,
    Duration? endTime,
    Duration? startOffset,
    Map<String, dynamic>? meta,
    bool skipUpdateHistory = false,
    bool clearAnchor = false,
  }) {
    final audioTracks = skipUpdateHistory
        ? stateManager.audioTracks
        : List<AudioEvent>.from(stateManager.audioTracks);
    if (index < 0 || index >= audioTracks.length) return;

    audioTracks[index] = audioTracks[index].copyWith(
      startTime: startTime,
      endTime: endTime ?? Duration.zero,
      startOffset: startOffset,
      // A manual move detaches the track from its source clip so it stops
      // following clip trims and behaves as an independent track.
      clearAnchorClipId: clearAnchor,
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
    List<Duration>? timelineMarkers,
  }) {
    final serialized = clips.map((c) => c.toJson()).toList();

    // Keep anchored (extracted, not-yet-moved) audio aligned to its source
    // clip after this clip edit, so trimming a clip's left edge produces a
    // J-Cut without losing sync. Only rewrite the audio key when a track
    // actually moved — `rebaseAnchoredAudioForClipState` returns the same
    // list instance otherwise.
    final currentTracks = stateManager.audioTracks;
    final rebasedTracks = rebaseAnchoredAudioForClipState(clips, currentTracks);
    final audioChanged = !identical(rebasedTracks, currentTracks);
    final serializedAudio = audioChanged
        ? rebasedTracks.map((e) => e.toJson()).toList()
        : null;

    final meta = {
      ...stateManager.activeMeta,
      VideoEditorConstants.clipsStateHistoryKey: serialized,
      VideoEditorConstants.audioStateHistoryKey: ?serializedAudio,
      if (timelineMarkers != null)
        VideoEditorConstants.timelineMarkersStateHistoryKey: timelineMarkers
            .map((marker) => marker.inMilliseconds)
            .toList(),
    };

    if (!skipUpdateHistory) {
      addHistory(meta: meta);
    } else {
      stateManager.activeMeta[VideoEditorConstants.clipsStateHistoryKey] =
          serialized;
      if (serializedAudio != null) {
        stateManager.activeMeta[VideoEditorConstants.audioStateHistoryKey] =
            serializedAudio;
      }
      if (timelineMarkers != null) {
        stateManager.activeMeta[VideoEditorConstants
            .timelineMarkersStateHistoryKey] = timelineMarkers
            .map((marker) => marker.inMilliseconds)
            .toList();
      }
    }
    setState(() {});
  }
}
