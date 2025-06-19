// ABOUTME: Abstract interface defining video management contract for TDD rebuild
// ABOUTME: Single source of truth interface replacing dual list system (VideoEventService + VideoCacheService)

import 'dart:async';
import '../models/video_event.dart';
import '../models/video_state.dart';

/// Interface for managing video state and lifecycle
/// 
/// This is the single source of truth for all video-related state.
/// Replaces the dual-list system (VideoEventService + VideoCacheService)
/// with a unified approach that eliminates race conditions and index mismatches.
/// 
/// Implementation must follow these principles:
/// - Immutable state transitions
/// - Memory management with configurable limits
/// - Circuit breaker pattern for failed videos
/// - Thread-safe operations
/// - Predictable cleanup lifecycle
abstract class IVideoManager {
  /// Get ordered list of videos for display (newest first)
  /// 
  /// This is the single source of truth - no more dual lists!
  /// Returns only videos that are not permanently failed.
  List<VideoEvent> get videos;
  
  /// Get videos that are ready to play immediately
  /// 
  /// Filtered subset of [videos] that have successfully loaded
  /// and have initialized video controllers.
  List<VideoEvent> get readyVideos;
  
  /// Get current state of a specific video
  /// 
  /// Returns null if video ID is not found.
  /// Use this to check loading state, errors, retry count, etc.
  VideoState? getVideoState(String videoId);
  
  /// Get controller for playback (null if not ready)
  /// 
  /// Returns a video controller only if the video is in ready state.
  /// Returns null for loading, failed, or not-loaded videos.
  dynamic getController(String videoId); // Dynamic to avoid video_player dependency in interface
  
  /// Add new video event (from Nostr or other source)
  /// 
  /// Adds video to the managed list and creates initial state.
  /// Prevents duplicates - calling with same video ID is a no-op.
  /// For GIF events, immediately marks as ready (no preloading needed).
  /// 
  /// Throws [VideoManagerException] if video event is invalid.
  Future<void> addVideoEvent(VideoEvent event);
  
  /// Preload video for smooth playback
  /// 
  /// Initiates video controller creation and initialization.
  /// Transitions video state from notLoaded -> loading -> ready/failed.
  /// Implements circuit breaker - permanently fails after max retries.
  /// 
  /// Returns immediately if video is already loading, ready, or permanently failed.
  /// Throws [VideoManagerException] if video ID is not found.
  Future<void> preloadVideo(String videoId);
  
  /// Preload videos around current position
  /// 
  /// Smart preloading strategy that loads current video + next N videos
  /// based on user's current viewing position. Also triggers cleanup
  /// of videos far from current position to manage memory.
  /// 
  /// [currentIndex] must be a valid index in the video list.
  void preloadAroundIndex(int currentIndex);
  
  /// Dispose specific video controller
  /// 
  /// Immediately disposes video controller and transitions to disposed state.
  /// Safe to call multiple times or on non-existent videos.
  /// Use this to free memory for videos no longer needed.
  void disposeVideo(String videoId);
  
  /// Get debug information for monitoring
  /// 
  /// Returns real-time statistics for system health monitoring:
  /// - Total video count
  /// - Ready/loading/failed video counts  
  /// - Estimated memory usage
  /// - Controller count
  /// - Configuration settings
  Map<String, dynamic> getDebugInfo();
  
  /// Clean up all resources
  /// 
  /// Disposes all video controllers, clears all state, and cancels
  /// any pending operations. After calling dispose(), this instance
  /// should not be used.
  void dispose();
  
  /// Stream of state changes for UI updates
  /// 
  /// Emits an event whenever video state changes (loading, ready, failed, etc).
  /// UI components should listen to this stream and rebuild accordingly.
  /// Stream closes when [dispose()] is called.
  Stream<void> get stateChanges;
}

/// Configuration for VideoManager behavior
/// 
/// Defines limits and behavior parameters that control memory usage,
/// preloading strategy, and error handling.
class VideoManagerConfig {
  /// Maximum number of videos to keep in memory
  /// 
  /// When this limit is exceeded, oldest videos are automatically
  /// cleaned up. Prevents unlimited memory growth.
  final int maxVideos;
  
  /// Number of videos to preload ahead of current position
  /// 
  /// Higher values provide smoother scrolling but use more memory.
  /// Lower values save memory but may cause loading delays.
  final int preloadAhead;
  
  /// Maximum retry attempts before marking video as permanently failed
  /// 
  /// After this many failures, video will not be retried automatically.
  /// Prevents infinite retry loops on broken videos.
  final int maxRetries;
  
  /// Timeout for video preloading operations
  /// 
  /// If video initialization takes longer than this, it's marked as failed
  /// and can be retried (up to maxRetries limit).
  final Duration preloadTimeout;
  
  /// Whether to enable automatic memory management
  /// 
  /// When true, automatically disposes distant video controllers to save memory.
  /// When false, videos are only disposed when explicitly requested.
  final bool enableMemoryManagement;
  
  /// Range of videos to keep around current position when cleaning up
  /// 
  /// During memory pressure, keeps this many videos before and after
  /// current position, disposing controllers for videos outside this range.
  final int memoryKeepRange;
  
  const VideoManagerConfig({
    this.maxVideos = 100,
    this.preloadAhead = 3,
    this.maxRetries = 3,
    this.preloadTimeout = const Duration(seconds: 10),
    this.enableMemoryManagement = true,
    this.memoryKeepRange = 10,
  });
  
  /// Create a configuration optimized for low memory devices
  factory VideoManagerConfig.lowMemory() {
    return const VideoManagerConfig(
      maxVideos = 50,
      preloadAhead = 2,
      maxRetries = 2,
      preloadTimeout = Duration(seconds: 15),
      enableMemoryManagement = true,
      memoryKeepRange = 5,
    );
  }
  
  /// Create a configuration optimized for high performance
  factory VideoManagerConfig.highPerformance() {
    return const VideoManagerConfig(
      maxVideos = 200,
      preloadAhead = 5,
      maxRetries = 4,
      preloadTimeout = Duration(seconds: 8),
      enableMemoryManagement = true,
      memoryKeepRange = 15,
    );
  }
}

/// Exceptions thrown by video manager
/// 
/// Provides structured error information for debugging and error handling.
class VideoManagerException implements Exception {
  /// Human-readable error message
  final String message;
  
  /// Video ID associated with the error (if applicable)
  final String? videoId;
  
  /// Original exception that caused this error (if any)
  final dynamic originalError;
  
  /// Error category for programmatic handling
  final VideoManagerErrorType type;
  
  const VideoManagerException(
    this.message, {
    this.videoId,
    this.originalError,
    this.type = VideoManagerErrorType.general,
  });
  
  /// Create exception for invalid video event
  factory VideoManagerException.invalidVideo(String videoId, String reason) {
    return VideoManagerException(
      'Invalid video event: $reason',
      videoId: videoId,
      type: VideoManagerErrorType.invalidVideo,
    );
  }
  
  /// Create exception for video not found
  factory VideoManagerException.videoNotFound(String videoId) {
    return VideoManagerException(
      'Video not found: $videoId',
      videoId: videoId,
      type: VideoManagerErrorType.videoNotFound,
    );
  }
  
  /// Create exception for preload failure
  factory VideoManagerException.preloadFailed(String videoId, dynamic originalError) {
    return VideoManagerException(
      'Failed to preload video: $videoId',
      videoId: videoId,
      originalError: originalError,
      type: VideoManagerErrorType.preloadFailed,
    );
  }
  
  /// Create exception for memory management failure
  factory VideoManagerException.memoryManagement(String reason) {
    return VideoManagerException(
      'Memory management error: $reason',
      type: VideoManagerErrorType.memoryManagement,
    );
  }
  
  @override
  String toString() {
    final buffer = StringBuffer('VideoManagerException: $message');
    
    if (videoId != null) {
      buffer.write(' (video: ${videoId!.length > 8 ? videoId!.substring(0, 8) + '...' : videoId})');
    }
    
    if (originalError != null) {
      buffer.write(' (caused by: $originalError)');
    }
    
    return buffer.toString();
  }
}

/// Categories of video manager errors for programmatic handling
enum VideoManagerErrorType {
  /// General unspecified error
  general,
  
  /// Invalid video event data
  invalidVideo,
  
  /// Video ID not found in manager
  videoNotFound,
  
  /// Video preloading failed
  preloadFailed,
  
  /// Memory management operation failed
  memoryManagement,
  
  /// Invalid index or range provided
  invalidIndex,
  
  /// Operation called on disposed manager
  disposed,
}

/// Interface for listening to video manager state changes
/// 
/// Provides granular event information for UI components that need
/// to react to specific types of state changes.
abstract class IVideoManagerListener {
  /// Called when a video is added to the manager
  void onVideoAdded(VideoEvent event);
  
  /// Called when a video state changes (loading, ready, failed, etc)
  void onVideoStateChanged(String videoId, VideoState newState);
  
  /// Called when a video is removed from the manager
  void onVideoRemoved(String videoId);
  
  /// Called when memory cleanup occurs
  void onMemoryCleanup(List<String> cleanedVideoIds);
  
  /// Called when an error occurs
  void onError(VideoManagerException error);
}