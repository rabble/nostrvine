// ABOUTME: Riverpod provider for managing video publish screen state
// ABOUTME: Controls playback, mute state, and position tracking

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Provider for video publish screen state management.
final videoPublishProvider =
    NotifierProvider<VideoPublishNotifier, VideoPublishProviderState>(
      VideoPublishNotifier.new,
    );

/// Manages video publish screen state including playback and position.
class VideoPublishNotifier extends Notifier<VideoPublishProviderState> {
  final _draftService = DraftStorageService();

  @override
  VideoPublishProviderState build() {
    return const VideoPublishProviderState();
  }

  /// Creates the publish service with callbacks wired to this notifier.
  Future<VideoPublishService> _createPublishService({
    required OnProgressChanged onProgressChanged,
  }) async {
    return VideoPublishService(
      uploadManager: ref.read(uploadManagerProvider),
      authService: ref.read(authServiceProvider),
      videoEventPublisher: ref.read(videoEventPublisherProvider),
      blossomService: ref.read(blossomUploadServiceProvider),
      draftService: _draftService,
      gallerySaveService: ref.read(gallerySaveServiceProvider),
      onProgressChanged: ({required String draftId, required double progress}) {
        setUploadProgress(draftId: draftId, progress: progress);
        onProgressChanged(draftId: draftId, progress: progress);
      },
    );
  }

  /// Resets all video-related providers.
  ///
  /// Clears recorder, editor, clip manager, sound selection, and publish state.
  void clearAll() {
    ref.read(videoRecorderProvider.notifier).reset();
    ref.read(videoEditorProvider.notifier).reset();
    ref.read(clipManagerProvider.notifier).clearAll();
    ref.read(selectedSoundProvider.notifier).clear();
    reset();
  }

  /// Resumes any pending publish drafts that were interrupted.
  ///
  /// Called on app startup to check for drafts with [VideoEditorConstants.publishPrefixId]
  /// prefix and restart their upload process.
  Future<void> resumePendingPublishes(BuildContext context) async {
    final drafts = await _draftService.getAllDrafts();
    final pendingDrafts = drafts.where(
      (d) => d.id.startsWith(VideoEditorConstants.publishPrefixId),
    );

    if (pendingDrafts.isEmpty) {
      Log.debug(
        '✅ No pending publish drafts found',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🔄 Found ${pendingDrafts.length} pending publish draft(s), resuming...',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );

    final backgroundPublishBloc = context.read<BackgroundPublishBloc>();

    for (final draft in pendingDrafts) {
      Log.info(
        '📤 Resuming upload for draft: ${draft.id}',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );

      final publishService = await _createPublishService(
        onProgressChanged: ({required draftId, required progress}) {
          backgroundPublishBloc.add(
            BackgroundPublishProgressChanged(
              draftId: draftId,
              progress: progress,
            ),
          );
        },
      );

      final publishmentProcess = publishService.publishVideo(draft: draft);
      backgroundPublishBloc.add(
        BackgroundPublishRequested(
          draft: draft,
          publishmentProcess: publishmentProcess,
        ),
      );
    }
  }

  /// Updates upload progress (0.0 to 1.0).
  void setUploadProgress({required String draftId, required double progress}) {
    state = state.copyWith(uploadProgress: progress);

    if (progress == 0.0 || progress == 1.0 || (progress * 100) % 10 == 0) {
      Log.info(
        '📊 Upload progress: ${(progress * 100).toStringAsFixed(0)}%',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  /// Sets error state with user message.
  void setError(String userMessage) {
    state = state.copyWith(publishState: .error, errorMessage: userMessage);

    Log.error(
      '❌ Publish error: $userMessage',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(publishState: .idle, errorMessage: '');
  }

  /// Publishes the video with ProofMode attestation and navigates to
  /// profile on success.
  Future<void> publishVideo(BuildContext context, VineDraft draft) async {
    if (state.publishState != .idle) {
      Log.warning(
        '⚠️ Publish already in progress, ignoring duplicate request',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      return;
    }

    VineDraft publishDraft = draft.copyWith(
      id:
          '${VideoEditorConstants.publishPrefixId}_'
          '${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      Log.info(
        '📝 Starting video publish process',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      // If the draft hasn't been proofread yet, we'll try again here.
      if (draft.proofManifestJson == null) {
        Log.info(
          '🔐 Generating proof manifest for video',
          name: 'VideoPublishNotifier',
          category: .video,
        );

        // When we publish a clip, we expect all the clips to be merged, so we
        // can read the first clip directly. Multiple clips are only required to
        // restore the editor state from drafts.
        final filePath = await publishDraft.clips.first.video.safeFilePath();
        final result = await NativeProofModeService.proofFile(File(filePath));
        String? proofManifestJson = result == null ? null : jsonEncode(result);
        publishDraft = publishDraft.copyWith(
          proofManifestJson: proofManifestJson,
        );

        Log.debug(
          '💾 Saving publish draft: ${publishDraft.id}',
          name: 'VideoPublishNotifier',
          category: .video,
        );
        await _draftService.saveDraft(publishDraft);
        Log.debug(
          '🧹 Clearing all editor state after draft save',
          name: 'VideoPublishNotifier',
          category: .video,
        );

        if (proofManifestJson != null) {
          Log.info(
            '✅ Proof manifest generated successfully',
            name: 'VideoPublishNotifier',
            category: .video,
          );
        } else {
          Log.warning(
            '⚠️ Proof manifest generation returned null',
            name: 'VideoPublishNotifier',
            category: .video,
          );
        }
      }

      Log.info(
        '📤 Uploading video',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      final backgroundPublishBloc = context.read<BackgroundPublishBloc>();
      final publishService = await _createPublishService(
        onProgressChanged: ({required draftId, required progress}) {
          backgroundPublishBloc.add(
            BackgroundPublishProgressChanged(
              draftId: draftId,
              progress: progress,
            ),
          );
        },
      );

      final publishmentProcess = publishService.publishVideo(
        draft: publishDraft,
      );
      backgroundPublishBloc.add(
        BackgroundPublishRequested(
          draft: publishDraft,
          publishmentProcess: publishmentProcess,
        ),
      );

      // Navigate to current user's profile
      final authService = ref.read(authServiceProvider);
      final currentNpub = authService.currentNpub;
      if (currentNpub != null) {
        context.go(ProfileScreenRouter.pathForNpub(currentNpub));
        // Clear editor state after navigation animation completes (~350ms)
        // Draft is already saved for background upload
        Future.delayed(const Duration(milliseconds: 600), clearAll);
      }

      final result = await publishmentProcess;

      // Handle result
      switch (result) {
        case PublishSuccess():
          Log.info(
            '🎉 Video published successfully',
            name: 'VideoPublishNotifier',
            category: .video,
          );

        case PublishError(:final userMessage):
          setError(userMessage);
          Log.error(
            '❌ Publish failed: $userMessage',
            name: 'VideoPublishNotifier',
            category: .video,
          );
      }
    } catch (error, stackTrace) {
      Log.error(
        '❌ Failed to publish video: $error',
        name: 'VideoPublishNotifier',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      Log.info(
        '🏁 Publish process completed',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  /// Resets state to initial values.
  void reset() {
    state = const VideoPublishProviderState();

    Log.info(
      '🔄 Video publish state reset',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }
}
