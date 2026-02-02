// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

final videoEditorProvider =
    NotifierProvider<VideoEditorNotifier, VideoEditorProviderState>(
      VideoEditorNotifier.new,
    );

/// Manages video editor state and operations.
///
/// Handles:
/// - Draft loading and saving
/// - Clip selection and navigation
/// - Clip editing (splitting, trimming)
/// - Playback control
/// - Video rendering and export
/// - Metadata management
class VideoEditorNotifier extends Notifier<VideoEditorProviderState> {
  /// Debounce duration for metadata autosave to prevent excessive saves.
  static const Duration _autosaveDebounce = Duration(milliseconds: 800);

  /// Current draft ID for save/load operations.
  @visibleForTesting
  String? draftId;

  Timer? _autosaveTimer;

  /// Get clip manager notifier.
  ClipManagerNotifier get _clipManager =>
      ref.read(clipManagerProvider.notifier);

  /// Get clips from clip manager.
  List<RecordingClip> get _clips => ref.read(clipManagerProvider).clips;

  // === LIFECYCLE ===

  @override
  VideoEditorProviderState build() {
    ref.onDispose(() {
      _autosaveTimer?.cancel();
      Log.debug(
        '🧹 VideoEditorNotifier disposed',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    });
    return VideoEditorProviderState();
  }

  /// Initialize the video editor with an optional draft.
  ///
  /// Loads existing draft data if [draftId] is provided, including clips
  /// and metadata.
  Future<void> initialize({String? draftId}) async {
    // Reset old editing states but keep metadata
    state = state.copyWith(
      currentClipIndex: 0,
      isEditing: false,
      isReordering: false,
      isProcessing: false,
      isSavingDraft: false,
      isPlaying: false,
      hasPlayedOnce: false,
      isOverDeleteZone: false,
      currentPosition: .zero,
    );

    // If the editor screen is opened from a draft, we initialize it here.
    if (draftId != null && draftId.isNotEmpty) {
      await restoreDraft(draftId);
    } else {
      Log.info(
        '🎬 Initializing video editor (no draft)',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
    this.draftId = draftId ?? 'Draft_${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Reset editor state and metadata to defaults.
  ///
  /// Also cancels any pending autosave and deletes the autosaved draft.
  Future<void> reset() async {
    Log.debug(
      '🔄 Resetting editor state',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = VideoEditorProviderState();
    _autosaveTimer?.cancel();

    unawaited(removeAutosavedDraft());
  }

  // === CLIP SELECTION & NAVIGATION ===

  /// Select a clip by index and update the current position.
  ///
  /// Calculates the playback offset based on previous clips' durations.
  void selectClipByIndex(int index) {
    if (index < 0 || index >= _clips.length) return;

    // Calculate offset from all previous clips
    final offset = _clips
        .take(index)
        .fold(Duration.zero, (sum, clip) => sum + clip.duration);

    Log.debug(
      '🎯 Selected clip $index (offset: ${offset.inSeconds}s)',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    state = state.copyWith(
      currentClipIndex: index,
      isPlaying: false,
      isPlayerReady: false,
      hasPlayedOnce: false,
      currentPosition: offset,
      splitPosition: .zero,
    );
  }

  // === CLIP EDITING MODE ===

  /// Enter editing mode for the currently selected clip.
  ///
  /// Resets trim position to zero when entering edit mode.
  void startClipEditing() {
    Log.info(
      '✂️ Started editing clip ${state.currentClipIndex}',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(
      isEditing: true,
      isPlaying: false,
      splitPosition: _clips[state.currentClipIndex].duration ~/ 2,
    );
  }

  /// Exit editing mode for the currently selected clip.
  void stopClipEditing() {
    Log.info(
      '✅ Stopped editing clip ${state.currentClipIndex}',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isEditing: false, isPlaying: false);
  }

  /// Toggle between editing and viewing mode for the current clip.
  ///
  /// Convenience method that calls [startClipEditing] or [stopClipEditing]
  /// based on current state.
  void toggleClipEditing() {
    if (state.isEditing) {
      stopClipEditing();
    } else {
      startClipEditing();
    }
  }

  /// Split the currently selected clip at the current split position.
  ///
  /// Creates two new clips and renders them in parallel. Both clips must
  /// meet the minimum duration requirement.
  Future<void> splitSelectedClip() async {
    final splitPosition = state.splitPosition;
    final selectedClip = _clips[state.currentClipIndex];

    // Validate split position
    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      splitPosition,
    )) {
      Log.warning(
        '⚠️ Invalid split position ${splitPosition.inSeconds}s - '
        'clips must be at least '
        '${VideoEditorSplitService.minClipDuration.inMilliseconds}ms',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      return;
    }

    Log.info(
      '✂️ Splitting clip ${selectedClip.id} at ${splitPosition.inSeconds}s',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    stopClipEditing();

    try {
      await VideoEditorSplitService.splitClip(
        sourceClip: selectedClip,
        splitPosition: splitPosition,
        onClipsCreated: (startClip, endClip) {
          // Add clips to UI immediately so processing status is visible
          _clipManager
            ..refreshClip(
              startClip.copyWith(id: selectedClip.id),
              newId: startClip.id,
            )
            ..insertClip(state.currentClipIndex + 1, endClip);
        },
        onThumbnailExtracted: (clip, thumbnailPath) {
          if (ref.mounted) {
            _clipManager.updateClipThumbnail(clip.id, thumbnailPath);
          }
        },
        onClipRendered: (clip, video) {
          if (ref.mounted) {
            _clipManager.updateClipVideo(clip.id, video);
            Log.debug(
              '✅ Clip rendered: ${clip.id}',
              name: 'VideoEditorNotifier',
              category: .video,
            );
          }
        },
      );

      Log.info(
        '✅ Successfully split clip into 2 segments',
        name: 'VideoEditorNotifier',
        category: .video,
      );

      await autosaveChanges();
    } catch (e) {
      Log.error(
        '❌ Failed to split clip: $e',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  // === CLIP REORDERING ===

  /// Start clip reordering mode for drag-and-drop operations.
  void startClipReordering() {
    Log.debug(
      '🔄 Started clip reordering mode',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isReordering: true, isPlaying: false);
  }

  /// Stop clip reordering mode and reset delete zone state.
  void stopClipReordering() {
    Log.debug(
      '✅ Stopped clip reordering mode',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isReordering: false, isOverDeleteZone: false);
  }

  /// Update whether a clip is being dragged over the delete zone.
  void setOverDeleteZone(bool isOver) {
    if (state.isOverDeleteZone != isOver) {
      Log.debug(
        isOver ? '🗑️  Clip over delete zone' : '⬅️  Clip left delete zone',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
    state = state.copyWith(isOverDeleteZone: isOver);
  }

  // === PLAYBACK CONTROL ===

  /// Pause video playback.
  ///
  /// Sets isPlaying to false without affecting other state.
  void pauseVideo() {
    Log.debug('⏸️ Paused video', name: 'VideoEditorNotifier', category: .video);
    state = state.copyWith(isPlaying: false);
  }

  /// Set whether the video player is ready for playback.
  ///
  /// Called by the video player widget when initialization completes or
  /// when the player is disposed.
  void setPlayerReady(bool isReady) {
    if (state.isPlayerReady == isReady) return;
    Log.debug(
      isReady ? '✅ Player ready' : '⏳ Player not ready',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isPlayerReady: isReady);
  }

  /// Mark that video has started playing (hides thumbnail).
  ///
  /// Called when video playback begins for the first time on current clip.
  void setHasPlayedOnce() {
    if (state.hasPlayedOnce) return;
    state = state.copyWith(hasPlayedOnce: true);
  }

  /// Toggle between playing and paused states.
  ///
  /// Convenience method to start/stop playback based on current state.
  /// Ignores play requests if the player is not yet ready.
  void togglePlayPause() {
    final newState = !state.isPlaying;
    Log.debug(
      newState ? '▶️ Playing video' : '⏸️ Paused video',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    // Prevent playing before player is initialized
    if (!state.isPlayerReady && newState) return;

    state = state.copyWith(isPlaying: newState);
  }

  /// Toggle audio mute state.
  ///
  /// Mutes or unmutes audio playback for the video editor.
  void toggleMute() {
    final newState = !state.isMuted;
    Log.debug(
      newState ? '🔇 Muted audio' : '🔊 Unmuted audio',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isMuted: newState);
  }

  /// Update the current playback position.
  ///
  /// In editing mode, uses absolute position within the clip.
  /// In viewing mode, adds offset from previous clips.
  void updatePosition(String clipId, Duration position) {
    // Ignore stale position updates from previous clip's controller
    if (clipId != _clips[state.currentClipIndex].id) {
      return; // Stale position from wrong controller
    }

    // Calculate offset from all previous clips
    final offset = state.isEditing
        ? Duration.zero
        : _clips
              .take(state.currentClipIndex)
              .fold(Duration.zero, (sum, clip) => sum + clip.duration);

    state = state.copyWith(
      currentPosition: Duration(
        milliseconds: (offset + position).inMilliseconds.clamp(
          0,
          VideoEditorConstants.maxDuration.inMilliseconds,
        ),
      ),
    );
  }

  /// Seek to a specific position within the trim range.
  ///
  /// Pauses playback and updates the split position marker.
  void seekToTrimPosition(Duration value) {
    state = state.copyWith(splitPosition: value, isPlaying: false);
  }

  // === METADATA ===

  /// Update video metadata (title, description, tags).
  ///
  /// Validates and enforces the 64KB size limit. Rejects updates that exceed
  /// the limit and sets metadataLimitReached flag.
  /// Update video metadata (title, description, tags).
  ///
  /// Validates and enforces the 64KB size limit. Rejects updates that exceed
  /// the limit and sets metadataLimitReached flag.
  ///
  /// Automatically extracts completed hashtags from title and description.
  /// A hashtag is considered complete when followed by a space or at the end
  /// of the string (e.g., "#hot " or "text #hot").
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    Log.debug(
      '📝 Updated video metadata',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    // Use raw values for hashtag extraction (before trim)
    final rawTitle = title ?? state.title;
    final rawDescription = description ?? state.description;

    // Trim for storage (but after hashtag extraction)
    final cleanedTitle = rawTitle.trim();
    final cleanedDescription = rawDescription.trim();
    final tagLimit = VideoEditorConstants.tagLimit;

    // Only extract hashtags when text changes, not when tags are manually edited
    final Set<String> allTags;
    if (tags != null) {
      // User manually edited tags - use only what they provided
      allTags = tags
          .map((tag) => tag.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))
          .where((tag) => tag.isNotEmpty)
          .take(tagLimit)
          .toSet();
    } else {
      // Text changed - compare old and new hashtags to only update changed ones
      final hashtagPattern = RegExp(r'#([a-zA-Z0-9]+)\s');

      // Extract hashtags from OLD text
      final oldText = '${state.title} ${state.description} ';
      final oldHashtags = hashtagPattern
          .allMatches(oldText)
          .map((m) => m.group(1))
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toSet();

      // Extract hashtags from NEW text
      final newText = '$rawTitle $rawDescription ';
      final newHashtags = hashtagPattern
          .allMatches(newText)
          .map((m) => m.group(1))
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toSet();

      // Find which hashtags were removed and which were added
      final removedHashtags = oldHashtags.difference(newHashtags);
      final addedHashtags = newHashtags.difference(oldHashtags);

      // Update tags: remove old ones, add new ones, keep manually added tags
      allTags = state.tags
          .difference(removedHashtags)
          .union(addedHashtags)
          .take(tagLimit)
          .toSet();
    }

    // Calculate total size in bytes (UTF-8 encoded)
    // Calculate total size
    const maxBytes = 64 * 1024; // 64KB
    final titleBytes = utf8.encode(cleanedTitle).length;
    final descriptionBytes = utf8.encode(cleanedDescription).length;
    final tagsBytes = allTags.isEmpty
        ? 0
        : allTags.fold<int>(0, (sum, tag) => sum + utf8.encode(tag).length);
    final totalBytes = titleBytes + descriptionBytes + tagsBytes;

    // Check if limit is exceeded
    if (totalBytes > maxBytes) {
      Log.warning(
        '⚠️ Metadata exceeds 64KB limit ($totalBytes bytes) - update rejected',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      state = state.copyWith(metadataLimitReached: true);
      return;
    }

    // Update metadata if within limit
    state = state.copyWith(
      title: cleanedTitle,
      description: cleanedDescription,
      tags: allTags,
      metadataLimitReached: false,
    );

    triggerAutosave();
  }

  /// Set video expiration time option.
  void setExpiration(VideoMetadataExpiration expiration) {
    state = state.copyWith(expiration: expiration);
    triggerAutosave();
  }

  /// Create a VineDraft from the rendered clip with metadata.
  VineDraft getActiveDraft({bool isAutosave = false}) {
    return VineDraft.create(
      id: isAutosave ? VideoEditorConstants.autoSaveId : draftId,
      clips: state.finalRenderedClip == null || isAutosave
          ? _clips
          : [state.finalRenderedClip!],
      title: state.title,
      description: state.description,
      hashtags: state.tags,
      allowAudioReuse: state.allowAudioReuse,
      expireTime: state.expiration.value,
      selectedApproach: 'video',
      editorStateHistory: state.editorStateHistory,
      editorEditingParameters: state.editorEditingParameters,
    );
  }

  // === EDITOR STATE PERSISTENCE ===

  /// Update the editor state history for undo/redo functionality.
  ///
  /// This stores the serialized state history from ProImageEditor,
  /// allowing users to restore their editing progress when reopening a draft.
  void updateEditorStateHistory(Map<String, dynamic> stateHistory) {
    Log.debug(
      '📜 Updated editor state history',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    state = state.copyWith(editorStateHistory: stateHistory);
    triggerAutosave();
  }

  /// Update the editor editing parameters (filters, drawings, etc.).
  ///
  /// This stores the serialized editing parameters from ProImageEditor,
  /// enabling restoration of all applied effects when reopening a draft.
  void updateEditorEditingParameters(Map<String, dynamic> editingParameters) {
    Log.debug(
      '🎨 Updated editor editing parameters',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    state = state.copyWith(editorEditingParameters: editingParameters);
    triggerAutosave();
  }

  // === DRAFT PERSISTENCE ===

  /// Set the draft ID for saving/loading.
  ///
  /// Associates this editing session with a persistent draft for auto-save.
  void setDraftId(String id) {
    Log.debug(
      '💾 Set draft ID: $id',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    draftId = id;
  }

  /// Trigger autosave with debounce to prevent excessive saves.
  ///
  /// Can be called from other providers (e.g., ClipManager) to trigger
  /// autosave after changes. Uses debouncing to batch rapid changes.
  void triggerAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      if (!ref.mounted) return;
      Log.debug(
        '💾 Triggering autosave',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
      autosaveChanges();
    });
  }

  /// Automatically save the current video project state.
  ///
  /// This method is typically called periodically or on significant changes
  /// to prevent data loss. Unlike [saveAsDraft], autosave uses a fixed
  /// [autoSaveId] to maintain a single recovery point.
  Future<bool> autosaveChanges() async {
    final clipCount = _clips.length;
    final hasTitle = state.title.isNotEmpty;

    Log.info(
      '💾 Autosaving draft (clips: $clipCount, has title: $hasTitle)',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      final draft = getActiveDraft(isAutosave: true);
      await draftService.saveDraft(draft);

      Log.info(
        '✅ Autosave completed - ${clipCount} clip(s), '
        'title: "${state.title.isEmpty ? "(empty)" : state.title}"',
        name: 'VideoEditorNotifier',
        category: .video,
      );

      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Autosave failed: $e',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Save the current video project as a draft.
  ///
  /// Persists clips and metadata to local storage for later editing.
  /// Returns `true` on success, `false` on failure.
  Future<bool> saveAsDraft() async {
    if (state.isSavingDraft) return false;

    state = state.copyWith(isSavingDraft: true);

    Log.info(
      '💾 Saving draft: $draftId',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      await draftService.saveDraft(getActiveDraft());

      // Remove the autosaved draft
      await removeAutosavedDraft();

      Log.info(
        '✅ Draft saved successfully: $draftId',
        name: 'VideoEditorNotifier',
        category: .video,
      );

      state = state.copyWith(isSavingDraft: false);
      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to save draft: $e',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isSavingDraft: false);
      return false;
    }
  }

  /// Restore a draft from local storage.
  ///
  /// Loads clips and metadata from the specified draft. If [draftId] is null,
  /// restores from [autoSaveId] to recover an autosaved session.
  Future<void> restoreDraft([String? draftId]) async {
    draftId ??= VideoEditorConstants.autoSaveId;
    Log.info(
      '🎬 Initializing video editor with draft ID: $draftId',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    final prefs = await SharedPreferences.getInstance();
    final draftService = DraftStorageService(prefs);
    final draft = await draftService.getDraftById(draftId);
    if (draft != null) {
      state = state.copyWith(
        title: draft.title,
        description: draft.description,
        tags: draft.hashtags,
        allowAudioReuse: draft.allowAudioReuse,
        expiration: VideoMetadataExpiration.fromDuration(draft.expireTime),
        editorStateHistory: draft.editorStateHistory,
        editorEditingParameters: draft.editorEditingParameters,
      );
      _clipManager.addMultipleClips(draft.clips);
      // We set the aspect ratio in the video recorder to match the clips,
      // so the user can't mix them up.
      ref
          .read(videoRecorderProvider.notifier)
          .setAspectRatio(draft.clips.first.targetAspectRatio);
      Log.info(
        '✅ Draft loaded with ${draft.clips.length} clip(s)',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Draft not found: $draftId',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  /// Delete the autosaved draft from local storage.
  ///
  /// Called when the user explicitly discards the autosaved session or
  /// after successfully publishing a video.
  Future<void> removeAutosavedDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);
      await draftService.deleteDraft(VideoEditorConstants.autoSaveId);
      Log.debug(
        '🗑️ Deleted autosaved draft',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete autosaved draft: $e',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  // === RENDERING & PUBLISHING ===

  /// Render all clips into final video and prepare for publishing.
  ///
  /// Combines all clips, applies audio settings, generates proofmode
  /// attestation, and creates the final rendered clip for publishing.
  Future<void> startRenderVideo() async {
    if (state.isProcessing) return;

    Log.info(
      '🎬 Starting final video render',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(isProcessing: true);

    // Render video and get proofmode data
    final (outputPath, proofManifestJson) = await _renderVideo();

    final validToPublish = outputPath != null;

    // Extract metadata from rendered video
    final metaData = validToPublish
        ? await ProVideoEditor.instance.getMetadata(
            EditorVideo.file(outputPath),
          )
        : null;

    if (!validToPublish) {
      Log.warning(
        '⚠️ Video render cancelled or failed',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      return;
    }

    Log.info(
      '✅ Video rendered successfully - duration: '
      '${metaData!.duration.inSeconds}s',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    // Create final clip for publishing
    final finalRenderedClip = RecordingClip(
      id: 'clip-${DateTime.now()}',
      video: EditorVideo.file(outputPath),
      duration: metaData.duration,
      recordedAt: .now(),
      originalAspectRatio: _clips.first.originalAspectRatio,
      targetAspectRatio: _clips.first.targetAspectRatio,
      thumbnailPath: _clips.first.thumbnailPath,
    );

    Log.info(
      '📤 Navigating to publish screen',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    state = state.copyWith(
      isProcessing: false,
      finalRenderedClip: finalRenderedClip,
    );
  }

  /// Cancel an ongoing video render operation.
  Future<void> cancelRenderVideo() async {
    try {
      Log.info(
        '⏹️ Cancelling video render',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      await ProVideoEditor.instance.cancel(_clips.first.id);
      Log.info(
        '✅ Video render cancelled',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } catch (e, stackTrace) {
      Log.error(
        '❌ Failed to cancel video render: $e',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
    }

    state = state.copyWith(isProcessing: false);
  }

  /// Publish the video to the Nostr network.
  ///
  /// Requires [finalRenderedClip] to be available. Throws [StateError] if
  /// no rendered clip exists.
  Future<void> postVideo(BuildContext context) async {
    if (state.finalRenderedClip == null) {
      Log.error(
        '❌ Cannot post video: no final rendered clip available',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      throw StateError('Cannot post video without a rendered clip');
    } else if (!state.isValidToPost) {
      Log.error(
        '❌ Cannot post video: metadata invalid '
        '(title empty: ${state.title.isEmpty}, '
        'limit reached: ${state.metadataLimitReached})',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      throw StateError('Cannot post video with invalid metadata');
    }

    Log.info(
      '📤 Starting video publish',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    await ref
        .read(videoPublishProvider.notifier)
        .publishVideo(context, getActiveDraft());
  }

  /// Render all clips into a single video file with aspect ratio cropping.
  ///
  /// Applies center cropping based on target aspect ratio (square or vertical).
  Future<(String? filePath, String? proof)> _renderVideo() async {
    Log.info(
      '🎥 Rendering ${_clips.length} clip(s) into final video',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    try {
      // Render clips into single video file
      final outputPath = await VideoEditorRenderService.renderVideo(
        clips: _clips,
        aspectRatio: _clips.first.targetAspectRatio,
        enableAudio: !state.isMuted,
      );
      String? proofManifestJson;

      // Generate proofmode attestation if render successful
      if (outputPath != null) {
        Log.info(
          '✅ Video rendered to: $outputPath',
          name: 'VideoEditorNotifier',
          category: .video,
        );

        Log.debug(
          '🔐 Generating proofmode attestation for video',
          name: 'VideoEditorNotifier',
          category: .video,
        );
        final proofData = await NativeProofModeService.proofFile(
          File(outputPath),
        );

        if (proofData != null) {
          proofManifestJson = jsonEncode(proofData);
          Log.info(
            '✅ Proofmode attestation generated',
            name: 'VideoEditorNotifier',
            category: .video,
          );
        } else {
          Log.warning(
            '⚠️ No proofmode data available',
            name: 'VideoEditorNotifier',
            category: .video,
          );
        }
      } else {
        Log.error(
          '❌ Video rendering failed',
          name: 'VideoEditorNotifier',
          category: .video,
        );
      }

      state = state.copyWith(isProcessing: false);
      return (outputPath, proofManifestJson);
    } catch (e, stackTrace) {
      Log.error(
        '❌ Video rendering error: $e',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isProcessing: false);
      return (null, null);
    }
  }
}
