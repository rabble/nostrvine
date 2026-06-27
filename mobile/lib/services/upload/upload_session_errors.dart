// ABOUTME: Shared predicate for detecting expired resumable-upload sessions,
// ABOUTME: used by UploadRetryPolicy, UploadProgressReporter, and UploadManager.

import 'package:blossom_upload_service/blossom_upload_service.dart';

/// Returns true if [error] represents an expired resumable-upload session — the
/// server returned 404/410, or the message says the session is gone.
///
/// This predicate decides both whether the error is retriable *and* whether the
/// resumable session is nulled on failure, so the two used to drift between
/// independent copies in [UploadRetryPolicy] and [UploadProgressReporter]. It
/// lives here as a single source of truth to keep those callers in lockstep.
bool isExpiredResumableSessionError(dynamic error) {
  if (error is BlossomResumableUploadException) {
    return error.statusCode == 404 || error.statusCode == 410;
  }

  final errorMessage = error.toString().toLowerCase();
  return errorMessage.contains('session expired') ||
      errorMessage.contains('session is no longer available');
}
