// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent, InspiredByInfo;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

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
  String? _draftId;
  String get draftId => _draftId ?? VideoEditorConstants.autoSaveId;
  set draftId(String? id) {
    _draftId = id;
  }

  Timer? _autosaveTimer;

  /// Get clip manager notifier.
  ClipManagerNotifier get _clipManager =>
      ref.read(clipManagerProvider.notifier);

  /// Get clips from clip manager.
  List<DivineVideoClip> get _clips => ref.read(clipManagerProvider).clips;

  DraftStorageService get _draftService =>
      ref.read(draftStorageServiceProvider);

  bool get isAutosavedDraft => state.isAutosavedDraft;

  int _renderGeneration = 0;

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

  /// Invalidate the final rendered clip when content changes.
  ///
  /// Called by ClipManager when clips change, or when editor parameters
  /// change, to ensure a re-render is required before publishing.
  /// Also deletes the rendered file from disk since it's stored in Documents.
  void invalidateFinalRenderedClip() {
    final clip = state.finalRenderedClip;
    if (clip == null) return;

    Log.debug(
      '🔄 Invalidating final rendered clip due to content change',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    if (state.isProcessing) {
      cancelRenderVideo();
    }

    state = state.copyWith(clearFinalRenderedClip: true);

    // Delete the old rendered file from disk to free up space
    final db = ref.read(databaseProvider);
    unawaited(
      FileCleanupService.deleteRecordingClipFiles(
        clip,
        draftsDao: db.draftsDao,
        clipsDao: db.clipsDao,
      ),
    );
  }

  /// Initialize the video editor with an optional draft.
  ///
  /// Loads existing draft data if [draftId] is provided, including clips
  /// and metadata.
  Future<void> initialize({String? draftId}) async {
    // Reset old editing states but keep metadata
    state = state.copyWith(isProcessing: false, isSavingDraft: false);

    // If the editor screen is opened from a draft, we initialize it here.
    if (draftId != null && draftId.isNotEmpty) {
      await restoreDraft(draftId);
    } else {
      Log.info(
        '🎬 Initializing video editor (no draft)',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      final accountLabelService = ref.read(accountLabelServiceProvider);
      await accountLabelService.initialized;
      final accountLabels = accountLabelService.defaultVideoLabels;
      if (accountLabels.isNotEmpty) {
        state = state.copyWith(contentWarnings: accountLabels);
        Log.info(
          '⚠️ Auto-selected content warnings from account labels: '
          '${accountLabels.map((label) => label.value).join(", ")}',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      }
    }
    this.draftId = draftId ?? VideoEditorConstants.autoSaveId;
    state = state.copyWith(
      isAutosavedDraft: this.draftId == VideoEditorConstants.autoSaveId,
    );
  }

  /// Reset editor state and metadata to defaults.
  ///
  /// Also cancels any pending autosave and deletes the autosaved draft
  /// unless [keepAutosavedDraft] is true.
  Future<void> reset({bool keepAutosavedDraft = false}) async {
    Log.debug(
      '🔄 Resetting editor state',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = VideoEditorProviderState();
    _autosaveTimer?.cancel();
    draftId = null;
    if (!keepAutosavedDraft) {
      unawaited(removeAutosavedDraft());
    }
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
  /// Automatically extracts hashtags from title and description.
  /// A hashtag is detected when followed by a non-alphanumeric character
  /// or at end of string (e.g., "#hot ", "#hot", "text #hot.").
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
    const tagLimit = VideoEditorConstants.tagLimit;

    // Only extract hashtags when text changes, not when tags are manually edited
    final Set<String> allTags;
    if (tags != null) {
      // User manually edited tags - use only what they provided
      allTags = tags
          .map((tag) => tag.replaceAll(RegExp('[^a-zA-Z0-9]'), ''))
          .where((tag) => tag.isNotEmpty)
          .take(tagLimit)
          .toSet();
    } else {
      // Text changed - compare old and new hashtags to only update changed ones
      final hashtagPattern = RegExp('#([a-zA-Z0-9]+)(?![a-zA-Z0-9])');

      // Extract hashtags from OLD text
      final oldText = '${state.title} ${state.description}';
      final oldHashtags = hashtagPattern
          .allMatches(oldText)
          .map((m) => m.group(1))
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toSet();

      // Extract hashtags from NEW text
      final newText = '$rawTitle $rawDescription';
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
    Log.debug(
      '⏰ Set expiration: ${expiration.name}',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(expiration: expiration);
    triggerAutosave();
  }

  /// Set NIP-32 content warning labels for the current video.
  void setContentWarnings(Set<ContentLabel> labels) {
    state = state.copyWith(contentWarnings: Set<ContentLabel>.of(labels));
    triggerAutosave();
  }

  // === COLLABORATORS & INSPIRED BY ===

  /// Maximum number of collaborators allowed per video.
  static const int maxCollaborators = 5;

  /// Add a collaborator pubkey to the pending verification set.
  ///
  /// Enforces a maximum of [maxCollaborators] total (confirmed + pending).
  void addPendingCollaborator(String pubkey) {
    final total =
        state.collaboratorPubkeys.length +
        state.pendingCollaboratorPubkeys.length;
    if (total >= maxCollaborators) return;
    if (state.collaboratorPubkeys.contains(pubkey)) return;
    if (state.pendingCollaboratorPubkeys.contains(pubkey)) return;
    state = state.copyWith(
      pendingCollaboratorPubkeys: {...state.pendingCollaboratorPubkeys, pubkey},
    );
  }

  /// Confirm a pending collaborator after successful verification.
  ///
  /// Moves the pubkey from [pendingCollaboratorPubkeys] to
  /// [collaboratorPubkeys].
  void confirmCollaborator(String pubkey) {
    if (!state.pendingCollaboratorPubkeys.contains(pubkey)) return;
    state = state.copyWith(
      pendingCollaboratorPubkeys: state.pendingCollaboratorPubkeys
          .where((p) => p != pubkey)
          .toSet(),
      collaboratorPubkeys: {...state.collaboratorPubkeys, pubkey},
    );
    triggerAutosave();
  }

  /// Remove a pubkey from the pending verification set.
  void removePendingCollaborator(String pubkey) {
    state = state.copyWith(
      pendingCollaboratorPubkeys: state.pendingCollaboratorPubkeys
          .where((p) => p != pubkey)
          .toSet(),
    );
  }

  /// Add a collaborator pubkey to the video.
  ///
  /// Enforces a maximum of [maxCollaborators] collaborators.
  /// Silently ignores duplicates.
  void addCollaborator(String pubkey) {
    if (state.collaboratorPubkeys.length >= maxCollaborators) return;
    if (state.collaboratorPubkeys.contains(pubkey)) return;
    state = state.copyWith(
      collaboratorPubkeys: {...state.collaboratorPubkeys, pubkey},
    );
    triggerAutosave();
  }

  /// Remove a collaborator pubkey from the video.
  void removeCollaborator(String pubkey) {
    state = state.copyWith(
      collaboratorPubkeys: state.collaboratorPubkeys
          .where((p) => p != pubkey)
          .toSet(),
    );
    triggerAutosave();
  }

  /// Set the "Inspired By" reference to a specific video (a-tag).
  void setInspiredByVideo(InspiredByInfo info) {
    state = state.copyWith(inspiredByVideo: info, clearInspiredByNpub: true);
    triggerAutosave();
  }

  /// Set the "Inspired By" reference to a person (NIP-27 npub in content).
  void setInspiredByPerson(String npub) {
    state = state.copyWith(inspiredByNpub: npub, clearInspiredByVideo: true);
    triggerAutosave();
  }

  /// Clear all "Inspired By" attribution.
  void clearInspiredBy() {
    state = state.copyWith(
      clearInspiredByVideo: true,
      clearInspiredByNpub: true,
    );
    triggerAutosave();
  }

  // === SOUND MANAGEMENT ===

  /// Select a sound for the video.
  ///
  /// This updates the editor's local state. The sound is persisted
  /// in drafts and used for audio playback during editing.
  void selectSound(AudioEvent? sound) {
    if (sound == state.selectedSound) return;

    state = state.copyWith(
      selectedSound: sound,
      clearSelectedSound: sound == null,
    );
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Clear the currently selected sound.
  void clearSound() {
    state = state.copyWith(clearSelectedSound: true);
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Update the volume level for the original video audio (0.0 to 1.0).
  void setOriginalAudioVolume(double volume) {
    state = state.copyWith(originalAudioVolume: volume.clamp(0.0, 1.0));
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Update the volume level for the custom/added audio track (0.0 to 1.0).
  void setCustomAudioVolume(double volume) {
    state = state.copyWith(customAudioVolume: volume.clamp(0.0, 1.0));
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Preview original audio volume without invalidating render or autosave.
  ///
  /// Used during live slider interaction so the user can hear the change
  /// immediately. Call [setOriginalAudioVolume] to commit the final value.
  void previewOriginalAudioVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped != state.originalAudioVolume) {
      state = state.copyWith(originalAudioVolume: clamped);
    }
  }

  /// Preview custom audio volume without invalidating render or autosave.
  ///
  /// Used during live slider interaction so the user can hear the change
  /// immediately. Call [setCustomAudioVolume] to commit the final value.
  void previewCustomAudioVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped != state.customAudioVolume) {
      state = state.copyWith(customAudioVolume: clamped);
    }
  }

  /// Update the start offset of the currently selected sound.
  void updateSoundStartOffset(Duration offset) {
    if (state.selectedSound != null &&
        offset != state.selectedSound?.startOffset) {
      state = state.copyWith(
        selectedSound: state.selectedSound!.copyWith(startOffset: offset),
      );
      invalidateFinalRenderedClip();
      triggerAutosave();
    }
  }

  /// Create a VineDraft from the rendered clip with metadata.
  ///
  /// When a sound is selected via [selectedSoundProvider], automatically
  /// populates [selectedAudioEventId] and [selectedAudioRelay] for the
  /// publisher to add an `["e", ..., "audio"]` tag. Also auto-populates
  /// [inspiredByVideo] from the sound's [sourceVideoReference] if not
  /// already set.
  DivineVideoDraft getActiveDraft({bool isAutosave = false, String? draftId}) {
    // Read selected sound from local state
    final selectedSound = state.selectedSound;

    // Auto-populate inspired-by from selected sound's source video
    var inspiredByVideo = state.inspiredByVideo;
    if (inspiredByVideo == null &&
        selectedSound?.sourceVideoReference != null) {
      inspiredByVideo = InspiredByInfo(
        addressableId: selectedSound!.sourceVideoReference!,
        relayUrl: selectedSound.sourceVideoRelay,
      );
    }

    return DivineVideoDraft.create(
      id:
          draftId ??
          (isAutosave ? VideoEditorConstants.autoSaveId : this.draftId),
      clips: _clips,
      title: state.title,
      description: state.description,
      hashtags: state.tags,
      allowAudioReuse: state.allowAudioReuse,
      expireTime: state.expiration.value,
      selectedApproach: 'video',
      editorStateHistory: state.editorStateHistory,
      editorEditingParameters: state.editorEditingParameters?.toMap(),
      collaboratorPubkeys: state.collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: state.inspiredByNpub,
      selectedSound: selectedSound,
      contentWarning: ContentLabel.toCsv(state.contentWarnings),
      finalRenderedClip: state.finalRenderedClip,
      proofManifestJson: state.proofManifestJson,
      originalAudioVolume: state.originalAudioVolume,
      customAudioVolume: state.customAudioVolume,
    );
  }

  // === EDITOR STATE PERSISTENCE ===

  /// Update the editor state history for undo/redo functionality.
  ///
  /// This stores the serialized state history from ProImageEditor,
  /// allowing users to restore their editing progress when reopening a draft.
  void updateEditorStateHistory(Map<String, dynamic> stateHistory) {
    if (mapEquals(state.editorStateHistory, stateHistory)) return;

    Log.debug(
      '📜 Updated editor state history',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    invalidateFinalRenderedClip();
    state = state.copyWith(editorStateHistory: stateHistory);
    triggerAutosave();
  }

  /// Update the editor editing parameters (filters, drawings, etc.).
  ///
  /// This stores the serialized editing parameters from ProImageEditor,
  /// enabling restoration of all applied effects when reopening a draft.
  void updateEditorEditingParameters(CompleteParameters editingParameters) {
    final old = state.editorEditingParameters;
    if (old != null) {
      final diffs = old.diff(editingParameters);
      if (diffs.isEmpty) {
        Log.debug(
          '🎨 Editor editing parameters unchanged - skipping update',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
        return;
      }
      Log.debug(
        '🎨 Editor editing parameters changed: ${diffs.join(", ")}',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        '🎨 Editor editing parameters set (was null)',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    }
    invalidateFinalRenderedClip();
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
    state = state.copyWith(
      isAutosavedDraft: id == VideoEditorConstants.autoSaveId,
    );
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
      final draft = getActiveDraft(isAutosave: isAutosavedDraft);
      await _draftService.saveDraft(draft);

      Log.info(
        '✅ Autosave completed - $clipCount clip(s), '
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
  Future<bool> saveAsDraft({bool enforceCreateNewDraft = false}) async {
    if (state.isSavingDraft) return false;

    state = state.copyWith(isSavingDraft: true);

    final draftId = enforceCreateNewDraft
        ? 'draft_${DateTime.now().microsecondsSinceEpoch}'
        : this.draftId;

    Log.info(
      '💾 Saving draft: $draftId',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    try {
      await _draftService.saveDraft(getActiveDraft(draftId: draftId));

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
  /// Invalid clips (missing video files) are automatically filtered out,
  /// and missing thumbnails are regenerated.
  ///
  /// Returns `true` if the draft was restored successfully with at least
  /// one clip, `false` if the draft was not found or had no valid clips.
  Future<bool> restoreDraft([String? draftId]) async {
    draftId ??= VideoEditorConstants.autoSaveId;
    Log.info(
      '🎬 Restoring draft: $draftId',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );

    final draft = await _draftService.getDraftById(draftId);
    if (draft == null) {
      Log.warning(
        '⚠️ Draft not found or has no valid clips: $draftId',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
      return false;
    }

    // Regenerate missing thumbnails
    final clipsWithThumbnails = <DivineVideoClip>[];
    for (final clip in draft.clips) {
      final thumbnailPath = clip.thumbnailPath;
      final thumbnailExists =
          thumbnailPath != null && File(thumbnailPath).existsSync();

      if (thumbnailExists) {
        clipsWithThumbnails.add(clip);
        continue;
      }

      Log.info(
        '🖼️ Regenerating thumbnail for clip ${clip.id}',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );

      final videoPath = clip.video.file!.path;
      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        targetTimestamp: clip.thumbnailTimestamp,
      );
      if (result != null) {
        clipsWithThumbnails.add(clip.copyWith(thumbnailPath: result.path));
      } else {
        Log.warning(
          '⚠️ Failed to regenerate thumbnail for clip ${clip.id}',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
        // Keep clip even without thumbnail
        clipsWithThumbnails.add(clip);
      }
    }

    // Validate finalRenderedClip - only restore if file still exists
    DivineVideoClip? validFinalRenderedClip;
    final finalClip = draft.finalRenderedClip;
    if (finalClip != null) {
      final videoPath = finalClip.video.file?.path;
      if (videoPath != null && File(videoPath).existsSync()) {
        validFinalRenderedClip = finalClip;
        Log.info(
          '✅ Restored final rendered clip',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      } else {
        Log.info(
          '⚠️ Final rendered clip file missing, will re-render',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      }
    }

    state = state.copyWith(
      title: draft.title,
      description: draft.description,
      tags: draft.hashtags,
      allowAudioReuse: draft.allowAudioReuse,
      expiration: VideoMetadataExpiration.fromDuration(draft.expireTime),
      editorStateHistory: draft.editorStateHistory,
      editorEditingParameters: CompleteParameters.fromMap(
        draft.editorEditingParameters,
      ),
      collaboratorPubkeys: draft.collaboratorPubkeys,
      inspiredByVideo: draft.inspiredByVideo,
      inspiredByNpub: draft.inspiredByNpub,
      selectedSound: draft.selectedSound,
      contentWarnings: draft.contentWarnings,
      finalRenderedClip: validFinalRenderedClip,
      clearFinalRenderedClip: validFinalRenderedClip == null,
      originalAudioVolume: draft.originalAudioVolume,
      customAudioVolume: draft.customAudioVolume,
    );

    _clipManager.replaceClips(clipsWithThumbnails);
    if (clipsWithThumbnails.isEmpty) {
      Log.warning(
        '⚠️ Draft restored with no clips',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
      return false;
    }

    // We set the aspect ratio in the video recorder to match the clips,
    // so the user can't mix them up.
    ref
        .read(videoRecorderProvider.notifier)
        .setAspectRatio(clipsWithThumbnails.first.targetAspectRatio);
    Log.info(
      '✅ Draft loaded with ${clipsWithThumbnails.length} clip(s)',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    return true;
  }

  /// Delete the autosaved draft from local storage.
  ///
  /// Called when the user explicitly discards the autosaved session or
  /// after successfully publishing a video.
  Future<void> removeAutosavedDraft() async {
    try {
      await _draftService.deleteDraft(VideoEditorConstants.autoSaveId);
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

  /// Set the processing state.
  ///
  /// Use this to mark that video processing has started before calling
  /// [startRenderVideo], or to reset the state after processing completes.
  void setProcessing(bool isProcessing) {
    if (state.isProcessing == isProcessing) return;
    state = state.copyWith(isProcessing: isProcessing);
  }

  /// Render all clips into final video and prepare for publishing.
  ///
  /// Combines all clips, applies audio settings, and creates the final
  /// rendered clip for publishing.
  Future<void> startRenderVideo() async {
    if (state.finalRenderedClip != null) {
      setProcessing(false);
      return;
    }

    Log.info(
      '🎬 Starting final video render',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    setProcessing(true);

    final renderParameters = _buildRenderParameters();
    final generation = ++_renderGeneration;

    final result = await VideoEditorRenderService.renderVideoToClip(
      clips: _clips,
      aiTrainingOptOut: ref
          .read(aiTrainingPreferenceServiceProvider)
          .isOptOutEnabled,
      parameters: renderParameters,
      originalAudioVolume: state.originalAudioVolume,
      customAudioVolume: state.customAudioVolume,
      editorStateHistory: state.editorStateHistory,
      taskId: draftId,
    );

    // A newer render was started while this one was running — discard.
    if (generation != _renderGeneration) return;

    if (result == null) {
      Log.warning(
        '⚠️ Video render cancelled or failed',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      state = state.copyWith(isProcessing: false);
      return;
    }

    final (finalRenderedClip, proofManifestJson) = result;

    Log.info(
      '✅ Video rendered successfully - duration: '
      '${finalRenderedClip.duration.inSeconds}s',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    state = state.copyWith(
      isProcessing: false,
      finalRenderedClip: finalRenderedClip,
      proofManifestJson: proofManifestJson,
    );
    autosaveChanges();
  }

  /// Cancel an ongoing video render operation.
  Future<void> cancelRenderVideo() async {
    await VideoEditorRenderService.cancelTask(draftId);
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

  // === PRIVATE HELPERS ===

  /// Build render parameters for video export.
  ///
  /// Combines editor editing parameters with custom audio track if selected.
  /// Returns null if no parameters or sound track are configured.
  CompleteParameters? _buildRenderParameters() {
    final hasEditorParams = state.editorEditingParameters != null;
    final soundTrack = state.selectedSound;

    if (!hasEditorParams && soundTrack == null) return null;

    final baseParams =
        state.editorEditingParameters ?? CompleteParameters.fromMap({});

    final audioTracks = baseParams.audioTracksFromMeta;

    return baseParams.copyWith(
      audioTracks: [
        for (final track in audioTracks)
          AudioTrack(
            id: track.id,
            title: track.title ?? '',
            subtitle: track.source ?? '',
            duration: Duration(seconds: track.duration?.toInt() ?? 0),
            audio: track.isBundled
                ? EditorAudio.asset(track.assetPath!)
                : EditorAudio.network(track.url!),
            startTime: track.startTime,
            endTime: track.endTime,
            audioStartTime: track.startOffset,
            audioEndTime:
                track.startOffset +
                Duration(milliseconds: ((track.duration ?? 0) * 1000).toInt()),
            volume: track.volume,
          ),

        if (soundTrack != null)
          AudioTrack(
            id: soundTrack.id,
            title: soundTrack.title ?? '',
            subtitle: soundTrack.source ?? '',
            duration: Duration(seconds: soundTrack.duration?.toInt() ?? 0),
            audio: soundTrack.isBundled
                ? EditorAudio.asset(soundTrack.assetPath!)
                : EditorAudio.network(soundTrack.url!),
            startTime: soundTrack.startOffset,
          ),
      ],
    );
  }
}
