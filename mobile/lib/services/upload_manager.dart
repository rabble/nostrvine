// ABOUTME: Service for managing video upload state and local persistence
// ABOUTME: Handles upload queue, retries, and coordination between UI and Cloudinary service

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/pending_upload.dart';
import 'cloudinary_upload_service.dart';

/// Manages video uploads and their persistent state
class UploadManager extends ChangeNotifier {
  static const String _uploadsBoxName = 'pending_uploads';
  
  Box<PendingUpload>? _uploadsBox;
  final CloudinaryUploadService _cloudinaryService;
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  
  UploadManager({required CloudinaryUploadService cloudinaryService})
      : _cloudinaryService = cloudinaryService;

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

  /// Perform the actual upload to Cloudinary
  Future<void> _performUpload(PendingUpload upload) async {
    try {
      // Update status to uploading
      await _updateUpload(upload.copyWith(status: UploadStatus.uploading));
      
      final videoFile = File(upload.localVideoPath);
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: ${upload.localVideoPath}');
      }
      
      // Start the upload with progress tracking
      final result = await _cloudinaryService.uploadVideo(
        videoFile: videoFile,
        nostrPubkey: upload.nostrPubkey,
        title: upload.title,
        description: upload.description,
        hashtags: upload.hashtags,
        onProgress: (progress) {
          _updateUploadProgress(upload.id, progress);
        },
      );
      
      if (result.success) {
        // Upload successful, now processing
        await _updateUpload(upload.copyWith(
          status: UploadStatus.processing,
          cloudinaryPublicId: result.cloudinaryPublicId,
          uploadProgress: 1.0,
        ));
        
        debugPrint('✅ Upload completed, video is now processing: ${result.cloudinaryPublicId}');
      } else {
        // Upload failed
        await _updateUpload(upload.copyWith(
          status: UploadStatus.failed,
          errorMessage: result.errorMessage,
          retryCount: (upload.retryCount ?? 0) + 1,
        ));
        
        debugPrint('❌ Upload failed: ${result.errorMessage}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Upload error for ${upload.id}: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      await _updateUpload(upload.copyWith(
        status: UploadStatus.failed,
        errorMessage: e.toString(),
        retryCount: (upload.retryCount ?? 0) + 1,
      ));
    }
  }

  /// Update upload progress
  void _updateUploadProgress(String uploadId, double progress) {
    final upload = getUpload(uploadId);
    if (upload != null && upload.status == UploadStatus.uploading) {
      _updateUpload(upload.copyWith(uploadProgress: progress));
    }
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

  /// Cancel an upload
  Future<void> cancelUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;
    
    debugPrint('🚫 Cancelling upload: $uploadId');
    
    // Cancel any active upload
    if (upload.cloudinaryPublicId != null) {
      await _cloudinaryService.cancelUpload(upload.cloudinaryPublicId!);
    }
    
    // Remove from storage
    await _uploadsBox?.delete(uploadId);
    
    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);
    
    notifyListeners();
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

  @override
  void dispose() {
    // Cancel all progress subscriptions
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();
    
    // Close Hive box
    _uploadsBox?.close();
    
    super.dispose();
  }
}