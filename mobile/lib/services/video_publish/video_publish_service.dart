// ABOUTME: Service for publishing videos to Nostr with upload management
// ABOUTME: Handles video upload to Blossom servers, retry logic, and Nostr event creation

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of a publish operation.
sealed class PublishResult extends Equatable {
  const PublishResult();

  @override
  List<Object?> get props => [];
}

class PublishSuccess extends PublishResult {
  const PublishSuccess();
}

class PublishError extends PublishResult {
  const PublishError(this.userMessage);
  final String userMessage;

  @override
  List<Object?> get props => [userMessage];
}

/// Callbacks for VideoPublishService to communicate state changes.
/// This abstraction makes the service testable without Riverpod dependencies.
typedef OnStateChanged = void Function(VideoPublishState state);
typedef OnProgressChanged =
    void Function({required String draftId, required double progress});

class VideoPublishService {
  VideoPublishService({
    required this.uploadManager,
    required this.authService,
    required this.videoEventPublisher,
    required this.blossomService,
    required this.draftService,
    required this.onProgressChanged,
    this.languagePreferenceService,
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

  /// Callback when upload progress changes.
  final OnProgressChanged onProgressChanged;

  /// Language preference for NIP-32 tagging.
  final LanguagePreferenceService? languagePreferenceService;

  /// Tracks the current background upload ID.
  String? _backgroundUploadId;

  /// Publishes a video draft.
  /// Returns [PublishSuccess] on success, [PublishError] on failure.
  Future<PublishResult> publishVideo({required DivineVideoDraft draft}) async {
    // Check if we have a background upload ID and its status
    if (_backgroundUploadId != null) {
      final error = await _handleActiveUpload(draft.id);
      if (error != null) return error;
    }

    try {
      final publishing = draft.copyWith(publishStatus: .publishing);
      await draftService.saveDraft(publishing);

      final videoPath = await draft.clips.first.video.safeFilePath();
      Log.info('📝 Publishing video: $videoPath', category: .video);

      // Verify user is fully authenticated
      if (!authService.isAuthenticated) {
        Log.warning(
          '⚠️ User not authenticated, cannot publish',
          category: .video,
        );
        _backgroundUploadId = null;
        // TODO(l10n): Replace with context.l10n when localization is added.
        return const PublishError('Please sign in to publish videos.');
      }
      final pubkey = authService.currentPublicKeyHex!;

      // Use existing upload if available, otherwise start new upload
      final pendingUpload = await _getOrCreateUpload(pubkey, draft);
      if (pendingUpload == null) {
        Log.error('❌ Upload creation failed', category: .video);
        final failedUpload = _backgroundUploadId != null
            ? uploadManager.getUpload(_backgroundUploadId!)
            : null;
        return await _handleUploadError(
          failedUpload?.errorMessage ?? 'Upload failed',
          StackTrace.current,
          draft,
        );
      }

      // Check if upload failed
      if (pendingUpload.status == .failed) {
        Log.error(
          '❌ Upload status is failed: ${pendingUpload.errorMessage}',
          category: .video,
        );
        return await _handleUploadError(
          pendingUpload.errorMessage ?? 'Upload failed',
          StackTrace.current,
          draft,
        );
      }

      // Publish Nostr event
      Log.info('📝 Publishing Nostr event...', category: .video);

      final published = await videoEventPublisher.publishVideoEvent(
        upload: pendingUpload,
        title: draft.title,
        description: draft.description,
        hashtags: draft.hashtags.toList(),
        expirationTimestamp: draft.expireTime != null
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                  draft.expireTime!.inSeconds
            : null,
        allowAudioReuse: draft.allowAudioReuse,
        collaboratorPubkeys: draft.collaboratorPubkeys.toList(),
        inspiredByAddressableId: draft.inspiredByVideo?.addressableId,
        inspiredByRelayUrl: draft.inspiredByVideo?.relayUrl,
        inspiredByNpub: draft.inspiredByNpub,
        selectedAudioEventId: draft.selectedSound?.id,
        selectedAudioRelay: draft.selectedSound?.sourceVideoRelay,
        language: languagePreferenceService?.contentLanguage,
        contentWarning: draft.contentWarning,
      );

      if (!published) {
        Log.error('❌ Failed to publish Nostr event', category: .video);
        return await _handleUploadError(
          Exception('Failed to publish Nostr event'),
          StackTrace.current,
          draft,
        );
      }

      // Success: delete draft
      await draftService.deleteDraft(draft.id);
      Log.debug('🗑️ Deleted publish draft: ${draft.id}', category: .video);

      Log.info('📝 Published successfully', category: .video);
      return const PublishSuccess();
    } catch (e, stackTrace) {
      return _handleUploadError(e, stackTrace, draft);
    }
  }

  /// Gets existing upload from background ID, reuses a matching upload
  /// found by video path, or creates a new one.
  /// Returns null if upload creation fails.
  Future<PendingUpload?> _getOrCreateUpload(
    String pubkey,
    DivineVideoDraft draft,
  ) async {
    // 1. Check in-memory ID (covers same-session retry)
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

    // 2. Search for reusable upload by video path (covers app restart)
    final videoPath = await _resolveVideoPath(draft);
    if (videoPath != null) {
      final reusable = uploadManager.findReusableUpload(videoPath);
      if (reusable != null) {
        Log.info(
          '📝 Reusing existing upload ${reusable.id} '
          '(status: ${reusable.status})',
          category: .video,
        );
        _backgroundUploadId = reusable.id;
        return _handleReusableUpload(reusable, draft);
      }
    }

    // 3. Nothing reusable — start fresh
    return _startNewUpload(pubkey, draft);
  }

  /// Resolves the video file path from a draft, mirroring the logic
  /// in [UploadManager.startUploadFromDraft].
  ///
  /// Note: when `finalRenderedClip` is absent and the draft has multiple
  /// clips, this returns the first source clip path. However,
  /// [UploadManager.startUploadFromDraft] merges multiple clips into a
  /// temp file at a different path, so [findReusableUpload] will not
  /// match in that case. The caller falls through to a new upload, which
  /// is the correct behavior since the merged file is ephemeral.
  Future<String?> _resolveVideoPath(DivineVideoDraft draft) async {
    try {
      final rendered = draft.finalRenderedClip;
      if (rendered != null) {
        final path = await rendered.video.safeFilePath();
        if (File(path).existsSync()) return path;
      }
      if (draft.clips.isNotEmpty) {
        return draft.clips.first.video.safeFilePath();
      }
    } catch (e) {
      Log.warning('⚠️ Could not resolve video path: $e', category: .video);
    }
    return null;
  }

  /// Handles a reusable upload found by video path.
  ///
  /// Depending on the upload's current status, either returns it directly
  /// (readyToPublish), kicks it off and polls (uploading/retrying), or
  /// retries it (failed with resumable session).
  Future<PendingUpload?> _handleReusableUpload(
    PendingUpload upload,
    DivineVideoDraft draft,
  ) async {
    switch (upload.status) {
      case UploadStatus.readyToPublish:
        return upload;
      case UploadStatus.uploading:
      case UploadStatus.retrying:
        uploadManager.resumeInterruptedUpload(upload.id);
        final ok = await _pollUploadProgress(draft.id, upload.id);
        return ok ? uploadManager.getUpload(upload.id) : null;
      case UploadStatus.processing:
        final ok = await _pollUploadProgress(draft.id, upload.id);
        return ok ? uploadManager.getUpload(upload.id) : null;
      case UploadStatus.failed:
        // findReusableUpload guarantees a resumable session exists.
        // Don't await — let the retry run in the background so
        // _pollUploadProgress can report progress to the UI.
        unawaited(uploadManager.retryUpload(upload.id));
        final ok = await _pollUploadProgress(draft.id, upload.id);
        return ok ? uploadManager.getUpload(upload.id) : null;
      case UploadStatus.pending:
      case UploadStatus.paused:
      case UploadStatus.published:
        return null;
    }
  }

  /// Handles an active background upload.
  /// Returns [PublishError] if there was an error, null to continue.
  Future<PublishError?> _handleActiveUpload(String draftId) async {
    final upload = uploadManager.getUpload(_backgroundUploadId!);
    if (upload == null) return null;

    Log.debug(
      '📤 Checking active upload: ${upload.id}, status: ${upload.status}',
      category: .video,
    );

    // If already ready, continue
    if (upload.status == .readyToPublish) return null;

    // If failed, return error
    if (upload.status == .failed) {
      _backgroundUploadId = null; // Clear failed upload ID
      final msg = await _getUserFriendlyErrorMessage(
        upload.errorMessage ?? 'Upload failed',
      );
      return PublishError(msg);
    }

    // Wait for upload to complete
    if (upload.status == .uploading || upload.status == .processing) {
      final result = await _pollUploadProgress(draftId, _backgroundUploadId!);
      if (!result) {
        final failedUpload = uploadManager.getUpload(_backgroundUploadId!);
        _backgroundUploadId = null; // Clear failed upload ID
        final msg = await _getUserFriendlyErrorMessage(
          failedUpload?.errorMessage ?? 'Upload failed',
        );
        return PublishError(msg);
      }
    }

    return null;
  }

  /// Polls upload progress until complete or failed.
  /// Returns true if upload succeeded, false if failed.
  Future<bool> _pollUploadProgress(String draftId, String uploadId) async {
    final upload = uploadManager.getUpload(uploadId);
    if (upload == null) return false;

    onProgressChanged(draftId: draftId, progress: upload.uploadProgress ?? 0.0);

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
        await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _pollUploadProgress(draftId, uploadId);
  }

  /// Starts a new upload and polls for progress until completion.
  /// Returns the upload if successful, null if failed.
  Future<PendingUpload?> _startNewUpload(
    String pubkey,
    DivineVideoDraft draft,
  ) async {
    // Ensure upload manager is initialized
    if (!uploadManager.isInitialized) {
      Log.info('📝 Initializing upload manager...', category: .video);
      await uploadManager.initialize();
    }

    Log.info('📝 Starting upload to Blossom...', category: .video);
    _logProofModeStatus(draft);

    final pendingUpload = await uploadManager.startUploadFromDraft(
      draft: draft,
      nostrPubkey: pubkey,
      onProgress: (value) =>
          onProgressChanged(draftId: draft.id, progress: value),
    );
    _backgroundUploadId = pendingUpload.id;

    // Poll for progress
    final success = await _pollUploadProgress(draft.id, pendingUpload.id);
    if (!success) return null;

    return uploadManager.getUpload(pendingUpload.id);
  }

  /// Logs ProofMode attestation status for debugging.
  void _logProofModeStatus(DivineVideoDraft draft) {
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
  Future<PublishResult> retryUpload(DivineVideoDraft draft) async {
    if (_backgroundUploadId == null) {
      Log.warning('⚠️ No background upload to retry', category: .video);

      _backgroundUploadId = null; // Clear any stale upload ID
      /// TODO(l10n): Replace with context.l10n when localization is added.
      return const PublishError('No upload to retry.');
    }

    Log.info('🔄 Retrying upload: $_backgroundUploadId', category: .video);
    try {
      await uploadManager.retryUpload(_backgroundUploadId!);
      final success = await _pollUploadProgress(draft.id, _backgroundUploadId!);

      if (!success) {
        final upload = uploadManager.getUpload(_backgroundUploadId!);
        _backgroundUploadId = null;
        return await _handleUploadError(
          upload?.errorMessage ?? 'Retry failed',
          StackTrace.current,
          draft,
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
    DivineVideoDraft draft,
  ) async {
    _backgroundUploadId = null;
    Log.error('📝 Publish failed: $e\n$stackTrace', category: .video);

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
  ///
  /// If the error is already a user-friendly string (e.g. from the upload
  /// manager), it is returned as-is instead of falling through to the
  /// generic fallback.
  Future<String> _getUserFriendlyErrorMessage(Object? e) async {
    final raw = e.toString();
    final errorString = raw.toLowerCase();

    // Errors from the upload manager may already be user-friendly strings.
    // Detect them by stripping any "Exception: " prefix and checking
    // whether the remainder looks like a sentence, not a class/stack dump.
    final stripped = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (stripped != raw || e is String) {
      final clean = (e is String ? raw : stripped).trim();
      if (clean.isNotEmpty &&
          clean.contains('.') &&
          !clean.contains('Exception') &&
          !clean.contains('#0 ')) {
        return clean;
      }
    }
    var serverName = 'Unknown server';

    try {
      final serverUrl = await blossomService.getBlossomServer();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        serverName = Uri.tryParse(serverUrl)?.host ?? serverUrl;
      }
    } catch (_) {}

    /// TODO(l10n): Replace with context.l10n when localization is added.
    // Network / connectivity
    if (errorString.contains('socketexception') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no address associated') ||
        errorString.contains('failed host lookup')) {
      return 'No internet connection. '
          'Check your Wi-Fi or mobile data and try again.';
    }
    if (errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection closed')) {
      return 'Could not reach the server. Please try again in a moment.';
    }
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'The upload timed out. '
          'Try a stronger connection or a smaller video.';
    }

    // TLS / certificate
    if (errorString.contains('certificate') ||
        errorString.contains('handshake') ||
        errorString.contains('ssl') ||
        errorString.contains('tls')) {
      return 'Secure connection failed. '
          'Check your network — public Wi-Fi can block uploads.';
    }

    // Server errors
    if (errorString.contains('404') || errorString.contains('not_found')) {
      return 'The media server ($serverName) is not available. '
          'You can choose another in your settings.';
    }
    if (errorString.contains('413') ||
        errorString.contains('payload too large') ||
        errorString.contains('too large')) {
      return 'The video file is too large for the server. '
          'Try trimming it or lowering the quality.';
    }
    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'The media server ($serverName) had an internal error. '
          'You can choose another in your settings.';
    }
    if (errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('bad gateway') ||
        errorString.contains('service unavailable')) {
      return 'The media server ($serverName) is temporarily down. '
          'Try again shortly or choose another in your settings.';
    }

    // Auth
    if (errorString.contains('not authenticated') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return 'Please sign in to publish videos.';
    }
    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'You don\u2019t have permission to upload to this server.';
    }

    // Local file issues
    if (errorString.contains('no such file') ||
        errorString.contains('file not found') ||
        errorString.contains('pathnotfoundexception')) {
      return 'The video file could not be found. '
          'It may have been deleted. Re-record and try again.';
    }
    if (errorString.contains('storage') ||
        errorString.contains('no space') ||
        errorString.contains('disk full')) {
      return 'Not enough storage on your device. '
          'Free up some space and try again.';
    }

    // Nostr event publish
    if (errorString.contains('failed to publish nostr event') ||
        errorString.contains('relay')) {
      return 'The video uploaded but the post could not be published. '
          'Check your relay settings and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}
