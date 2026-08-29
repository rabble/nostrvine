// ABOUTME: Per-upload performance metrics recorded by the upload pipeline,
// ABOUTME: shared by UploadManager and UploadProgressReporter.

/// Upload performance metrics
class UploadMetrics {
  const UploadMetrics({
    required this.uploadId,
    required this.startTime,
    required this.retryCount,
    required this.fileSizeMB,
    required this.wasSuccessful,
    this.endTime,
    this.uploadDuration,
    this.throughputMBps,
    this.errorCategory,
  });
  final String uploadId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? uploadDuration;
  final int retryCount;
  final double fileSizeMB;
  final double? throughputMBps;
  final String? errorCategory;
  final bool wasSuccessful;
}
