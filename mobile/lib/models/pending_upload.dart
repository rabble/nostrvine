// ABOUTME: Model for tracking video uploads to Cloudinary in various states
// ABOUTME: Supports local persistence and state management for async upload flow

import 'package:hive/hive.dart';

part 'pending_upload.g.dart';

/// Status of a video upload to Cloudinary
@HiveType(typeId: 1)
enum UploadStatus {
  @HiveField(0)
  pending,       // Waiting to start upload
  
  @HiveField(1)
  uploading,     // Currently uploading to Cloudinary
  
  @HiveField(2)
  retrying,      // Retrying after failure
  
  @HiveField(3)
  processing,    // Cloudinary is processing the video
  
  @HiveField(4)
  readyToPublish, // Processing complete, ready for Nostr publishing
  
  @HiveField(5)
  published,     // Successfully published to Nostr
  
  @HiveField(6)
  failed,        // Upload or processing failed
  
  @HiveField(7)
  paused,        // Upload paused by user
}

/// Represents a video upload in progress or completed
@HiveType(typeId: 2)
class PendingUpload {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String localVideoPath;
  
  @HiveField(2)
  final String nostrPubkey;
  
  @HiveField(3)
  final UploadStatus status;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final String? cloudinaryPublicId; // Deprecated - use videoId instead
  
  @HiveField(15)
  final String? videoId; // New field for direct upload
  
  @HiveField(16)
  final String? cdnUrl; // Direct CDN URL from upload
  
  @HiveField(6)
  final String? errorMessage;
  
  @HiveField(7)
  final double? uploadProgress; // 0.0 to 1.0
  
  @HiveField(8)
  final String? thumbnailPath;
  
  @HiveField(9)
  final String? title;
  
  @HiveField(10)
  final String? description;
  
  @HiveField(11)
  final List<String>? hashtags;
  
  @HiveField(12)
  final String? nostrEventId; // Set when published to Nostr
  
  @HiveField(13)
  final DateTime? completedAt;
  
  @HiveField(14)
  final int? retryCount;

  const PendingUpload({
    required this.id,
    required this.localVideoPath,
    required this.nostrPubkey,
    required this.status,
    required this.createdAt,
    this.cloudinaryPublicId,
    this.videoId,
    this.cdnUrl,
    this.errorMessage,
    this.uploadProgress,
    this.thumbnailPath,
    this.title,
    this.description,
    this.hashtags,
    this.nostrEventId,
    this.completedAt,
    this.retryCount = 0,
  });

  /// Create a new pending upload
  factory PendingUpload.create({
    required String localVideoPath,
    required String nostrPubkey,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
  }) {
    return PendingUpload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      localVideoPath: localVideoPath,
      nostrPubkey: nostrPubkey,
      status: UploadStatus.pending,
      createdAt: DateTime.now(),
      thumbnailPath: thumbnailPath,
      title: title,
      description: description,
      hashtags: hashtags,
    );
  }

  /// Copy with updated fields
  PendingUpload copyWith({
    String? id,
    String? localVideoPath,
    String? nostrPubkey,
    UploadStatus? status,
    DateTime? createdAt,
    String? cloudinaryPublicId,
    String? videoId,
    String? cdnUrl,
    String? errorMessage,
    double? uploadProgress,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    String? nostrEventId,
    DateTime? completedAt,
    int? retryCount,
  }) {
    return PendingUpload(
      id: id ?? this.id,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      nostrPubkey: nostrPubkey ?? this.nostrPubkey,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      videoId: videoId ?? this.videoId,
      cdnUrl: cdnUrl ?? this.cdnUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      title: title ?? this.title,
      description: description ?? this.description,
      hashtags: hashtags ?? this.hashtags,
      nostrEventId: nostrEventId ?? this.nostrEventId,
      completedAt: completedAt ?? this.completedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Check if the upload is in a terminal state
  bool get isCompleted => status == UploadStatus.published || status == UploadStatus.failed;

  /// Check if the upload can be retried
  bool get canRetry => status == UploadStatus.failed && (retryCount ?? 0) < 3;

  /// Get display-friendly status text
  String get statusText {
    switch (status) {
      case UploadStatus.pending:
        return 'Waiting to upload...';
      case UploadStatus.uploading:
        if (uploadProgress != null) {
          return 'Uploading ${(uploadProgress! * 100).toInt()}%...';
        }
        return 'Uploading...';
      case UploadStatus.retrying:
        return 'Retrying upload...';
      case UploadStatus.processing:
        return 'Processing video...';
      case UploadStatus.readyToPublish:
        return 'Ready to publish';
      case UploadStatus.published:
        return 'Published';
      case UploadStatus.failed:
        return 'Failed: ${errorMessage ?? 'Unknown error'}';
      case UploadStatus.paused:
        return 'Upload paused';
    }
  }

  /// Get progress value for UI (0.0 to 1.0)
  double get progressValue {
    switch (status) {
      case UploadStatus.pending:
        return 0.0;
      case UploadStatus.uploading:
        return uploadProgress ?? 0.0;
      case UploadStatus.retrying:
        return uploadProgress ?? 0.0;
      case UploadStatus.processing:
        return 0.8; // Show 80% when processing
      case UploadStatus.readyToPublish:
        return 0.9; // Show 90% when ready
      case UploadStatus.published:
        return 1.0;
      case UploadStatus.failed:
        return 0.0;
      case UploadStatus.paused:
        return uploadProgress ?? 0.0; // Preserve current progress
    }
  }

  @override
  String toString() {
    return 'PendingUpload{id: $id, status: $status, progress: $uploadProgress, cloudinaryId: $cloudinaryPublicId}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUpload &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}