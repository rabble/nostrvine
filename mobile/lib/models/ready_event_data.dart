// ABOUTME: Model for video events ready for Nostr publishing from Cloudinary processing
// ABOUTME: Contains all metadata needed to create and publish NIP-94 file metadata events

import 'package:hive/hive.dart';

part 'ready_event_data.g.dart';

/// Data for a video that's ready to be published to Nostr
@HiveType(typeId: 3)
class ReadyEventData {
  @HiveField(0)
  final String publicId; // Cloudinary public ID
  
  @HiveField(1)
  final String secureUrl; // Final video URL
  
  @HiveField(2)
  final String contentSuggestion; // Suggested content for the Nostr event
  
  @HiveField(3)
  final List<List<String>> tags; // NIP-94 tags for the event
  
  @HiveField(4)
  final Map<String, dynamic> metadata; // Additional metadata from Cloudinary
  
  @HiveField(5)
  final DateTime processedAt; // When Cloudinary finished processing
  
  @HiveField(6)
  final String originalUploadId; // Link back to original PendingUpload
  
  @HiveField(7)
  final String mimeType; // Video MIME type
  
  @HiveField(8)
  final int? fileSize; // File size in bytes
  
  @HiveField(9)
  final String? thumbnailUrl; // Thumbnail URL if available
  
  @HiveField(10)
  final int? width; // Video width
  
  @HiveField(11)
  final int? height; // Video height
  
  @HiveField(12)
  final double? duration; // Video duration in seconds
  
  @HiveField(13)
  final String? hash; // File hash for integrity

  const ReadyEventData({
    required this.publicId,
    required this.secureUrl,
    required this.contentSuggestion,
    required this.tags,
    required this.metadata,
    required this.processedAt,
    required this.originalUploadId,
    required this.mimeType,
    this.fileSize,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.duration,
    this.hash,
  });

  /// Create from JSON response from backend API
  factory ReadyEventData.fromJson(Map<String, dynamic> json) {
    return ReadyEventData(
      publicId: json['public_id'] as String,
      secureUrl: json['secure_url'] as String,
      contentSuggestion: json['content_suggestion'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>)
          .map((tag) => (tag as List<dynamic>).cast<String>())
          .toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      processedAt: DateTime.parse(json['processed_at'] as String),
      originalUploadId: json['original_upload_id'] as String,
      mimeType: json['mime_type'] as String,
      fileSize: json['file_size'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: (json['duration'] as num?)?.toDouble(),
      hash: json['hash'] as String?,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'public_id': publicId,
      'secure_url': secureUrl,
      'content_suggestion': contentSuggestion,
      'tags': tags,
      'metadata': metadata,
      'processed_at': processedAt.toIso8601String(),
      'original_upload_id': originalUploadId,
      'mime_type': mimeType,
      if (fileSize != null) 'file_size': fileSize,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      if (hash != null) 'hash': hash,
    };
  }

  /// Get the main URL tag for NIP-94
  List<String> get urlTag => ['url', secureUrl];

  /// Get the MIME type tag for NIP-94
  List<String> get mimeTypeTag => ['m', mimeType];

  /// Get the file size tag for NIP-94 (if available)
  List<String>? get fileSizeTag => fileSize != null ? ['size', fileSize.toString()] : null;

  /// Get the dimensions tag for NIP-94 (if available)
  List<String>? get dimensionsTag => 
      width != null && height != null ? ['dim', '${width}x$height'] : null;

  /// Get the duration tag for NIP-94 (if available)
  List<String>? get durationTag => 
      duration != null ? ['duration', duration!.round().toString()] : null;

  /// Get the hash tag for NIP-94 (if available)
  List<String>? get hashTag => hash != null ? ['x', hash!] : null;

  /// Get the thumbnail tag for NIP-94 (if available)
  List<String>? get thumbnailTag => thumbnailUrl != null ? ['thumb', thumbnailUrl!] : null;

  /// Generate all NIP-94 compatible tags
  List<List<String>> get nip94Tags {
    final allTags = <List<String>>[
      urlTag,
      mimeTypeTag,
      ...tags, // Include any custom tags from backend
    ];

    // Add optional tags if available
    if (fileSizeTag != null) allTags.add(fileSizeTag!);
    if (dimensionsTag != null) allTags.add(dimensionsTag!);
    if (durationTag != null) allTags.add(durationTag!);
    if (hashTag != null) allTags.add(hashTag!);
    if (thumbnailTag != null) allTags.add(thumbnailTag!);

    return allTags;
  }

  /// Check if this event has all required data for publishing
  bool get isReadyForPublishing {
    return publicId.isNotEmpty &&
           secureUrl.isNotEmpty &&
           mimeType.isNotEmpty &&
           originalUploadId.isNotEmpty;
  }

  /// Get display-friendly status
  String get statusDescription {
    if (!isReadyForPublishing) {
      return 'Missing required data';
    }
    return 'Ready for publishing';
  }

  /// Get estimated event size (for relay limits)
  int get estimatedEventSize {
    final content = contentSuggestion;
    final tagsJson = nip94Tags.toString();
    return content.length + tagsJson.length + 200; // Add overhead for other fields
  }

  @override
  String toString() {
    return 'ReadyEventData{publicId: $publicId, secureUrl: ${secureUrl.substring(0, 30)}..., originalUploadId: $originalUploadId}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadyEventData &&
          runtimeType == other.runtimeType &&
          publicId == other.publicId &&
          originalUploadId == other.originalUploadId;

  @override
  int get hashCode => publicId.hashCode ^ originalUploadId.hashCode;
}