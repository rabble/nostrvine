// ABOUTME: Riverpod provider for Clip Manager state management
// ABOUTME: Manages recorded video clips with modern Notifier pattern

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

final clipManagerProvider =
    NotifierProvider<ClipManagerNotifier, ClipManagerState>(
      ClipManagerNotifier.new,
    );

/// Manages recorded video clips for the video editor.
///
/// Handles clip recording, organization, and state management including:
/// - Recording timer and duration tracking
/// - Clip addition, deletion, and reordering
/// - Thumbnail and metadata updates
/// - Draft and library persistence
class ClipManagerNotifier extends Notifier<ClipManagerState> {
  int _clipCounter = 0;
  Timer? _recordingDurationTimer;
  final _recordStopwatch = Stopwatch();
  final List<RecordingClip> _clips = [];

  /// Returns an unmodifiable view of all clips.
  List<RecordingClip> get clips => List.unmodifiable(_clips);

  /// Calculates the remaining recording time available.
  ///
  /// Returns the difference between [maxDuration] and the sum of all clip
  /// durations.
  Duration get remainingDuration {
    final totalDuration = _clips.fold<Duration>(
      Duration.zero,
      (sum, clip) => sum + clip.duration,
    );
    return VideoEditorConstants.maxDuration - totalDuration;
  }

  @override
  ClipManagerState build() {
    ref.onDispose(() {
      _recordingDurationTimer?.cancel();
      _recordStopwatch.stop();
      _clips.clear();
      Log.debug(
        '🧹 ClipManagerNotifier disposed',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    });
    return ClipManagerState();
  }

  /// Trigger autosave via VideoEditorProvider (debounced).
  void _triggerAutosave() {
    ref.read(videoEditorProvider.notifier).triggerAutosave();
  }

  /// Force immediate autosave without debounce.
  /// Use this before file cleanup to ensure references are updated.
  Future<void> _forceAutosave() =>
      ref.read(videoEditorProvider.notifier).autosaveChanges();

  /// Manually trigger a state refresh with current clips.
  ///
  /// Forces a rebuild of consumers without modifying clip data.
  void refreshClips() {
    state = state.copyWith(clips: List.unmodifiable(_clips));
    Log.debug(
      '🔄 Refreshed clips state',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Start recording timer for active clip duration tracking.
  void startRecording() {
    _recordStopwatch
      ..reset()
      ..start();

    Log.debug(
      '▶️  Recording timer started',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    // Update activeRecordingDuration every 16ms (~60fps).
    // We ONLY rebuild with that logic, the progress inside of the segment-bar.
    _recordingDurationTimer = Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
      if (_recordStopwatch.isRunning) {
        state = state.copyWith(
          activeRecordingDuration: _recordStopwatch.elapsed,
        );
      }
    });
  }

  /// Stop recording timer and freeze duration.
  void stopRecording() {
    _recordStopwatch.stop();
    _recordingDurationTimer?.cancel();

    Log.debug(
      '⏸️  Recording timer stopped at '
      '${_recordStopwatch.elapsed.inMilliseconds}ms',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Reset recording stopwatch to zero.
  void resetRecording() {
    _recordStopwatch.reset();
    Log.debug(
      '🔄 Recording timer reset',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Add a new recorded clip to the list.
  ///
  /// If the clip duration exceeds [remainingDuration], it will be automatically
  /// trimmed to fit within the max duration limit. The trimming happens
  /// asynchronously in the background while the clip is displayed immediately.
  ///
  /// Returns the created clip with unique ID.
  RecordingClip addClip({
    required EditorVideo video,
    required double originalAspectRatio,
    required model.AspectRatio targetAspectRatio,
    Duration? duration,
    String? thumbnailPath,
  }) {
    final clipDuration =
        duration ??
        Duration(microseconds: _recordStopwatch.elapsedMicroseconds);
    final remainingDuration = this.remainingDuration;

    // Check if clip needs to be trimmed to fit within max duration
    final isClipToLong = clipDuration > remainingDuration;

    // Create a completer to track async trimming progress
    final processingCompleter = isClipToLong ? Completer<bool>() : null;

    final clip = RecordingClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}_${_clipCounter++}',
      video: video,
      duration: isClipToLong ? remainingDuration : clipDuration,
      recordedAt: .now(),
      thumbnailPath: thumbnailPath,
      targetAspectRatio: targetAspectRatio,
      originalAspectRatio: originalAspectRatio,
      processingCompleter: processingCompleter,
    );

    // Asynchronously trim the clip if it exceeds remaining duration
    if (isClipToLong) {
      unawaited(
        VideoEditorRenderService.limitClipDuration(
          clip: clip,
          duration: remainingDuration,
          onComplete: (success) async {
            if (!ref.mounted) return;
            processingCompleter!.complete(success);
            refreshClip(clip);
          },
        ),
      );
    }

    _clips.add(clip);
    Log.info(
      '📎 Added clip: ${clip.id}, duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    if (duration == null) {
      resetRecording();
    }
    state = state.copyWith(
      clips: List.unmodifiable(_clips),
      activeRecordingDuration: .zero,
    );

    _triggerAutosave();
    return clip;
  }

  /// Insert a clip at a specific position.
  ///
  /// Adds [clip] at [index], shifting subsequent clips forward.
  /// Returns the inserted clip.
  RecordingClip insertClip(int index, RecordingClip clip) {
    _clips.insert(index, clip);
    Log.info(
      '📎 Insert clip: ${clip.id}, '
      'position: $index '
      'duration: ${clip.durationInSeconds}s',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));

    _triggerAutosave();
    return clip;
  }

  /// Add multiple clips at once (e.g., from draft restoration).
  ///
  /// Appends all clips to the end of the current clip list and updates state.
  /// Used when restoring drafts or importing multiple clips from library.
  void addMultipleClips(List<RecordingClip> clips) {
    if (clips.isEmpty) {
      Log.debug(
        '📎 No clips to add - empty list provided',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }

    final previousCount = _clips.length;
    _clips.addAll(clips);

    Log.info(
      '📎 Added ${clips.length} clips '
      '($previousCount → ${_clips.length} total)',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));
    _triggerAutosave();
  }

  /// Delete a clip by ID.
  ///
  /// Returns true if the clip was successfully deleted, false if not found.
  /// Also deletes associated files if not referenced elsewhere.
  Future<bool> removeClipById(String clipId) async {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) {
      Log.warning(
        '⚠️ Cannot delete - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return false;
    }

    final clip = _clips[index];
    _clips.removeAt(index);
    Log.info(
      '🗑️  Deleted clip: $clipId (${_clips.length} remaining)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = state.copyWith(clips: List.unmodifiable(_clips));

    // Force immediate autosave so draft references are updated before cleanup
    await _forceAutosave();

    // Delete files only if not referenced by drafts or clip library
    await FileCleanupService.deleteRecordingClipFiles(clip);

    return true;
  }

  /// Reorder a single clip from oldIndex to newIndex.
  ///
  /// Moves the clip at [oldIndex] to [newIndex], shifting other clips
  /// accordingly.
  void reorderClip(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _clips.length ||
        newIndex < 0 ||
        newIndex >= _clips.length) {
      Log.warning(
        '⚠️ Invalid reorder indices: $oldIndex → $newIndex '
        '(length: ${_clips.length})',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }

    if (oldIndex == newIndex) return;

    final clip = _clips.removeAt(oldIndex);
    _clips.insert(newIndex, clip);

    Log.info(
      '📎 Reordered clip ${clip.id}: $oldIndex → $newIndex',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    state = state.copyWith(clips: List.unmodifiable(_clips));
    _triggerAutosave();
  }

  /// Update thumbnail path for a clip.
  void updateThumbnail({
    required String clipId,
    required String thumbnailPath,
    required Duration thumbnailTimestamp,
  }) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(
        thumbnailPath: thumbnailPath,
        thumbnailTimestamp: thumbnailTimestamp,
      );
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🖼️  Updated thumbnail for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update thumbnail - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Update duration for a clip (from metadata extraction).
  void updateClipDuration(String clipId, Duration duration) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(duration: duration);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '⏱️  Updated duration for clip: $clipId → ${duration.inMilliseconds}ms',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update duration - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Update video for a clip (e.g., after trimming or editing).
  ///
  /// Replaces the EditorVideo instance for the clip with [clipId].
  void updateClipVideo(String clipId, EditorVideo video) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(video: video);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🎬 Updated video for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update video - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Update thumbnail path for a clip.
  ///
  /// Alternative method to [updateThumbnail] with same functionality.
  void updateClipThumbnail(String clipId, String thumbnailPath) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index] = _clips[index].copyWith(thumbnailPath: thumbnailPath);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '🖼️  Updated thumbnail for clip: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot update thumbnail - clip not found: $clipId',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Refresh an existing clip with new data.
  ///
  /// Replaces the entire clip instance at the matching ID position.
  void refreshClip(
    RecordingClip clip, {
    String? newId,
    bool createNewClipId = false,
  }) {
    final index = _clips.indexWhere((c) => c.id == clip.id);
    if (index != -1) {
      final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
      final newClipId = newId ?? (createNewClipId ? timestamp : null);

      _clips[index] = clip.copyWith(id: newClipId);
      state = state.copyWith(clips: List.unmodifiable(_clips));
      Log.debug(
        '⏱️  Refreshed clip: ${clip.id}',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Cannot refresh - clip not found: ${clip.id}',
        name: 'ClipManagerNotifier',
        category: .video,
      );
    }
    _triggerAutosave();
  }

  /// Select a clip for editing.
  ///
  /// Sets the currently selected clip ID. Pass null to deselect.
  void selectClip(String? clipId) {
    state = state.copyWith(selectedClipId: clipId);
    Log.debug(
      clipId == null ? '🔽 Deselected clip' : '🔼 Selected clip: $clipId',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  /// Remove the most recent clip (undo last recording).
  ///
  /// Safely removes only the last clip if any exist, otherwise logs debug
  /// message.
  Future<void> removeLastClip() async {
    if (_clips.isEmpty) {
      Log.debug(
        '⚠️ Cannot remove last clip - no clips available',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return;
    }
    final lastClip = _clips.last;
    Log.info(
      '↩️  Removing last clip: ${lastClip.id}',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    await removeClipById(lastClip.id);
  }

  /// Remove all clips and reset state.
  ///
  /// Clears all recorded clips and resets to initial state.
  /// Also deletes the autosave draft and associated files.
  Future<void> clearAll() async {
    final clipCount = _clips.length;
    _clips.clear();
    Log.info(
      '🗑️  Cleared all clips (removed $clipCount clips)',
      name: 'ClipManagerNotifier',
      category: .video,
    );
    state = ClipManagerState();

    // Delete autosave draft and its associated files
    final draftService = DraftStorageService();
    await draftService.deleteDraft(VideoEditorConstants.autoSaveId);
  }

  /// Save clip(s) to library.
  ///
  /// Iterates through all clips and saves them to the persistent clip library.
  /// Continues saving remaining clips even if individual saves fail.
  Future<bool> saveClipsToLibrary() async {
    Log.info(
      '💾 Starting to save ${_clips.length} clips to library',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    try {
      // IMPORTANT: Do not change to Future.wait or parallel execution.
      // Sequential saving ensures each clip is fully persisted before the next,
      // preventing file conflicts and ensuring data integrity.
      for (final clip in _clips) {
        await saveClipToLibrary(clip);
      }

      Log.info(
        '💾 Successfully saved clips to library',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to save clips to library: $e',
        name: 'ClipManagerNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Save specific clip to library.
  ///
  /// Returns true if the clip was successfully saved, false otherwise.
  Future<bool> saveClipToLibrary(RecordingClip clip) async {
    Log.info(
      '💾 Starting to save clip to library',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    try {
      final clipService = ref.read(clipLibraryServiceProvider);

      final savedClip = SavedClip(
        id: clip.id,
        aspectRatio: clip.targetAspectRatio.name,
        createdAt: DateTime.now(),
        duration: clip.duration,
        filePath: await clip.video.safeFilePath(),
        thumbnailPath: clip.thumbnailPath,
      );
      await clipService.saveClip(savedClip);

      Log.debug(
        '✅ Saved clip ${clip.id} to library (${clip.durationInSeconds}s)',
        name: 'ClipManagerNotifier',
        category: .video,
      );

      Log.info(
        '💾 Successfully saved clip to library',
        name: 'ClipManagerNotifier',
        category: .video,
      );
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to save clip ${clip.id}: $e',
        name: 'ClipManagerNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
