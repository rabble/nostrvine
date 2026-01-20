// ABOUTME: Service for publishing videos to Nostr with upload management
// ABOUTME: Handles video upload to Blossom servers, retry logic, and Nostr event creation

import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result of a publish operation.
sealed class PublishResult {
  const PublishResult();
}

class PublishSuccess extends PublishResult {
  const PublishSuccess();
}

class PublishError extends PublishResult {
  const PublishError(this.userMessage);
  final String userMessage;
}

/// Callbacks for VideoPublishService to communicate state changes.
/// This abstraction makes the service testable without Riverpod dependencies.
typedef OnStateChanged = void Function(VideoPublishState state);
typedef OnProgressChanged = void Function(double progress);

class VideoPublishService {
  VideoPublishService({
    required this.uploadManager,
    required this.authService,
    required this.videoEventPublisher,
    required this.blossomService,
    required this.draftService,
    required this.onStateChanged,
    required this.onProgressChanged,
    this.isMounted,
  });

  /// Manages background video uploads.
  final UploadManager uploadManager;

  /// Handles user authentication.
  final AuthService authService;

  /// Publishes video events to Nostr.
  final VideoEventPublisher videoEventPublisher;

  /// Handles Blossom server interactions.
  final BlossomUploadService blossomService;

  /// Manages video draft storage.
  final DraftStorageService draftService;

  /// Callback when publish state changes.
  final OnStateChanged onStateChanged;

  /// Callback when upload progress changes.
  final OnProgressChanged onProgressChanged;

  /// Optional function to check if the caller is still mounted.
  /// Used to stop polling when the caller is disposed.
  final bool Function()? isMounted;

  bool get _shouldContinue => isMounted?.call() ?? true;

  /// Tracks the current background upload ID.
  String? _backgroundUploadId;

  /// Publishes a video draft.
  /// Returns [PublishSuccess] on success, [PublishError] on failure.
  Future<PublishResult> publishVideo({required VineDraft draft}) async {
    // Check if we have a background upload ID and its status
    if (_backgroundUploadId != null) {
      final error = await _handleActiveUpload();
      if (error != null) return error;
    }

    try {
      final publishing = draft.copyWith(publishStatus: .publishing);
      await draftService.saveDraft(publishing);

      // TODO(@hm21): Temporary "commented out" create PR with only new files
      /* final videoPath = await draft.clips.first.video.safeFilePath();
      Log.info('📝 Publishing video: $videoPath', category: .video); */

      // Verify user is fully authenticated
      if (!authService.isAuthenticated) {
        onStateChanged(.error);
        // TODO(l10n): Replace with context.l10n when localization is added.
        return const PublishError('Please sign in to publish videos.');
      }
      final pubkey = authService.currentPublicKeyHex!;

      // Use existing upload if available, otherwise start new upload
      final pendingUpload = await _getOrCreateUpload(pubkey, draft);
      if (pendingUpload == null) {
        onStateChanged(.error);
        // TODO(l10n): Replace with context.l10n when localization is added.
        return const PublishError('Failed to upload video. Please try again.');
      }

      // Check if upload failed
      if (pendingUpload.status == .failed) {
        return await _handleUploadError(
          Exception(pendingUpload.errorMessage ?? 'Upload failed'),
          StackTrace.current,
          draft,
        );
      }

      // Publish Nostr event
      Log.info('📝 Publishing Nostr event...', category: .video);
      onStateChanged(.publishToNostr);

      final published = await videoEventPublisher.publishVideoEvent(
        upload: pendingUpload,
        title: draft.title,
        description: draft.description,
        hashtags: draft.hashtags,
        // TODO(@hm21): Temporary "commented out" create PR with only new files
        /*  expirationTimestamp: draft.expireTime != null
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                  draft.expireTime!.inSeconds
            : null,
        allowAudioReuse: draft.allowAudioReuse, */
      );

      if (!published) {
        return await _handleUploadError(
          Exception('Failed to publish Nostr event'),
          StackTrace.current,
          draft,
        );
      }

      // Success: delete draft
      await draftService.deleteDraft(draft.id);
      onStateChanged(.completed);

      Log.info('📝 Published successfully', category: .video);
      return const PublishSuccess();
    } catch (e, stackTrace) {
      return await _handleUploadError(e, stackTrace, draft);
    }
  }

  /// Gets existing upload from background ID or creates a new one.
  /// Returns null if upload creation fails.
  Future<PendingUpload?> _getOrCreateUpload(
    String pubkey,
    VineDraft draft,
  ) async {
    if (_backgroundUploadId != null) {
      final existingUpload = uploadManager.getUpload(_backgroundUploadId!);
      if (existingUpload != null && existingUpload.status == .readyToPublish) {
        Log.info(
          '📝 Using existing upload: ${existingUpload.id}',
          category: .video,
        );
        return existingUpload;
      }
    }

    return _startNewUpload(pubkey, draft);
  }

  /// Handles an active background upload.
  /// Returns [PublishError] if there was an error, null to continue.
  Future<PublishError?> _handleActiveUpload() async {
    final upload = uploadManager.getUpload(_backgroundUploadId!);
    if (upload == null) return null;

    // If already ready, continue
    if (upload.status == .readyToPublish) return null;

    // If failed, return error
    if (upload.status == .failed) {
      /// TODO(l10n): Replace with context.l10n when localization is added.
      return PublishError(
        'Upload failed: ${upload.errorMessage ?? "Unknown error"}',
      );
    }

    // Wait for upload to complete
    if (upload.status == .uploading || upload.status == .processing) {
      final result = await _pollUploadProgress(_backgroundUploadId!);
      if (!result) {
        final failedUpload = uploadManager.getUpload(_backgroundUploadId!);

        /// TODO(l10n): Replace with context.l10n when localization is added.
        return PublishError(
          'Upload failed: ${failedUpload?.errorMessage ?? "Unknown error"}',
        );
      }
    }

    return null;
  }

  /// Polls upload progress until complete or failed.
  /// Returns true if upload succeeded, false if failed.
  Future<bool> _pollUploadProgress(String uploadId) async {
    while (_shouldContinue) {
      final upload = uploadManager.getUpload(uploadId);
      if (upload == null) return false;

      onProgressChanged(upload.uploadProgress ?? 0.0);

      switch (upload.status) {
        case .readyToPublish:
        case .published:
          return true;
        case .failed:
          return false;
        case .uploading:
        case .processing:
        case .pending:
        case .retrying:
        case .paused:
          await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return false;
  }

  /// Starts a new upload and polls for progress until completion.
  /// Returns the upload if successful, null if failed.
  Future<PendingUpload?> _startNewUpload(String pubkey, VineDraft draft) async {
    // Ensure upload manager is initialized
    if (!uploadManager.isInitialized) {
      Log.info('📝 Initializing upload manager...', category: .video);
      onStateChanged(.initialize);
      await uploadManager.initialize();
    }

    Log.info('📝 Starting upload to Blossom...', category: .video);
    _logProofModeStatus(draft);

    onStateChanged(VideoPublishState.uploading);

    final pendingUpload = await uploadManager.startUploadFromDraft(
      draft: draft,
      nostrPubkey: pubkey,
    );
    _backgroundUploadId = pendingUpload.id;

    // Poll for progress
    final success = await _pollUploadProgress(pendingUpload.id);
    if (!success) return null;

    return uploadManager.getUpload(pendingUpload.id);
  }

  /// Logs ProofMode attestation status for debugging.
  void _logProofModeStatus(VineDraft draft) {
    final hasProofMode = draft.hasProofMode;
    final nativeProof = draft.nativeProof;

    Log.info(
      '📜 ProofMode: $hasProofMode, '
      'nativeProof: ${nativeProof != null ? "present" : "null"}',
      category: .video,
    );

    if (hasProofMode && nativeProof == null) {
      Log.error('📜 ProofMode deserialization failed!', category: .video);
    }
  }

  /// Retry a failed upload and continue publishing.
  Future<PublishResult> retryUpload(VineDraft draft) async {
    if (_backgroundUploadId == null) {
      /// TODO(l10n): Replace with context.l10n when localization is added.
      return const PublishError('No upload to retry.');
    }

    onStateChanged(.retryUpload);

    try {
      await uploadManager.retryUpload(_backgroundUploadId!);
      final success = await _pollUploadProgress(_backgroundUploadId!);

      if (!success) {
        final upload = uploadManager.getUpload(_backgroundUploadId!);

        /// TODO(l10n): Replace with context.l10n when localization is added.
        return PublishError(
          'Retry failed: ${upload?.errorMessage ?? "Unknown error"}',
        );
      }

      // Continue with publishing
      return await publishVideo(draft: draft);
    } catch (e, stackTrace) {
      Log.error('📝 Failed to retry: $e', category: LogCategory.video);
      return _handleUploadError(e, stackTrace, draft);
    }
  }

  /// Handles upload errors by logging, updating draft status, and returning
  /// a user-friendly message.
  Future<PublishError> _handleUploadError(
    Object? e,
    StackTrace stackTrace,
    VineDraft draft,
  ) async {
    Log.error('📝 Publish failed: $e\n$stackTrace', category: .video);

    onStateChanged(.error);

    // Save failed state to draft
    try {
      final failedDraft = draft.copyWith(
        publishStatus: .failed,
        publishError: e.toString(),
        publishAttempts: draft.publishAttempts + 1,
      );
      await draftService.saveDraft(failedDraft);
    } catch (saveError) {
      Log.error('📝 Failed to save error state: $saveError', category: .video);
    }

    final userMessage = await _getUserFriendlyErrorMessage(e);
    return PublishError(userMessage);
  }

  /// Converts technical error messages into user-friendly descriptions.
  Future<String> _getUserFriendlyErrorMessage(Object? e) async {
    final errorString = e.toString();
    var serverName = 'Unknown server';

    try {
      final serverUrl = await blossomService.getBlossomServer();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        serverName = Uri.tryParse(serverUrl)?.host ?? serverUrl;
      }
    } catch (_) {}

    /// TODO(l10n): Replace with context.l10n when localization is added.
    if (errorString.contains('404') || errorString.contains('not_found')) {
      return 'The Blossom media server ($serverName) is not working. '
          'You can choose another in your settings.';
    } else if (errorString.contains('500')) {
      return 'The Blossom media server ($serverName) encountered an error. '
          'You can choose another in your settings.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    } else if (errorString.contains('Not authenticated')) {
      return 'Please sign in to publish videos.';
    }
    return 'Failed to publish video. Please try again.';
  }
}
