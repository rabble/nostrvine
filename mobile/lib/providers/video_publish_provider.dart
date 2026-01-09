// ABOUTME: Riverpod provider for managing video publish screen state
// ABOUTME: Controls playback, mute state, and position tracking

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/models/video_publish_state.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/router/nav_extensions.dart';
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
  VineDraft? draft;
  bool _isPublishing = false;
  final publishService = VideoPublishService();

  @override
  VideoPublishProviderState build() {
    return const VideoPublishProviderState();
  }

  /// Sets video data and metadata for publishing.
  void initialize({required VineDraft draft}) {
    this.draft = draft;
    state = state.copyWith(clip: draft.clips.first);

    Log.info(
      '🎬 Video publish initialized with ${draft.clips.length} clip(s)',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Toggles between play and pause states.
  void togglePlayPause() {
    final newState = !state.isPlaying;
    state = state.copyWith(isPlaying: newState);

    Log.info(
      '${newState ? '▶️' : '⏸️'} Video ${newState ? 'playing' : 'paused'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Sets the playing state.
  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);

    Log.info(
      '${isPlaying ? '▶️' : '⏸️'} Video playback set to '
      '${isPlaying ? 'playing' : 'paused'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Toggles mute state.
  void toggleMute() {
    final newState = !state.isMuted;
    state = state.copyWith(isMuted: newState);

    Log.info(
      '${newState ? '🔇' : '🔊'} Video ${newState ? 'muted' : 'unmuted'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Sets the muted state.
  void setMuted(bool isMuted) {
    state = state.copyWith(isMuted: isMuted);

    Log.info(
      '${isMuted ? '🔇' : '🔊'} Video audio set to '
      '${isMuted ? 'muted' : 'unmuted'}',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Updates current playback position.
  void updatePosition(Duration position) {
    state = state.copyWith(currentPosition: position);
  }

  /// Sets total video duration.
  void setDuration(Duration duration) {
    state = state.copyWith(totalDuration: duration);

    Log.info(
      '⏱️ Video duration set: ${duration.inSeconds}s',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Updates upload progress (0.0 to 1.0).
  void setUploadProgress(double value) {
    state = state.copyWith(uploadProgress: value);

    if (value == 0.0 || value == 1.0 || (value * 100) % 25 == 0) {
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

  Future<void> publishVideo(BuildContext context) async {
    if (_isPublishing) {
      Log.warning(
        '⚠️ Publish already in progress, ignoring duplicate request',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      return;
    }

    if (draft == null) {
      Log.error(
        '❌ Cannot publish: Draft is required',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      throw ArgumentError('Draft is required!');
    }

    _isPublishing = true;

    try {
      // Stop video playback when publishing starts
      setPlaying(false);
      Log.info(
        '📝 Starting video publish process',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      // If the draft hasn't been proofread yet, we'll try again here.
      if (draft!.proofManifestJson == null) {
        Log.info(
          '🔐 Generating proof manifest for video',
          name: 'VideoPublishNotifier',
          category: .video,
        );

        // When we publish a clip, we expect all the clips to be merged, so we
        // can read the first clip directly. Multiple clips are only required to
        // restore the editor state from drafts.
        final filePath = await draft!.clips.first.video.safeFilePath();
        final result = await NativeProofModeService.proofFile(File(filePath));
        String? proofManifestJson = result == null ? null : jsonEncode(result);
        draft = draft!.copyWith(proofManifestJson: proofManifestJson);

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

      await publishService.publishVideo(
        ref: ref,
        context: context,
        draft: draft!,
      );
      reset();

      Log.info(
        '🎉 Video published successfully',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      context.goMyProfile();
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
      _isPublishing = false;
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
