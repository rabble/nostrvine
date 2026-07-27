import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/composition_duration.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart' hide AudioTrack;

/// Builds the editor history meta for appending [newTracks] after the audio
/// tracks already present in [existingTracks].
///
/// Merges over [activeMeta] and serializes both lists into the audio-state
/// key. Pure so the music-library and voice-over commit paths share one merge
/// instead of each duplicating the spread-and-serialize.
Map<String, dynamic> buildAppendedAudioMeta({
  required Map<String, dynamic> activeMeta,
  required Iterable<AudioEvent> existingTracks,
  required Iterable<AudioEvent> newTracks,
}) {
  return {
    ...activeMeta,
    VideoEditorConstants.audioStateHistoryKey: [
      ...existingTracks.map((track) => track.toJson()),
      ...newTracks.map((track) => track.toJson()),
    ],
  };
}

extension VideoEditorExtensions on ProImageEditorState {
  /// Captures the overlays currently over the composition — layers, colour
  /// filters, tune adjustments and blur — so they can be baked into a render
  /// mid-session.
  ///
  /// The export path gets the same data handed to it in `CompleteParameters`,
  /// but only once the user taps Done; anything that renders *during* editing
  /// (saving a single clip to the library) has to ask for it.
  ///
  /// Rasterizing the layers costs a frame, so only call this when a render is
  /// actually about to run.
  ///
  /// Passes the same `basePixelRatio` the Done/export path uses
  /// (`configs.imageGeneration.customPixelRatio`, the export-resolution ratio)
  /// so a layer baked into a saved clip is captured at the same resolution it
  /// would be in a full export, not the lower device pixel ratio the bare call
  /// would fall back to. Global transforms are deliberately *not* applied — a
  /// clip's own geometry is already baked into its file (#5322).
  Future<EditorOverlaySnapshot> captureOverlaySnapshot() async {
    final capturedLayers = await captureAllLayersWithMeta(
      basePixelRatio: configs.imageGeneration.customPixelRatio,
    );
    return EditorOverlaySnapshot(
      capturedLayers: capturedLayers,
      filterStates: List.of(stateManager.activeFilters),
      tuneAdjustments: List.of(stateManager.activeTuneAdjustments),
      blur: stateManager.activeBlur,
      bodySize: sizesManager.bodySize,
    );
  }

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
  }) => setClipAndAudioState(clips: clips, audioTracks: audioTracks);

  /// Persists clips and audio tracks in a single history entry.
  ///
  /// Use this when an edit changes both the clip list and the sound timeline
  /// so undo/redo restores the full timeline atomically.
  void setClipAndAudioState({
    required List<DivineVideoClip> clips,
    required List<AudioEvent> audioTracks,
    List<Duration>? timelineMarkers,
  }) {
    addHistory(
      meta: {
        ..._clipHistoryMeta(clips, timelineMarkers: timelineMarkers),
        VideoEditorConstants.audioStateHistoryKey: audioTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    setState(() {});
  }

  /// Persists a clip-list change that can make the composition longer, growing
  /// any audio window that covered the old end onto the new one (#6401).
  ///
  /// [previousClips] is the composition as it stood *before* the edit, so the
  /// grow can tell a window that ran to the end from one the user trimmed
  /// short. Falls back to a plain [setClipState] when no window moved, so an
  /// edit over a soundless composition does not start writing an audio key
  /// into every history entry.
  ///
  /// Use this from every commit that can lengthen the composition — the
  /// stop-motion frame-list commit, the camera/clips-picker sync, duplicating
  /// a clip, slowing a clip down, and dragging a trim handle back out. The
  /// grow is one-way: a later shrink leaves the window overhanging, and the
  /// sound strip's trim handle is the affordance for pulling it back.
  /// Deliberately *not* folded into [setClipState] itself: that is the
  /// generic clip writer with no previous-clip list to compare against, and
  /// the transition path measures its output with `TransitionTimelineMap`
  /// rather than a plain sum of playback durations.
  void setLengthenedClipState({
    required List<DivineVideoClip> previousClips,
    required List<DivineVideoClip> clips,
    List<Duration>? timelineMarkers,
  }) {
    final currentTracks = stateManager.audioTracks;
    final grownTracks = growAudioToCompositionEnd(
      rebaseAnchoredAudioForClipState(clips, currentTracks),
      previousDuration: compositionDuration(previousClips),
      duration: compositionDuration(clips),
      maxDuration: VideoEditorConstants.maxDuration,
    );

    if (identical(grownTracks, currentTracks)) {
      setClipState(clips, timelineMarkers: timelineMarkers);
      return;
    }
    setClipAndAudioState(
      clips: clips,
      audioTracks: grownTracks,
      timelineMarkers: timelineMarkers,
    );
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
    // actually moved - `rebaseAnchoredAudioForClipState` returns the same
    // list instance otherwise.
    final currentTracks = stateManager.audioTracks;
    final rebasedTracks = rebaseAnchoredAudioForClipState(clips, currentTracks);
    final audioChanged = !identical(rebasedTracks, currentTracks);
    final serializedAudio = audioChanged
        ? rebasedTracks.map((e) => e.toJson()).toList()
        : null;

    final meta = _clipHistoryMeta(
      clips,
      serializedClips: serialized,
      serializedAudio: serializedAudio,
      timelineMarkers: timelineMarkers,
    );

    if (!skipUpdateHistory) {
      addHistory(meta: meta);
    } else {
      stateManager.activeMeta[VideoEditorConstants.clipsStateHistoryKey] =
          serialized;
      if (serializedAudio != null) {
        stateManager.activeMeta[VideoEditorConstants.audioStateHistoryKey] =
            serializedAudio;
      }
      stateManager.activeMeta[VideoEditorConstants
              .timelineMarkersStateHistoryKey] =
          meta[VideoEditorConstants.timelineMarkersStateHistoryKey];
    }
    setState(() {});
  }

  Map<String, dynamic> _clipHistoryMeta(
    List<DivineVideoClip> clips, {
    List<Map<String, dynamic>>? serializedClips,
    List<Map<String, dynamic>>? serializedAudio,
    List<Duration>? timelineMarkers,
  }) {
    final markers = timelineMarkers ?? stateManager.timelineMarkers;
    return {
      ...stateManager.activeMeta,
      VideoEditorConstants.clipsStateHistoryKey:
          serializedClips ?? clips.map((c) => c.toJson()).toList(),
      VideoEditorConstants.audioStateHistoryKey: ?serializedAudio,
      VideoEditorConstants.timelineMarkersStateHistoryKey: markers
          .map((marker) => marker.inMilliseconds)
          .toList(),
    };
  }
}
