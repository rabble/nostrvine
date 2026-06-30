// ABOUTME: Retry policy for video uploads — owns exponential backoff, session
// ABOUTME: persistence, and manual/automatic retry lifecycle for UploadManager.

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload/pending_upload_store.dart';
import 'package:openvine/services/upload/upload_session_errors.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the retry and session-persistence concerns extracted from [UploadManager].
class UploadRetryPolicy {
  UploadRetryPolicy({
    required PendingUploadStore store,
    required UploadRetryConfig retryConfig,
  }) : _store = store,
       _retryConfig = retryConfig;

  final PendingUploadStore _store;
  final UploadRetryConfig _retryConfig;

  final Map<String, Future<void>> _sessionPersistFutures = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> performWithRetry(
    PendingUpload upload,
    Future<void> Function() executeUpload, {
    required bool Function(dynamic) isRetriable,
  }) async {
    // Local-only counter for how many auto-attempts have been made in this
    // call. Must NOT be persisted to Hive: PendingUpload.retryCount is the
    // manual-retry budget (canRetry gates on retryCount < 3). Writing
    // auto-attempt counts there would exhaust the budget and prevent the user
    // from calling retryUpload() after a failed session.
    var autoAttempt = 0;

    try {
      await AsyncUtils.retryWithBackoff(
        operation: () async {
          await drainSessionPersist(upload.id);
          final currentUpload = _store.getUpload(upload.id) ?? upload;

          // autoAttempt is local to this performWithRetry invocation and is
          // never written to Hive, so the manual-retry budget is preserved.
          autoAttempt++;
          Log.warning(
            'Upload attempt $autoAttempt/${_retryConfig.maxRetries + 1} for ${currentUpload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );

          await _store.update(
            currentUpload.copyWith(
              status: autoAttempt == 1
                  ? UploadStatus.uploading
                  : UploadStatus.retrying,
              // retryCount is intentionally left unchanged here — it is the
              // manual-retry budget managed exclusively by retryUpload().
            ),
          );

          await executeUpload();
        },
        maxRetries: _retryConfig.maxRetries,
        baseDelay: _retryConfig.initialDelay,
        maxDelay: _retryConfig.maxDelay,
        backoffMultiplier: _retryConfig.backoffMultiplier,
        retryWhen: isRetriable,
        debugName: 'Upload-${upload.id}',
      );
    } catch (e) {
      Log.error(
        'Upload failed after all retries: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  void enqueueSessionPersist(
    String uploadId,
    BlossomResumableUploadSession session,
    int fileSizeBytes,
  ) {
    final previous = _sessionPersistFutures[uploadId] ?? Future<void>.value();
    final persistFuture = previous.then((_) async {
      try {
        await _storeResumableSessionProgress(uploadId, session, fileSizeBytes);
      } catch (e, s) {
        Log.error(
          'Failed to persist resumable session progress for $uploadId: $e',
          name: 'UploadManager',
          category: LogCategory.video,
          error: e,
          stackTrace: s,
        );
      }
    });
    _sessionPersistFutures[uploadId] = persistFuture;
    unawaited(
      persistFuture.whenComplete(() {
        if (identical(_sessionPersistFutures[uploadId], persistFuture)) {
          _sessionPersistFutures.remove(uploadId);
        }
      }),
    );
  }

  Future<void> drainSessionPersist(String uploadId) async {
    await (_sessionPersistFutures[uploadId] ?? Future<void>.value());
  }

  Future<void> retryUpload(
    String uploadId, {
    required Future<void> Function(PendingUpload) performUpload,
  }) async {
    final upload = _store.getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Upload not found for retry: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (!upload.canRetry) {
      Log.error(
        'Upload cannot be retried: $uploadId (retries: ${upload.retryCount})',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.warning(
      'Retrying upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final nextRetryCount = (upload.retryCount ?? 0) + 1;
    final resetUpload = upload.copyWith(
      status: UploadStatus.pending,
      retryCount: nextRetryCount,
    );

    await _store.update(resetUpload);
    await performUpload(resetUpload);
  }

  void resumeInterruptedUpload(
    String uploadId, {
    required Future<void> Function(PendingUpload) performUpload,
  }) {
    final upload = _store.getUpload(uploadId);
    if (upload == null) return;
    if (upload.status != UploadStatus.uploading &&
        upload.status != UploadStatus.retrying) {
      return;
    }

    Log.info(
      'Resuming interrupted upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final resumed = upload.copyWith(status: UploadStatus.uploading);
    unawaited(_store.update(resumed));
    unawaited(performUpload(resumed));
  }

  /// Re-run a failed upload, resetting the manual-retry budget when the last
  /// attempt is at least an hour old and otherwise incrementing it.
  ///
  /// Despite the name there is no backoff *timer* — the budget is the
  /// "backoff": [performUpload] is invoked immediately and the 1-hour reset
  /// window is what spaces out repeated manual retries.
  Future<void> retryUploadWithBackoff(
    String uploadId, {
    required Future<void> Function(PendingUpload) performUpload,
  }) async {
    final upload = _store.getUpload(uploadId);
    if (upload == null) {
      Log.warning(
        'Upload not found for retry: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.failed) {
      Log.error(
        'Upload is not in failed state: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.warning(
      'Retrying upload with backoff: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final now = DateTime.now();
    final timeSinceLastAttempt = upload.completedAt != null
        ? now.difference(upload.completedAt!)
        : now.difference(upload.createdAt);

    final shouldResetRetries = timeSinceLastAttempt.inHours >= 1;
    final newRetryCount = shouldResetRetries ? 1 : (upload.retryCount ?? 0) + 1;

    final updatedUpload = upload.copyWith(
      status: UploadStatus.pending,
      retryCount: newRetryCount,
    );

    await _store.update(updatedUpload);
    await performUpload(updatedUpload);
  }

  bool isRetriableError(dynamic error) {
    if (isExpiredResumableSessionError(error)) {
      return false;
    }

    // Use structured classification when available.
    if (error is BlossomUploadFailureException) {
      // A transient inability to *produce* a signed auth header (the remote
      // signer or its network path was briefly unreachable) is retriable —
      // distinct from a permanent 401/403 rejection handled below. This is
      // the fix for uploads that died on a momentary signer DNS blip.
      final reason = error.failureReason;
      if (reason == BlossomUploadFailureReason.authUnavailable ||
          reason == BlossomUploadFailureReason.network) {
        return true;
      }
      if (reason == BlossomUploadFailureReason.auth ||
          reason == BlossomUploadFailureReason.fileTooLarge) {
        return false;
      }

      final code = error.statusCode;
      if (code != null) {
        // 408 request timeout — retriable
        if (code == 408) return true;
        // 429 rate limited — retriable after backoff
        if (code == 429) return true;
        // Transient server errors — retriable
        if (code == 500 || code == 502 || code == 503 || code == 504) {
          return true;
        }
        // Other 5xx (501, 505, etc.) are permanent — not retriable
        if (code >= 500) return false;
        // 4xx client errors are not retriable
        if (code >= 400) return false;
      }
    }

    // Fall back to string matching for non-HTTP errors
    final errorStr = error.toString().toLowerCase();

    // A missing required thumbnail already exhausted the image upload's own
    // retry path; retrying here would re-upload the full video.
    if (errorStr.contains('thumbnail upload failed')) {
      return false;
    }

    // Network and timeout errors are retriable
    if (errorStr.contains('timeout') ||
        errorStr.contains('cannot connect') ||
        errorStr.contains('network error') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket')) {
      return true;
    }

    // File not found errors are not retriable
    if (errorStr.contains('file not found') ||
        errorStr.contains('does not exist')) {
      return false;
    }

    // Permission and cancellation failures are permanent. Authentication is
    // classified structurally above (failureReason / 401-403 statusCode): a
    // failed auth-header *creation* is transient while a server *rejection*
    // is not, and the bare substring 'auth' cannot tell them apart — so it
    // no longer gates retries here.
    if (errorStr.contains('permission') || errorStr.contains('cancelled')) {
      return false;
    }

    // Unknown errors are retriable by default
    return true;
  }

  void dispose() {
    _sessionPersistFutures.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _storeResumableSessionProgress(
    String uploadId,
    BlossomResumableUploadSession session,
    int fileSizeBytes,
  ) async {
    final upload = _store.getUpload(uploadId);
    if (upload == null) return;

    final persistedProgress = fileSizeBytes <= 0
        ? upload.uploadProgress
        : ((session.nextOffset / fileSizeBytes) * 0.8).clamp(0.0, 0.8);

    await _store.update(
      upload.copyWith(
        resumableSession: session,
        uploadProgress: persistedProgress,
      ),
    );
  }
}
