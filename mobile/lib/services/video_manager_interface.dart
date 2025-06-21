// ABOUTME: Abstract interface defining contract for video management system
// ABOUTME: Single source of truth for video state, preloading, and memory management

import 'dart:async';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';

/// Priority levels for video preloading operations
enum PreloadPriority {
  /// Currently viewing video - highest priority
  current,
  /// Next video in sequence - high priority
  next,
  /// Videos near current position - medium priority
  nearby,
  /// Background preloading - low priority
  background,
}

/// Strategies for cleaning up video controllers and memory
enum CleanupStrategy {
  /// Dispose controllers immediately when no longer needed
  immediate,
  /// Delay disposal to allow for quick returns to recently viewed videos
  delayed,
  /// Only cleanup when system reports memory pressure
  memoryPressure,
  /// Cleanup based on limits (max controllers, memory usage)
  limitBased,
}

/// Abstract interface for video management system
/// 
/// This interface defines the contract for the video management system that
/// serves as the single source of truth for video state, preloading, and
/// memory management. Implementation must ensure:
/// 
/// ## Core Requirements
/// - Memory usage stays under 500MB regardless of video count
/// - Maximum 15 concurrent video controllers at any time
/// - Race condition prevention for controller access/disposal
/// - Circuit breaker pattern for repeatedly failing videos
/// - Efficient preloading around current viewing position
/// 
/// ## State Management Contract
/// - Videos maintain newest-first ordering
/// - State transitions follow VideoLoadingState enum rules
/// - Immutable video list returned to prevent external modification
/// - Null safety for non-existent videos
/// 
/// ## Error Handling Requirements
/// - Graceful handling of network failures, format errors, and memory pressure
/// - Progressive retry with exponential backoff
/// - Circuit breaker after max retries
/// - Detailed error reporting with video context
/// 
/// ## Memory Management Contract
/// - Automatic disposal of off-screen videos
/// - Preload window management (ahead/behind current position)
/// - Memory pressure handling with resource cleanup
/// - Debug information for monitoring and troubleshooting
/// 
/// ## Thread Safety Requirements
/// - All operations must be safe for concurrent access
/// - State transitions atomic and consistent
/// - No race conditions during controller disposal
/// - Stream-based notifications for UI updates
abstract class IVideoManager {
  /// Get the current list of videos in newest-first order
  /// This is the single source of truth for video ordering
  List<VideoEvent> get videos;
  
  /// Get list of videos that are ready for immediate playback
  /// These videos have initialized controllers and are preloaded
  List<VideoEvent> get readyVideos;
  
  /// Get the current state of a specific video
  /// Returns null if video ID is not found
  VideoState? getVideoState(String videoId);
  
  /// Get the video player controller for a specific video
  /// Returns null if video is not preloaded or controller is disposed
  VideoPlayerController? getController(String videoId);
  
  /// Add a new video event to the manager
  /// 
  /// This method:
  /// - Adds video to the main videos list in newest-first order
  /// - Prevents duplicate videos (same ID)
  /// - Creates initial VideoState with notLoaded status
  /// - Triggers memory cleanup if necessary
  /// 
  /// Throws [VideoManagerException] if event is invalid
  Future<void> addVideoEvent(VideoEvent event);
  
  /// Preload a video for immediate playback
  /// 
  /// This method:
  /// - Creates and initializes VideoPlayerController
  /// - Updates VideoState to loading, then ready/failed
  /// - Enforces memory limits (max 15 controllers)
  /// - Implements circuit breaker for repeatedly failing videos
  /// - Disposes oldest controllers if memory limit exceeded
  /// 
  /// No-op if video is already preloaded or permanently failed
  Future<void> preloadVideo(String videoId);
  
  /// Preload videos around the current index for smooth scrolling
  /// 
  /// This method:
  /// - Preloads current video + N ahead + M behind
  /// - Disposes videos outside the preload window
  /// - Prioritizes forward direction (upcoming videos)
  /// - Adapts to network conditions (WiFi vs cellular)
  /// 
  /// [currentIndex] - Index of currently viewing video
  /// [preloadRange] - Number of videos to preload in each direction
  void preloadAroundIndex(int currentIndex, {int? preloadRange});
  
  /// Dispose a specific video's controller to free memory
  /// 
  /// This method:
  /// - Safely disposes VideoPlayerController
  /// - Updates VideoState to disposed
  /// - Handles race conditions during disposal
  /// - Removes video from readyVideos list
  void disposeVideo(String videoId);
  
  /// Handle system memory pressure by aggressively cleaning up
  /// 
  /// This method:
  /// - Disposes all non-current video controllers
  /// - Keeps only current + 1 ahead preloaded
  /// - Forces garbage collection
  /// - Reduces memory footprint to minimum
  Future<void> handleMemoryPressure();
  
  /// Get debug information about the video manager state
  /// 
  /// Returns a map containing:
  /// - totalVideos: Total number of videos in manager
  /// - readyVideos: Number of videos with ready controllers
  /// - loadingVideos: Number of videos currently loading
  /// - failedVideos: Number of videos in failed state
  /// - controllers: Number of active video controllers
  /// - estimatedMemoryMB: Estimated memory usage in MB
  /// - maxVideos: Maximum video limit
  /// - preloadAhead: Current preload ahead count
  /// - memoryManagement: Whether memory management is enabled
  Map<String, dynamic> getDebugInfo();
  
  /// Stream of state changes for reactive UI updates
  /// 
  /// Emits events when:
  /// - Videos are added or removed
  /// - Video states change (loading -> ready -> failed)
  /// - Controllers are created or disposed
  /// - Memory cleanup occurs
  /// 
  /// UI should listen to this stream and rebuild when changes occur
  Stream<void> get stateChanges;
  
  /// Dispose the video manager and clean up all resources
  /// 
  /// This method:
  /// - Disposes all video controllers
  /// - Cancels all ongoing operations
  /// - Closes state change stream
  /// - Clears all internal state
  /// 
  /// Manager is unusable after calling dispose()
  void dispose();
}

/// Configuration class for VideoManager behavior
class VideoManagerConfig {
  /// Maximum number of videos to keep in memory
  final int maxVideos;
  
  /// Number of videos to preload ahead of current position
  final int preloadAhead;
  
  /// Number of videos to preload behind current position
  final int preloadBehind;
  
  /// Maximum number of retry attempts for failed videos
  final int maxRetries;
  
  /// Timeout for video initialization
  final Duration preloadTimeout;
  
  /// Whether to enable automatic memory management
  final bool enableMemoryManagement;
  
  /// Create video manager configuration
  const VideoManagerConfig({
    this.maxVideos = 100,
    this.preloadAhead = 3,
    this.preloadBehind = 1,
    this.maxRetries = 3,
    this.preloadTimeout = const Duration(seconds: 10),
    this.enableMemoryManagement = true,
  });
  
  /// Configuration optimized for cellular connections
  factory VideoManagerConfig.cellular() {
    return const VideoManagerConfig(
      maxVideos: 50,
      preloadAhead: 1,
      preloadBehind: 0,
      maxRetries: 2,
      preloadTimeout: Duration(seconds: 15),
      enableMemoryManagement: true,
    );
  }
  
  /// Configuration optimized for WiFi connections
  factory VideoManagerConfig.wifi() {
    return const VideoManagerConfig(
      maxVideos: 100,
      preloadAhead: 2,  // Reduced from 5 to 2
      preloadBehind: 1, // Reduced from 2 to 1
      maxRetries: 2,    // Reduced from 3 to 2
      preloadTimeout: Duration(seconds: 15), // Increased timeout
      enableMemoryManagement: true,
    );
  }
  
  /// Configuration optimized for testing
  factory VideoManagerConfig.testing() {
    return const VideoManagerConfig(
      maxVideos: 10,
      preloadAhead: 2,
      preloadBehind: 1,
      maxRetries: 1,
      preloadTimeout: Duration(milliseconds: 500),
      enableMemoryManagement: true,
    );
  }
}

/// Exception thrown by video manager operations
class VideoManagerException implements Exception {
  final String message;
  final String? videoId;
  final dynamic originalError;
  
  const VideoManagerException(
    this.message, {
    this.videoId,
    this.originalError,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer('VideoManagerException: $message');
    if (videoId != null) {
      buffer.write(' (videoId: $videoId)');
    }
    if (originalError != null) {
      buffer.write(' (caused by: $originalError)');
    }
    return buffer.toString();
  }
}