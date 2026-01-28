// ABOUTME: Riverpod provider for managing video publish screen state
// ABOUTME: Controls playback, mute state, and position tracking

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
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
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for video publish screen state management.
final videoPublishProvider =
    NotifierProvider<VideoPublishNotifier, VideoPublishProviderState>(
      VideoPublishNotifier.new,
    );

/// Manages video publish screen state including playback and position.
class VideoPublishNotifier extends Notifier<VideoPublishProviderState> {
  @override
  VideoPublishProviderState build() {
    return const VideoPublishProviderState();
  }

  /// Creates the publish service with callbacks wired to this notifier.
  Future<VideoPublishService> _createPublishService() async {
    final prefs = await SharedPreferences.getInstance();

    return VideoPublishService(
      uploadManager: ref.read(uploadManagerProvider),
      authService: ref.read(authServiceProvider),
      videoEventPublisher: ref.read(videoEventPublisherProvider),
      blossomService: ref.read(blossomUploadServiceProvider),
      draftService: DraftStorageService(prefs),
      onStateChanged: setPublishState,
      onProgressChanged: setUploadProgress,
      isMounted: () => ref.mounted,
    );
  }

  /// Resets all video-related providers after a successful publish.
  ///
  /// Clears recorder, editor, clip manager, sound selection, and publish state.
  void cleanupAfterPublish() {
    ref.read(videoRecorderProvider.notifier).reset();
    ref.read(videoEditorProvider.notifier).reset();
    ref.read(clipManagerProvider.notifier).clearAll();
    ref.read(selectedSoundProvider.notifier).clear();
    reset();
  }

  /// Updates upload progress (0.0 to 1.0).
  void setUploadProgress(double value) {
    state = state.copyWith(uploadProgress: value);

    if (value == 0.0 || value == 1.0 || (value * 100) % 10 == 0) {
      Log.info(
        '📊 Upload progress: ${(value * 100).toStringAsFixed(0)}%',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  /// Updates the publish state.
  void setPublishState(VideoPublishState value) {
    state = state.copyWith(publishState: value);

    Log.info(
      'Publish state changed to: ${value.name}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
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

    VineDraft publishDraft = draft.copyWith();

    try {
      setPublishState(.preparing);
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

      final publishService = await _createPublishService();
      final result = await publishService.publishVideo(draft: publishDraft);

      // Handle result
      switch (result) {
        case PublishSuccess():
          cleanupAfterPublish();
          Log.info(
            '🎉 Video published successfully',
            name: 'VideoPublishNotifier',
            category: .video,
          );
          if (!context.mounted) return;
          // Navigate to current user's profile
          final authService = ref.read(authServiceProvider);
          final currentUserHex = authService.currentPublicKeyHex;
          if (currentUserHex != null) {
            final npub = NostrKeyUtils.encodePubKey(currentUserHex);
            context.go(ProfileScreenRouter.pathForNpub(npub));
          }

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

      setPublishState(.error);
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
