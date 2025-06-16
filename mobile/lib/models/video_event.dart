// ABOUTME: NIP-71 Video Event model for handling kind 22 short video events
// ABOUTME: Parses and structures video content data from Nostr relays

import 'package:dart_nostr/dart_nostr.dart';

/// Represents a NIP-71 video event (kind 22 for short videos)
class VideoEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final String content;
  final String? title;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? duration; // in seconds
  final String? dimensions; // WIDTHxHEIGHT
  final String? mimeType;
  final String? sha256;
  final int? fileSize;
  final List<String> hashtags;
  final DateTime timestamp;
  final String? publishedAt;
  final Map<String, String> rawTags;
  
  const VideoEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.content,
    required this.timestamp,
    this.title,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.dimensions,
    this.mimeType,
    this.sha256,
    this.fileSize,
    this.hashtags = const [],
    this.publishedAt,
    this.rawTags = const {},
  });
  
  /// Create VideoEvent from Nostr event
  factory VideoEvent.fromNostrEvent(NostrEvent event) {
    if (event.kind != 22) {
      throw ArgumentError('Event must be kind 22 (short video)');
    }
    
    final tags = <String, String>{};
    final hashtags = <String>[];
    String? videoUrl;
    String? thumbnailUrl;
    String? title;
    int? duration;
    String? dimensions;
    String? mimeType;
    String? sha256;
    int? fileSize;
    String? publishedAt;
    
    // Parse event tags according to NIP-71
    for (final tag in event.tags) {
      if (tag.isEmpty) continue;
      
      final tagName = tag[0];
      final tagValue = tag.length > 1 ? tag[1] : '';
      
      switch (tagName) {
        case 'url':
          videoUrl = tagValue;
          break;
        case 'title':
          title = tagValue;
          break;
        case 'published_at':
          publishedAt = tagValue;
          break;
        case 'duration':
          duration = int.tryParse(tagValue);
          break;
        case 'dim':
          dimensions = tagValue;
          break;
        case 'm':
          mimeType = tagValue;
          break;
        case 'x':
          sha256 = tagValue;
          break;
        case 'size':
          fileSize = int.tryParse(tagValue);
          break;
        case 'thumb':
          thumbnailUrl = tagValue;
          break;
        case 't':
          if (tagValue.isNotEmpty) {
            hashtags.add(tagValue);
          }
          break;
      }
      
      // Store all tags for potential future use
      tags[tagName] = tagValue;
    }
    
    final createdAtTimestamp = event.createdAt is int 
      ? event.createdAt as int
      : (event.createdAt is DateTime 
          ? (event.createdAt as DateTime).millisecondsSinceEpoch ~/ 1000
          : int.tryParse(event.createdAt.toString()) ?? 0);
    
    return VideoEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: createdAtTimestamp,
      content: event.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp * 1000),
      title: title,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      dimensions: dimensions,
      mimeType: mimeType,
      sha256: sha256,
      fileSize: fileSize,
      hashtags: hashtags,
      publishedAt: publishedAt,
      rawTags: tags,
    );
  }
  
  /// Extract width from dimensions string
  int? get width {
    if (dimensions == null) return null;
    final parts = dimensions!.split('x');
    return parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  }
  
  /// Extract height from dimensions string
  int? get height {
    if (dimensions == null) return null;
    final parts = dimensions!.split('x');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }
  
  /// Check if video is in portrait orientation
  bool get isPortrait {
    if (width == null || height == null) return false;
    return height! > width!;
  }
  
  /// Get file size in MB
  double? get fileSizeMB {
    if (fileSize == null) return null;
    return fileSize! / (1024 * 1024);
  }
  
  /// Get formatted duration string (e.g., "0:15")
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Get relative time string (e.g., "2 hours ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
  
  /// Get shortened pubkey for display (first 8 characters + npub prefix)
  String get displayPubkey {
    // In a real implementation, convert to npub format
    // For now, just show first 8 chars
    return pubkey.length > 8 ? pubkey.substring(0, 8) : pubkey;
  }
  
  /// Check if this event has video content
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  
  /// Check if video URL is a GIF
  bool get isGif {
    if (mimeType != null) {
      return mimeType!.toLowerCase() == 'image/gif';
    }
    if (videoUrl != null) {
      return videoUrl!.toLowerCase().endsWith('.gif');
    }
    return false;
  }
  
  /// Check if video URL is MP4
  bool get isMp4 {
    if (mimeType != null) {
      return mimeType!.toLowerCase() == 'video/mp4';
    }
    if (videoUrl != null) {
      return videoUrl!.toLowerCase().endsWith('.mp4');
    }
    return false;
  }
  
  /// Create a copy with updated fields
  VideoEvent copyWith({
    String? id,
    String? pubkey,
    int? createdAt,
    String? content,
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    String? dimensions,
    String? mimeType,
    String? sha256,
    int? fileSize,
    List<String>? hashtags,
    DateTime? timestamp,
    String? publishedAt,
    Map<String, String>? rawTags,
  }) {
    return VideoEvent(
      id: id ?? this.id,
      pubkey: pubkey ?? this.pubkey,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      dimensions: dimensions ?? this.dimensions,
      mimeType: mimeType ?? this.mimeType,
      sha256: sha256 ?? this.sha256,
      fileSize: fileSize ?? this.fileSize,
      hashtags: hashtags ?? this.hashtags,
      timestamp: timestamp ?? this.timestamp,
      publishedAt: publishedAt ?? this.publishedAt,
      rawTags: rawTags ?? this.rawTags,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoEvent && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'VideoEvent('
           'id: ${id.substring(0, 8)}..., '
           'pubkey: $displayPubkey, '
           'title: $title, '
           'duration: $formattedDuration, '
           'time: $relativeTime'
           ')';
  }
}

/// Exception thrown when parsing video events
class VideoEventException implements Exception {
  final String message;
  
  const VideoEventException(this.message);
  
  @override
  String toString() => 'VideoEventException: $message';
}