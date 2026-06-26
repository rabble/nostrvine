// ABOUTME: Retry policy for video uploads — owns exponential backoff, session
// ABOUTME: persistence, and manual/automatic retry lifecycle for UploadManager.

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload/pending_upload_store.dart';
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

  final Map<String, Timer> _retryTimers = {};
  final Map<String, Future<void>> _sessionPersistFutures = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> performWithRetry(
    PendingUpload upload,
    Future<void> Function() executeUpload, {
    required bool Function(dynamic) isRetriable,
  }) async {
    var autoAttempt = 0;

    try {
      await AsyncUtils.retryWithBackoff(
        operation: () async {
          final currentUpload = _store.getUpload(upload.id) ?? upload;

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
    _sessionPersistFutures[uploadId] = previous.then((_) async {
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

    _retryTimers[uploadId]?.cancel();
    _retryTimers.remove(uploadId);

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
    if (_isExpiredResumableSessionError(error)) {
      return false;
    }

    if (error is BlossomUploadFailureException) {
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
        if (code == 408) return true;
        if (code == 429) return true;
        if (code == 500 || code == 502 || code == 503 || code == 504) {
          return true;
        }
        if (code >= 500) return false;
        if (code >= 400) return false;
      }
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('thumbnail upload failed')) {
      return false;
    }

    if (errorStr.contains('timeout') ||
        errorStr.contains('cannot connect') ||
        errorStr.contains('network error') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket')) {
      return true;
    }

    if (errorStr.contains('file not found') ||
        errorStr.contains('does not exist')) {
      return false;
    }

    if (errorStr.contains('permission') || errorStr.contains('cancelled')) {
      return false;
    }

    return true;
  }

  void dispose() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
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

  bool _isExpiredResumableSessionError(dynamic error) {
    if (error is BlossomResumableUploadException) {
      return error.statusCode == 404 || error.statusCode == 410;
    }

    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('session expired') ||
        errorMessage.contains('session is no longer available');
  }
}
