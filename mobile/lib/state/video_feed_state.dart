// ABOUTME: Freezed state model for video feed provider containing feed metadata
// ABOUTME: Represents the current state of the video feed including mode and content

import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/video_event.dart';

part 'video_feed_state.freezed.dart';

/// Available feed modes for content filtering
enum FeedMode {
  /// User's following list (or classic vines fallback)
  following,
  
  /// Classic vines curator content only  
  curated,
  
  /// General discovery content (currently disabled)
  discovery,
  
  /// Specific hashtag filter
  hashtag,
  
  /// Specific user profile
  profile,
}

/// State model for the video feed provider
@freezed
class VideoFeedState with _$VideoFeedState {
  const factory VideoFeedState({
    /// List of videos in the feed
    required List<VideoEvent> videos,
    
    /// Current feed mode
    required FeedMode feedMode,
    
    /// Whether this is a following-based feed
    required bool isFollowingFeed,
    
    /// Whether more content can be loaded
    required bool hasMoreContent,
    
    /// Number of videos from primary source (following/curated)
    required int primaryVideoCount,
    
    /// Loading state for pagination
    @Default(false) bool isLoadingMore,
    
    /// Refreshing state for pull-to-refresh
    @Default(false) bool isRefreshing,
    
    /// Current context value (hashtag or pubkey)
    String? feedContext,
    
    /// Error message if any
    String? error,
    
    /// Timestamp of last update
    DateTime? lastUpdated,
  }) = _VideoFeedState;
  
  const VideoFeedState._();
  
  /// Get discovery video count (total - primary)
  int get discoveryVideoCount => videos.length - primaryVideoCount;
  
  /// Check if at feed boundary between primary and discovery
  bool isAtFeedBoundary(int index) {
    return index == primaryVideoCount - 1 && discoveryVideoCount > 0;
  }
  
  /// Get feed display title
  String get feedTitle {
    return switch (feedMode) {
      FeedMode.following => isFollowingFeed ? 'Following' : 'Classic Vines',
      FeedMode.curated => 'Editor\'s Picks',
      FeedMode.discovery => 'Discover',
      FeedMode.hashtag => '#${feedContext ?? 'hashtag'}',
      FeedMode.profile => '@${feedContext ?? 'profile'}',
    };
  }
}