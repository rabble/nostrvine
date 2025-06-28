// ABOUTME: Service for managing video upload state and local persistence
// ABOUTME: Handles upload queue, retries, and coordination between UI and Cloudinary service

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_upload.dart';
import '../utils/async_utils.dart';
import 'direct_upload_service.dart';
import 'circuit_breaker_service.dart';

/// Upload retry configuration
class UploadRetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration networkTimeout;
  
  const UploadRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.networkTimeout = const Duration(minutes: 10),
  });
}

/// Upload performance metrics
class UploadMetrics {
  final String uploadId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? uploadDuration;
  final int retryCount;
  final double fileSizeMB;
  final double? throughputMBps;
  final String? errorCategory;
  final bool wasSuccessful;
  
  const UploadMetrics({
    required this.uploadId,
    required this.startTime,
    this.endTime,
    this.uploadDuration,
    required this.retryCount,
    required this.fileSizeMB,
    this.throughputMBps,
    this.errorCategory,
    required this.wasSuccessful,
  });
}

/// Manages video uploads and their persistent state with enhanced reliability
class UploadManager extends ChangeNotifier {
  static const String _uploadsBoxName = 'pending_uploads';
  
  // Core services
  Box<PendingUpload>? _uploadsBox;
  final DirectUploadService _uploadService;
  final VideoCircuitBreaker _circuitBreaker;
  final UploadRetryConfig _retryConfig;
  
  // State tracking
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Map<String, UploadMetrics> _uploadMetrics = {};
  final Map<String, Timer> _retryTimers = {};
  
  UploadManager({
    required DirectUploadService uploadService,
    VideoCircuitBreaker? circuitBreaker,
    UploadRetryConfig? retryConfig,
  }) : _uploadService = uploadService,
       _circuitBreaker = circuitBreaker ?? VideoCircuitBreaker(),
       _retryConfig = retryConfig ?? const UploadRetryConfig();

  /// Initialize the upload manager and load persisted uploads
  Future<void> initialize() async {
    debugPrint('🔧 Initializing UploadManager');
    
    try {
      // Initialize Hive adapters
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UploadStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PendingUploadAdapter());
      }
      
      // Open the uploads box
      _uploadsBox = await Hive.openBox<PendingUpload>(_uploadsBoxName);
      
      debugPrint('✅ UploadManager initialized with ${_uploadsBox!.length} existing uploads');
      
      // Clean up any problematic uploads first
      await cleanupProblematicUploads();
      
      // Resume any interrupted uploads
      await _resumeInterruptedUploads();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize UploadManager: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all pending uploads
  List<PendingUpload> get pendingUploads {
    if (_uploadsBox == null) return [];
    return _uploadsBox!.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  /// Get uploads by status
  List<PendingUpload> getUploadsByStatus(UploadStatus status) {
    return pendingUploads.where((upload) => upload.status == status).toList();
  }

  /// Get a specific upload by ID
  PendingUpload? getUpload(String id) {
    return _uploadsBox?.get(id);
  }
  
  /// Get an upload by file path
  PendingUpload? getUploadByFilePath(String filePath) {
    try {
      return pendingUploads.firstWhere(
        (upload) => upload.localVideoPath == filePath,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update an upload's status to published with Nostr event ID
  Future<void> markUploadPublished(String uploadId, String nostrEventId) async {
    final upload = getUpload(uploadId);
    if (upload != null) {
      final updatedUpload = upload.copyWith(
        status: UploadStatus.published,
        nostrEventId: nostrEventId,
        completedAt: DateTime.now(),
      );
      
      await _updateUpload(updatedUpload);
      debugPrint('✅ Upload marked as published: $uploadId -> $nostrEventId');
    } else {
      debugPrint('⚠️ Could not find upload to mark as published: $uploadId');
    }
  }

  /// Update an upload's status to ready for publishing
  Future<void> markUploadReadyToPublish(String uploadId, String cloudinaryPublicId) async {
    final upload = getUpload(uploadId);
    if (upload != null) {
      final updatedUpload = upload.copyWith(
        status: UploadStatus.readyToPublish,
        cloudinaryPublicId: cloudinaryPublicId,
      );
      
      await _updateUpload(updatedUpload);
      debugPrint('📋 Upload marked as ready to publish: $uploadId');
    }
  }

  /// Get uploads that are ready for background processing
  List<PendingUpload> get uploadsReadyForProcessing {
    return getUploadsByStatus(UploadStatus.processing);
  }

  /// Start a new video upload
  Future<PendingUpload> startUpload({
    required File videoFile,
    required String nostrPubkey,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    debugPrint('🚀 Starting new upload: ${videoFile.path}');
    
    // Create pending upload record
    final upload = PendingUpload.create(
      localVideoPath: videoFile.path,
      nostrPubkey: nostrPubkey,
      thumbnailPath: thumbnailPath,
      title: title,
      description: description,
      hashtags: hashtags,
    );
    
    // Save to local storage
    await _saveUpload(upload);
    
    // Start the upload process
    _performUpload(upload);
    
    return upload;
  }

  /// Perform upload with circuit breaker and retry logic
  Future<void> _performUpload(PendingUpload upload) async {
    final startTime = DateTime.now();
    final videoFile = File(upload.localVideoPath);
    
    // Initialize metrics
    _uploadMetrics[upload.id] = UploadMetrics(
      uploadId: upload.id,
      startTime: startTime,
      retryCount: upload.retryCount ?? 0,
      fileSizeMB: videoFile.existsSync() ? videoFile.lengthSync() / (1024 * 1024) : 0,
      wasSuccessful: false,
    );
    
    try {
      await _performUploadWithRetry(upload, videoFile);
    } catch (e) {
      await _handleUploadFailure(upload, e);
    }
  }

  /// Perform upload with exponential backoff retry using proper async patterns
  Future<void> _performUploadWithRetry(PendingUpload upload, File videoFile) async {
    try {
      await AsyncUtils.retryWithBackoff(
        operation: () async {
          // Check circuit breaker state
          if (!_circuitBreaker.allowRequests) {
            throw Exception('Circuit breaker is open - service unavailable');
          }
          
          // Update status based on current retry count
          final currentRetry = upload.retryCount ?? 0;
          debugPrint('🚀 Upload attempt ${currentRetry + 1}/${_retryConfig.maxRetries + 1} for ${upload.id}');
          
          await _updateUpload(upload.copyWith(
            status: currentRetry == 0 ? UploadStatus.uploading : UploadStatus.retrying,
            retryCount: currentRetry,
          ));
          
          // Validate file still exists
          if (!videoFile.existsSync()) {
            throw Exception('Video file not found: ${upload.localVideoPath}');
          }
          
          // Execute upload with timeout
          final result = await _executeUploadWithTimeout(upload, videoFile);
          
          // Success - record metrics and complete
          await _handleUploadSuccess(upload, result);
          _circuitBreaker.recordSuccess(upload.localVideoPath);
        },
        maxRetries: _retryConfig.maxRetries,
        baseDelay: _retryConfig.initialDelay,
        maxDelay: _retryConfig.maxDelay,
        backoffMultiplier: _retryConfig.backoffMultiplier,
        retryWhen: (error) {
          _circuitBreaker.recordFailure(upload.localVideoPath, error.toString());
          return _isRetriableError(error);
        },
        debugName: 'Upload-${upload.id}',
      );
    } catch (e) {
      debugPrint('❌ Upload failed after all retries: $e');
      rethrow;
    }
  }

  /// Execute upload with timeout and progress tracking
  Future<dynamic> _executeUploadWithTimeout(PendingUpload upload, File videoFile) async {
    return await _uploadService.uploadVideo(
      videoFile: videoFile,
      nostrPubkey: upload.nostrPubkey,
      title: upload.title,
      description: upload.description,
      hashtags: upload.hashtags,
      onProgress: (progress) {
        _updateUploadProgress(upload.id, progress);
      },
    ).timeout(
      _retryConfig.networkTimeout,
      onTimeout: () {
        throw TimeoutException('Upload timed out after ${_retryConfig.networkTimeout.inMinutes} minutes');
      },
    );
  }

  /// Handle successful upload
  Future<void> _handleUploadSuccess(PendingUpload upload, dynamic result) async {
    final endTime = DateTime.now();
    final metrics = _uploadMetrics[upload.id];
    
    if (result.success) {
      final updatedUpload = upload.copyWith(
        status: UploadStatus.readyToPublish,  // Direct upload is immediately ready
        cloudinaryPublicId: result.videoId,   // Use videoId for existing systems
        videoId: result.videoId,               // Store videoId for new publishing system
        cdnUrl: result.cdnUrl,                 // Store CDN URL directly
        thumbnailPath: result.thumbnailUrl,    // Store thumbnail URL
        uploadProgress: 1.0,
        completedAt: endTime,
      );
      
      await _updateUpload(updatedUpload);
      
      // Record successful metrics
      if (metrics != null) {
        final duration = endTime.difference(metrics.startTime);
        final throughput = metrics.fileSizeMB / duration.inSeconds;
        
        _uploadMetrics[upload.id] = UploadMetrics(
          uploadId: upload.id,
          startTime: metrics.startTime,
          endTime: endTime,
          uploadDuration: duration,
          retryCount: upload.retryCount ?? 0,
          fileSizeMB: metrics.fileSizeMB,
          throughputMBps: throughput,
          wasSuccessful: true,
        );
        
        debugPrint('✅ Direct upload successful: ${result.videoId}');
        debugPrint('🔗 CDN URL: ${result.cdnUrl}');
        debugPrint('📊 Upload metrics: ${metrics.fileSizeMB.toStringAsFixed(1)}MB in ${duration.inSeconds}s (${throughput.toStringAsFixed(2)} MB/s)');
      }
      
      // Notify that upload is ready for immediate publishing
      notifyListeners();
    } else {
      throw Exception(result.errorMessage ?? 'Upload failed with unknown error');
    }
  }

  /// Handle upload failure
  Future<void> _handleUploadFailure(PendingUpload upload, dynamic error) async {
    final endTime = DateTime.now();
    final metrics = _uploadMetrics[upload.id];
    final errorCategory = _categorizeError(error);
    
    debugPrint('❌ Upload failed for ${upload.id}: $error');
    debugPrint('🏷️ Error category: $errorCategory');
    
    await _updateUpload(upload.copyWith(
      status: UploadStatus.failed,
      errorMessage: error.toString(),
      retryCount: (upload.retryCount ?? 0),
    ));
    
    // Record failure metrics
    if (metrics != null) {
      _uploadMetrics[upload.id] = UploadMetrics(
        uploadId: upload.id,
        startTime: metrics.startTime,
        endTime: endTime,
        uploadDuration: endTime.difference(metrics.startTime),
        retryCount: upload.retryCount ?? 0,
        fileSizeMB: metrics.fileSizeMB,
        errorCategory: errorCategory,
        wasSuccessful: false,
      );
    }
  }

  /// Check if error is retriable
  bool _isRetriableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Network and timeout errors are retriable
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return true;
    }
    
    // Server errors (5xx) are retriable
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504')) {
      return true;
    }
    
    // Client errors (4xx) are generally not retriable
    if (errorStr.contains('400') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('404')) {
      return false;
    }
    
    // File not found errors are not retriable
    if (errorStr.contains('file not found') ||
        errorStr.contains('does not exist')) {
      return false;
    }
    
    // Unknown errors are retriable by default
    return true;
  }

  /// Categorize error for monitoring
  String _categorizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) return 'TIMEOUT';
    if (errorStr.contains('network') || errorStr.contains('connection')) return 'NETWORK';
    if (errorStr.contains('file not found')) return 'FILE_NOT_FOUND';
    if (errorStr.contains('memory')) return 'MEMORY';
    if (errorStr.contains('permission')) return 'PERMISSION';
    if (errorStr.contains('auth')) return 'AUTHENTICATION';
    if (errorStr.contains('5')) return 'SERVER_ERROR';
    if (errorStr.contains('4')) return 'CLIENT_ERROR';
    
    return 'UNKNOWN';
  }

  /// Update upload progress
  void _updateUploadProgress(String uploadId, double progress) {
    final upload = getUpload(uploadId);
    if (upload != null && upload.status == UploadStatus.uploading) {
      _updateUpload(upload.copyWith(uploadProgress: progress));
    }
  }

  /// Pause an active upload
  Future<void> pauseUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      debugPrint('❌ Upload not found for pause: $uploadId');
      return;
    }
    
    if (upload.status != UploadStatus.uploading) {
      debugPrint('❌ Upload is not currently uploading: ${upload.status}');
      return;
    }
    
    debugPrint('⏸️ Pausing upload: $uploadId');
    
    // Cancel the active upload (similar to cancelUpload but non-destructive)
    if (upload.cloudinaryPublicId != null) {
      await _uploadService.cancelUpload(upload.cloudinaryPublicId!);
    }
    
    // Update status to paused instead of failed
    final pausedUpload = upload.copyWith(
      status: UploadStatus.paused,
      // Keep current progress and don't set error message
    );
    
    await _updateUpload(pausedUpload);
    
    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);
    
    debugPrint('✅ Upload paused: $uploadId');
  }

  /// Resume a paused upload
  Future<void> resumeUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      debugPrint('❌ Upload not found for resume: $uploadId');
      return;
    }
    
    if (upload.status != UploadStatus.paused) {
      debugPrint('❌ Upload is not paused: ${upload.status}');
      return;
    }
    
    debugPrint('▶️ Resuming upload: $uploadId');
    
    // Reset to pending to restart upload from beginning
    final resumedUpload = upload.copyWith(
      status: UploadStatus.pending,
      uploadProgress: 0.0, // Reset progress since we're starting over
      errorMessage: null,
    );
    
    await _updateUpload(resumedUpload);
    
    // Start upload process again
    _performUpload(resumedUpload);
    
    debugPrint('✅ Upload resumed: $uploadId');
  }

  /// Retry a failed upload
  Future<void> retryUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      debugPrint('❌ Upload not found for retry: $uploadId');
      return;
    }
    
    if (!upload.canRetry) {
      debugPrint('❌ Upload cannot be retried: $uploadId (retries: ${upload.retryCount})');
      return;
    }
    
    debugPrint('🔄 Retrying upload: $uploadId');
    
    // Reset status and error
    final resetUpload = upload.copyWith(
      status: UploadStatus.pending,
      errorMessage: null,
      uploadProgress: null,
    );
    
    await _updateUpload(resetUpload);
    
    // Start upload again
    _performUpload(resetUpload);
  }

  /// Cancel an upload (stops the upload but keeps it for retry)
  Future<void> cancelUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;
    
    debugPrint('🚫 Cancelling upload: $uploadId');
    
    // Cancel any active upload
    if (upload.cloudinaryPublicId != null) {
      await _uploadService.cancelUpload(upload.cloudinaryPublicId!);
    }
    
    // Update status to failed so it can be retried later
    final cancelledUpload = upload.copyWith(
      status: UploadStatus.failed,
      errorMessage: 'Upload cancelled by user',
      uploadProgress: null,
    );
    
    await _updateUpload(cancelledUpload);
    
    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);
    
    debugPrint('✅ Upload cancelled and available for retry: $uploadId');
  }

  /// Delete an upload permanently (removes from storage)
  Future<void> deleteUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;
    
    debugPrint('🗑️ Deleting upload: $uploadId');
    
    // Cancel any active upload first
    if (upload.status == UploadStatus.uploading) {
      if (upload.cloudinaryPublicId != null) {
        await _uploadService.cancelUpload(upload.cloudinaryPublicId!);
      }
    }
    
    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);
    
    // Remove from storage
    await _uploadsBox?.delete(uploadId);
    
    notifyListeners();
    debugPrint('✅ Upload deleted permanently: $uploadId');
  }

  /// Remove completed or failed uploads
  Future<void> cleanupCompletedUploads() async {
    if (_uploadsBox == null) return;
    
    final completedUploads = pendingUploads
        .where((upload) => upload.isCompleted)
        .where((upload) => upload.completedAt != null)
        .where((upload) => 
            DateTime.now().difference(upload.completedAt!).inDays > 7) // Keep for 7 days
        .toList();
    
    for (final upload in completedUploads) {
      await _uploadsBox!.delete(upload.id);
      debugPrint('🗑️ Cleaned up old upload: ${upload.id}');
    }
    
    if (completedUploads.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Resume any uploads that were interrupted
  Future<void> _resumeInterruptedUploads() async {
    final interruptedUploads = pendingUploads
        .where((upload) => upload.status == UploadStatus.uploading)
        .toList();
    
    for (final upload in interruptedUploads) {
      debugPrint('🔄 Resuming interrupted upload: ${upload.id}');
      
      // Reset to pending and restart
      final resetUpload = upload.copyWith(
        status: UploadStatus.pending,
        uploadProgress: null,
      );
      
      await _updateUpload(resetUpload);
      _performUpload(resetUpload);
    }
  }

  /// Save upload to local storage
  Future<void> _saveUpload(PendingUpload upload) async {
    if (_uploadsBox == null) {
      throw Exception('UploadManager not initialized');
    }
    
    await _uploadsBox!.put(upload.id, upload);
    notifyListeners();
  }

  /// Update existing upload
  Future<void> _updateUpload(PendingUpload upload) async {
    if (_uploadsBox == null) return;
    
    await _uploadsBox!.put(upload.id, upload);
    notifyListeners();
  }
  
  /// Update upload status (public method for VideoEventPublisher)
  Future<void> updateUploadStatus(String uploadId, UploadStatus status, {String? nostrEventId}) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      debugPrint('⚠️ Upload not found for status update: $uploadId');
      return;
    }
    
    final updatedUpload = upload.copyWith(
      status: status,
      nostrEventId: nostrEventId ?? upload.nostrEventId,
      completedAt: status == UploadStatus.published ? DateTime.now() : upload.completedAt,
    );
    
    await _updateUpload(updatedUpload);
    debugPrint('✅ Updated upload status: $uploadId -> $status');
  }

  /// Get upload statistics
  Map<String, int> get uploadStats {
    final uploads = pendingUploads;
    return {
      'total': uploads.length,
      'pending': uploads.where((u) => u.status == UploadStatus.pending).length,
      'uploading': uploads.where((u) => u.status == UploadStatus.uploading).length,
      'processing': uploads.where((u) => u.status == UploadStatus.processing).length,
      'ready': uploads.where((u) => u.status == UploadStatus.readyToPublish).length,
      'published': uploads.where((u) => u.status == UploadStatus.published).length,
      'failed': uploads.where((u) => u.status == UploadStatus.failed).length,
    };
  }

  /// Fix uploads stuck in readyToPublish without proper data (debug method)
  Future<void> cleanupProblematicUploads() async {
    final uploads = pendingUploads;
    int fixedCount = 0;
    
    for (final upload in uploads) {
      // Fix uploads that are ready to publish but missing required data
      // These should be moved back to failed status so user can retry
      if (upload.status == UploadStatus.readyToPublish && 
          (upload.videoId == null || upload.cdnUrl == null)) {
        debugPrint('🔄 Fixing stuck upload: ${upload.id} (missing videoId/cdnUrl) - moving to failed');
        final fixedUpload = upload.copyWith(status: UploadStatus.failed);
        await _updateUpload(fixedUpload);
        fixedCount++;
      }
    }
    
    if (fixedCount > 0) {
      debugPrint('🔄 Fixed $fixedCount stuck uploads - moved back to failed status');
      notifyListeners();
    }
  }

  /// Get comprehensive performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final metrics = _uploadMetrics.values.toList();
    final successful = metrics.where((m) => m.wasSuccessful).toList();
    final failed = metrics.where((m) => !m.wasSuccessful).toList();
    
    return {
      'total_uploads': metrics.length,
      'successful_uploads': successful.length,
      'failed_uploads': failed.length,
      'success_rate': metrics.isNotEmpty ? (successful.length / metrics.length * 100) : 0,
      'average_throughput_mbps': successful.isNotEmpty 
          ? successful.map((m) => m.throughputMBps ?? 0).reduce((a, b) => a + b) / successful.length
          : 0,
      'average_retry_count': metrics.isNotEmpty
          ? metrics.map((m) => m.retryCount).reduce((a, b) => a + b) / metrics.length
          : 0,
      'error_categories': _getErrorCategoriesCount(failed),
      'circuit_breaker_state': _circuitBreaker.state.toString(),
      'circuit_breaker_failure_rate': _circuitBreaker.failureRate,
    };
  }

  /// Get error categories breakdown
  Map<String, int> _getErrorCategoriesCount(List<UploadMetrics> failedMetrics) {
    final categories = <String, int>{};
    for (final metric in failedMetrics) {
      final category = metric.errorCategory ?? 'UNKNOWN';
      categories[category] = (categories[category] ?? 0) + 1;
    }
    return categories;
  }

  /// Get upload metrics for a specific upload
  UploadMetrics? getUploadMetrics(String uploadId) {
    return _uploadMetrics[uploadId];
  }

  /// Get recent upload metrics (last 24 hours)
  List<UploadMetrics> getRecentMetrics() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    
    return _uploadMetrics.values
        .where((m) => m.startTime.isAfter(cutoff))
        .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Clear old metrics to prevent memory bloat
  void _cleanupOldMetrics() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7)); // Keep 1 week
    
    _uploadMetrics.removeWhere((key, metric) => 
        metric.startTime.isBefore(cutoff));
  }

  /// Enhanced retry mechanism for manual retry
  Future<void> retryUploadWithBackoff(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      debugPrint('⚠️ Upload not found for retry: $uploadId');
      return;
    }
    
    if (upload.status != UploadStatus.failed) {
      debugPrint('⚠️ Upload is not in failed state: ${upload.status}');
      return;
    }
    
    // Cancel any existing retry timer
    _retryTimers[uploadId]?.cancel();
    _retryTimers.remove(uploadId);
    
    debugPrint('🔄 Retrying upload with backoff: $uploadId');
    
    // Reset retry count if it's been more than 1 hour since last attempt
    final now = DateTime.now();
    final timeSinceLastAttempt = upload.completedAt != null 
        ? now.difference(upload.completedAt!)
        : now.difference(upload.createdAt);
    
    final shouldResetRetries = timeSinceLastAttempt.inHours >= 1;
    final newRetryCount = shouldResetRetries ? 0 : (upload.retryCount ?? 0);
    
    // Update upload with reset retry count if applicable
    final updatedUpload = upload.copyWith(
      status: UploadStatus.pending,
      retryCount: newRetryCount,
      errorMessage: null,
    );
    
    await _updateUpload(updatedUpload);
    
    // Start upload process
    await _performUpload(updatedUpload);
  }

  @override
  void dispose() {
    // Cancel all progress subscriptions
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();
    
    // Cancel all retry timers
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    
    // Clean up old metrics
    _cleanupOldMetrics();
    
    // Close Hive box
    _uploadsBox?.close();
    
    super.dispose();
  }
}