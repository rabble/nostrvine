// ABOUTME: Service for managing default/featured content shown to new users
// ABOUTME: Provides fallback videos when the feed is empty or for onboarding

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import '../models/video_event.dart';

/// Service for managing default content shown to new users
class DefaultContentService {
  
  /// Default video that should appear first for new users
  /// This is Rabble's "Are we the bad guys?" video
  static const String _defaultVideoEventId = '329aa2cbeeb2b69f8b7aaf2e89a95ddbe50bd702e7d49cef14e78851f0853c50';
  
  /// Create a default VideoEvent for the featured video
  static VideoEvent createDefaultVideo() {
    // Create a mock Event object for the default video
    // In production, this would ideally be fetched from relays, but for fallback we create it manually
    
    // Use hex pubkey directly to avoid potential decoding issues
    const hexPubkey = '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd';
    
    final defaultEvent = Event(
      hexPubkey, // Rabble's pubkey in hex format
      22, // Kind 22 for short videos (NIP-71)
      [
        // NIP-71 video metadata tags
        ['title', 'Are we the bad guys?'],
        ['published_at', '1747864092'],
        ['duration', '3'],
        ['imeta', 'url https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4', 'dim 1920x1080', 'm video/mp4'],
        ['client', 'mkstack'],
      ],
      'Rabble on Twitter',
      createdAt: 1747864092, // Unix timestamp
    );
    
    try {
      return VideoEvent.fromNostrEvent(defaultEvent);
    } catch (e) {
      debugPrint('Error creating default video event: $e');
      // Return a minimal fallback video
      return _createFallbackVideo();
    }
  }
  
  /// Create a basic fallback video if the default video creation fails
  static VideoEvent _createFallbackVideo() {
    // Use hex pubkey directly to avoid potential decoding issues
    const hexPubkey = '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd';
    
    return VideoEvent(
      id: _defaultVideoEventId,
      pubkey: hexPubkey,
      createdAt: 1747864092,
      content: 'Rabble on Twitter',
      title: 'Are we the bad guys?',
      videoUrl: 'https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4',
      thumbnailUrl: 'https://picsum.photos/640/480?random=1',
      duration: 3,
      dimensions: '1920x1080',
      mimeType: 'video/mp4',
      sha256: null,
      fileSize: null,
      hashtags: [],
      timestamp: DateTime.fromMillisecondsSinceEpoch(1747864092 * 1000),
      publishedAt: '1747864092',
      rawTags: {},
      isRepost: false,
      reposterId: null,
      reposterPubkey: null,
      repostedAt: null,
    );
  }
  
  /// Get list of featured/default videos for new users
  /// Currently returns just the single default video, but can be expanded
  static List<VideoEvent> getDefaultVideos() {
    return [createDefaultVideo()];
  }
  
  /// Check if a video is one of the default/featured videos
  static bool isDefaultVideo(String videoId) {
    return videoId == _defaultVideoEventId;
  }
  
  /// Get the priority order for default videos (lower number = higher priority)
  static int getDefaultVideoPriority(String videoId) {
    if (videoId == _defaultVideoEventId) {
      return 0; // Highest priority
    }
    return 999; // Not a default video
  }
}