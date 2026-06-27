// ABOUTME: Progress tracking, network diagnostics, error categorisation, and
// ABOUTME: crash-report concerns extracted from UploadManager.

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/circuit_breaker_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/upload/pending_upload_store.dart';
import 'package:openvine/services/upload/upload_session_errors.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:unified_logger/unified_logger.dart';

/// Get platform name for logging (web-safe).
///
/// Duplicated from upload_manager.dart top-level helper to avoid
/// cross-file dependency on a private top-level function.
String _getPlatformName() {
  if (kIsWeb) return 'web';
  try {
    return defaultTargetPlatform.name;
  } catch (_) {
    return 'unknown';
  }
}

/// Owns the progress-tracking, network-diagnostic, error-categorisation, and
/// crash-report concerns extracted from [UploadManager].
class UploadProgressReporter {
  UploadProgressReporter({
    required PendingUploadStore store,
    required VideoCircuitBreaker circuitBreaker,
    required UploadRetryConfig retryConfig,
  }) : _store = store,
       _circuitBreaker = circuitBreaker,
       _retryConfig = retryConfig;

  final PendingUploadStore _store;
  final VideoCircuitBreaker _circuitBreaker;
  final UploadRetryConfig _retryConfig;

  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Map<String, UploadMetrics> _uploadMetrics = {};

  // ---------------------------------------------------------------------------
  // Metrics lifecycle
  // ---------------------------------------------------------------------------

  /// Record the start of an upload (replaces the initial `_uploadMetrics[id] =` assignment).
  void recordStart(String uploadId, UploadMetrics metrics) {
    _uploadMetrics[uploadId] = metrics;
  }

  /// Record a successful upload result and prune stale metrics.
  void recordSuccess(String uploadId, UploadMetrics metrics) {
    _uploadMetrics[uploadId] = metrics;
    _cleanupOldMetrics();
  }

  /// Record a failed upload result.
  void recordFailure(String uploadId, UploadMetrics metrics) {
    _uploadMetrics[uploadId] = metrics;
  }

  /// Return the in-memory metrics for [uploadId], or null if not present.
  UploadMetrics? metricsFor(String uploadId) => _uploadMetrics[uploadId];

  // ---------------------------------------------------------------------------
  // Progress subscriptions
  // ---------------------------------------------------------------------------

  /// Cancel and remove the progress subscription for [uploadId].
  void cancelAndRemoveSubscription(String uploadId) {
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);
  }

  // ---------------------------------------------------------------------------
  // Progress update (replaces _updateUploadProgress)
  // ---------------------------------------------------------------------------

  /// Update the persisted [progress] for [uploadId] when the upload is active.
  void updateProgress(String uploadId, double progress) {
    final upload = _store.getUpload(uploadId);
    if (upload != null &&
        (upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.retrying)) {
      _store.update(upload.copyWith(uploadProgress: progress));
    }
  }

  // ---------------------------------------------------------------------------
  // Network helpers (replaces _checkNetworkConnectivity / getNetworkTypeString)
  // ---------------------------------------------------------------------------

  /// Check current network connectivity, preferring WiFi > Cellular > Ethernet.
  Future<ConnectivityResult> checkNetworkConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      // connectivity_plus 7.x returns List<ConnectivityResult>
      final resultList = result.cast<ConnectivityResult>();
      if (resultList.contains(ConnectivityResult.wifi)) {
        return ConnectivityResult.wifi;
      }
      if (resultList.contains(ConnectivityResult.mobile)) {
        return ConnectivityResult.mobile;
      }
      if (resultList.contains(ConnectivityResult.ethernet)) {
        return ConnectivityResult.ethernet;
      }
      if (resultList.contains(ConnectivityResult.vpn)) {
        return ConnectivityResult.vpn;
      }
      return ConnectivityResult.none;
    } catch (e) {
      Log.error(
        'Failed to check network connectivity: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return ConnectivityResult.none;
    }
  }

  /// Convert a [ConnectivityResult] enum value to a human-readable string.
  String getNetworkTypeString(ConnectivityResult connectivity) {
    switch (connectivity) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Cellular';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.none:
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

  // ---------------------------------------------------------------------------
  // Error categorisation (replaces categorizeError / getUserFriendlyErrorMessage)
  // ---------------------------------------------------------------------------

  /// Categorise [error] into a string category constant for monitoring.
  Future<String> categorizeError(dynamic error) async {
    if (isExpiredResumableSessionError(error)) {
      return 'UPLOAD_SESSION_EXPIRED';
    }

    final connectivity = await checkNetworkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      return 'NO_INTERNET';
    }

    if (error is BlossomUploadFailureException) {
      // A failure to *produce* the signed auth header (the signer was briefly
      // unreachable) is a connectivity problem, not a server rejection. It
      // carries no HTTP status, so classify it on the typed reason and surface
      // the retry-friendly network copy instead of the generic UNKNOWN message.
      if (error.failureReason == BlossomUploadFailureReason.authUnavailable) {
        return 'NETWORK_ERROR';
      }

      final code = error.statusCode;
      if (code != null) {
        if (code == 408) return 'TIMEOUT';
        if (code == 413) return 'FILE_TOO_LARGE';
        if (code == 429) return 'RATE_LIMITED';
        if (code == 401 || code == 403) return 'AUTHENTICATION';
        if (code == 502 || code == 503 || code == 504) {
          return 'SERVER_UNAVAILABLE';
        }
        if (code >= 500) return 'SERVER_ERROR';
        if (code >= 400) return 'CLIENT_ERROR';
      }
    }

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timeout')) {
      if (connectivity == ConnectivityResult.mobile) {
        return 'SLOW_CONNECTION';
      }
      return 'TIMEOUT';
    }

    if (errorStr.contains('host') || errorStr.contains('dns')) {
      return 'DNS_ERROR';
    }

    if (errorStr.contains('cannot connect') ||
        errorStr.contains('network error') ||
        errorStr.contains('connection')) {
      return 'NETWORK_ERROR';
    }

    if (errorStr.contains('file not found')) return 'FILE_NOT_FOUND';
    if (errorStr.contains('memory')) return 'OUT_OF_MEMORY';
    if (errorStr.contains('permission')) return 'PERMISSION_DENIED';

    return 'UNKNOWN';
  }

  /// Return a user-friendly error message for the given [category].
  String getUserFriendlyErrorMessage(
    String category,
    ConnectivityResult connectivity,
  ) {
    switch (category) {
      case 'NO_INTERNET':
        return 'No internet connection. Check your WiFi or cellular data and try again.';

      case 'SLOW_CONNECTION':
        return 'Upload timed out on cellular data. Try connecting to WiFi for faster uploads.';

      case 'TIMEOUT':
        return 'Upload timed out. Your connection might be slow. Try again or connect to WiFi.';

      case 'NETWORK_ERROR':
        final networkType = getNetworkTypeString(connectivity);
        return 'Network error on $networkType. Check your connection and try again.';

      case 'DNS_ERROR':
        return 'Could not reach the upload server. Check your connection or try a different network.';

      case 'FILE_NOT_FOUND':
        return 'Video file not found. Please record the video again.';

      case 'FILE_TOO_LARGE':
        return 'Video is too large to upload. Try recording a shorter video.';

      case 'OUT_OF_MEMORY':
        return 'Not enough memory to upload. Close other apps and try again.';

      case 'PERMISSION_DENIED':
        return 'Permission denied. Check app permissions in Settings.';

      case 'AUTHENTICATION':
        return 'Authentication failed. Please sign in again.';

      case 'UPLOAD_SESSION_EXPIRED':
        return 'Upload session expired. Please retry the upload.';

      case 'RATE_LIMITED':
        return 'Too many uploads. Please wait a moment and try again.';

      case 'SERVER_UNAVAILABLE':
        return 'Upload server is temporarily unavailable. '
            'It will retry automatically.';

      case 'SERVER_ERROR':
        return 'Upload server encountered an error. Please try again later.';

      case 'CLIENT_ERROR':
        return 'Upload request failed. Please try again.';

      default:
        return 'Upload failed. Please check your connection and try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Metrics computation (replaces _createSuccessMetrics / _logUploadSuccess)
  // ---------------------------------------------------------------------------

  /// Compute success metrics from [currentMetrics] at [endTime].
  UploadMetrics createSuccessMetrics(
    UploadMetrics currentMetrics,
    DateTime endTime,
    int retryCount,
  ) {
    final duration = endTime.difference(currentMetrics.startTime);
    final throughput = _calculateThroughput(
      currentMetrics.fileSizeMB,
      duration,
    );

    return UploadMetrics(
      uploadId: currentMetrics.uploadId,
      startTime: currentMetrics.startTime,
      endTime: endTime,
      uploadDuration: duration,
      retryCount: retryCount,
      fileSizeMB: currentMetrics.fileSizeMB,
      throughputMBps: throughput,
      wasSuccessful: true,
    );
  }

  /// Log upload-success details at debug level.
  void logUploadSuccess(dynamic result, UploadMetrics metrics) {
    Log.info(
      'Direct upload successful: ${result.videoId}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.debug(
      '🎬 CDN URL: ${result.cdnUrl}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final durationStr = metrics.uploadDuration?.inSeconds ?? 0;
    final throughputStr = metrics.throughputMBps?.toStringAsFixed(2) ?? '0.00';

    Log.debug(
      'Upload metrics: ${metrics.fileSizeMB.toStringAsFixed(1)}MB in ${durationStr}s ($throughputStr MB/s)',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  // ---------------------------------------------------------------------------
  // Performance metrics (replaces getPerformanceMetrics)
  // ---------------------------------------------------------------------------

  /// Return aggregate performance statistics for all tracked uploads.
  Map<String, dynamic> getPerformanceMetrics() {
    final metrics = _uploadMetrics.values.toList();
    final successful = metrics.where((m) => m.wasSuccessful).toList();
    final failed = metrics.where((m) => !m.wasSuccessful).toList();

    return {
      'total_uploads': metrics.length,
      'successful_uploads': successful.length,
      'failed_uploads': failed.length,
      'success_rate': metrics.isNotEmpty
          ? (successful.length / metrics.length * 100)
          : 0,
      'average_throughput_mbps': successful.isNotEmpty
          ? successful
                    .map((m) => m.throughputMBps ?? 0)
                    .reduce((a, b) => a + b) /
                successful.length
          : 0,
      'average_retry_count': metrics.isNotEmpty
          ? metrics.map((m) => m.retryCount).reduce((a, b) => a + b) /
                metrics.length
          : 0,
      'error_categories': _getErrorCategoriesCount(failed),
      'circuit_breaker_state': _circuitBreaker.state.toString(),
      'circuit_breaker_failure_rate': _circuitBreaker.failureRate,
    };
  }

  // ---------------------------------------------------------------------------
  // Crash reports (replaces _sendUpload/Initialization/TimeoutCrashReport)
  // ---------------------------------------------------------------------------

  /// Send a comprehensive upload-failure report to Crashlytics.
  Future<void> sendUploadFailureCrashReport(
    PendingUpload upload,
    dynamic error,
    String errorCategory,
    UploadMetrics? metrics,
    ConnectivityResult connectivity, {
    required bool isManagerInitialized,
  }) async {
    try {
      final crashReporting = CrashReportingService.instance;

      final context = {
        'upload_id': upload.id,
        'upload_status': upload.status.toString(),
        'error_category': errorCategory,
        'retry_count': upload.retryCount ?? 0,
        'can_retry': upload.canRetry,
        'upload_target': 'blossomServer',
        'circuit_breaker_state': _circuitBreaker.state.toString(),
        'circuit_breaker_failure_rate': _circuitBreaker.failureRate,
        'local_file_path': upload.localVideoPath,
        'video_id': upload.videoId,
        'cdn_url': upload.cdnUrl,
        'upload_progress': upload.uploadProgress,
        'created_at': upload.createdAt.toIso8601String(),
        'file_exists': !kIsWeb && File(upload.localVideoPath).existsSync(),
        // Network connectivity information
        'network_type': getNetworkTypeString(connectivity),
        'network_status': connectivity.toString(),
        'is_offline': connectivity == ConnectivityResult.none,
        'is_cellular': connectivity == ConnectivityResult.mobile,
        'is_wifi': connectivity == ConnectivityResult.wifi,
      };

      if (metrics != null) {
        context.addAll({
          'file_size_mb': metrics.fileSizeMB,
          'start_time': metrics.startTime.toIso8601String(),
          'upload_duration_seconds': metrics.uploadDuration?.inSeconds,
          'throughput_mbps': metrics.throughputMBps,
          'metrics_retry_count': metrics.retryCount,
        });
      }

      context.addAll({
        'total_uploads': _store.length,
        'active_uploads': _progressSubscriptions.length,
        'queued_uploads': _store.queuedCount,
        'platform': _getPlatformName(),
        'is_initialized': isManagerInitialized,
        'timestamp': DateTime.now().toIso8601String(),
      });

      for (final entry in context.entries) {
        await crashReporting.setCustomKey(
          'upload_failure_${entry.key}',
          entry.value.toString(),
        );
      }

      final stackTrace = StackTrace.current;

      final fileExists = kIsWeb
          ? 'N/A (web)'
          : '${File(upload.localVideoPath).existsSync()}';
      final detailedError =
          '''
Upload Failure Report:
- Upload ID: ${upload.id}
- Error Category: $errorCategory
- Error: $error
- Network: ${getNetworkTypeString(connectivity)} (${connectivity == ConnectivityResult.none ? 'OFFLINE' : 'ONLINE'})
- File: ${upload.localVideoPath}
- File Exists: $fileExists
- Upload Status: ${upload.status}
- Retry Count: ${upload.retryCount ?? 0}
- Can Retry: ${upload.canRetry}
- Circuit Breaker: ${_circuitBreaker.state} (${_circuitBreaker.failureRate}% failure rate)
- Upload Target: blossomServer
${metrics != null ? '- File Size: ${metrics.fileSizeMB} MB\n- Duration: ${metrics.uploadDuration}\n- Throughput: ${metrics.throughputMBps} MB/s' : ''}
''';

      crashReporting.log('UPLOAD_FAILURE: $detailedError');

      await crashReporting.recordError(
        error,
        stackTrace,
        reason: 'Video upload failure - $errorCategory',
      );

      Log.info(
        '📊 Sent comprehensive upload failure report to Crashlytics',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (crashReportingError) {
      Log.error(
        'Failed to send crash report for upload failure: $crashReportingError',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Send an initialization-failure report to Crashlytics.
  Future<void> sendInitializationFailureCrashReport(
    dynamic error,
    StackTrace stackTrace,
  ) async {
    try {
      final crashReporting = CrashReportingService.instance;

      await crashReporting.setCustomKey('init_failure_error', error.toString());
      await crashReporting.setCustomKey(
        'init_failure_platform',
        _getPlatformName(),
      );
      await crashReporting.setCustomKey(
        'init_failure_timestamp',
        DateTime.now().toIso8601String(),
      );
      await crashReporting.setCustomKey(
        'init_failure_retry_attempts',
        'multiple',
      );

      final detailedError =
          '''
UploadManager Initialization Failure:
- Error: $error
- Platform: ${_getPlatformName()}
- Timestamp: ${DateTime.now().toIso8601String()}
- Context: Failed after all retry attempts in UploadInitializationHelper
''';

      crashReporting.log('INIT_FAILURE: $detailedError');

      await crashReporting.recordError(
        error,
        stackTrace,
        reason: 'UploadManager initialization failure after retries',
      );

      Log.info(
        '📊 Sent UploadManager initialization failure report to Crashlytics',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (crashReportingError) {
      Log.error(
        'Failed to send initialization crash report: $crashReportingError',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Send an upload-timeout failure report to Crashlytics.
  Future<void> sendTimeoutCrashReport(
    PendingUpload upload,
    TimeoutException timeoutError,
  ) async {
    try {
      final crashReporting = CrashReportingService.instance;

      final context = {
        'timeout_upload_id': upload.id,
        'timeout_file_path': upload.localVideoPath,
        'timeout_upload_target': 'blossomServer',
        'timeout_network_timeout_minutes':
            _retryConfig.networkTimeout.inMinutes,
        'timeout_retry_count': upload.retryCount ?? 0,
        'timeout_upload_status': upload.status.toString(),
        'timeout_platform': _getPlatformName(),
        'timeout_file_exists':
            !kIsWeb && File(upload.localVideoPath).existsSync(),
        'timeout_timestamp': DateTime.now().toIso8601String(),
      };

      for (final entry in context.entries) {
        await crashReporting.setCustomKey(entry.key, entry.value.toString());
      }

      final fileExists = kIsWeb
          ? 'N/A (web)'
          : '${File(upload.localVideoPath).existsSync()}';
      final detailedError =
          '''
Upload Timeout Failure:
- Upload ID: ${upload.id}
- File: ${upload.localVideoPath}
- File Exists: $fileExists
- Upload Target: blossomServer
- Timeout Duration: ${_retryConfig.networkTimeout.inMinutes} minutes
- Retry Count: ${upload.retryCount ?? 0}
- Upload Status: ${upload.status}
- Platform: ${_getPlatformName()}
- Timestamp: ${DateTime.now().toIso8601String()}
''';

      crashReporting.log('TIMEOUT_FAILURE: $detailedError');

      await crashReporting.recordError(
        timeoutError,
        StackTrace.current,
        reason:
            'Video upload timeout after ${_retryConfig.networkTimeout.inMinutes} minutes',
      );

      Log.info(
        '📊 Sent upload timeout failure report to Crashlytics',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (crashReportingError) {
      Log.error(
        'Failed to send timeout crash report: $crashReportingError',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();
    // Drop all metrics (not just the 7-day prune) so a later initialize()
    // starts from a clean slate and the disposed reporter frees its memory.
    _uploadMetrics.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Map<String, int> _getErrorCategoriesCount(List<UploadMetrics> failedMetrics) {
    final categories = <String, int>{};
    for (final metric in failedMetrics) {
      final category = metric.errorCategory ?? 'UNKNOWN';
      categories[category] = (categories[category] ?? 0) + 1;
    }
    return categories;
  }

  void _cleanupOldMetrics() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));

    _uploadMetrics.removeWhere(
      (key, metric) => metric.startTime.isBefore(cutoff),
    );
  }

  double _calculateThroughput(double fileSizeMB, Duration duration) {
    if (duration.inMicroseconds == 0) {
      return fileSizeMB * 1000; // Assume instant = 1ms
    }
    return fileSizeMB / (duration.inMicroseconds / 1000000.0);
  }
}
