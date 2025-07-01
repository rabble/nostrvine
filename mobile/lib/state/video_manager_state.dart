// ABOUTME: Comprehensive Riverpod-based video manager state model
// ABOUTME: Manages video controllers, preloading, memory tracking with reactive updates

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:video_player/video_player.dart';
import '../models/video_state.dart';
import '../services/video_manager_interface.dart';

part 'video_manager_state.freezed.dart';

/// State for individual video controller management
@freezed
class VideoControllerState with _$VideoControllerState {
  const factory VideoControllerState({
    required String videoId,
    required VideoPlayerController controller,
    required VideoState state,
    required DateTime createdAt,
    required PreloadPriority priority,
    @Default(0) int retryCount,
    DateTime? lastAccessedAt,
  }) = _VideoControllerState;
  
  const VideoControllerState._();
  
  /// Check if this controller is ready for playback
  bool get isReady => state.loadingState == VideoLoadingState.ready;
  
  /// Check if this controller is currently loading
  bool get isLoading => state.loadingState == VideoLoadingState.loading;
  
  /// Check if this controller has failed
  bool get isFailed => state.loadingState == VideoLoadingState.failed;
  
  /// Check if this controller should be considered stale for cleanup
  bool get isStale {
    if (lastAccessedAt == null) return false;
    final now = DateTime.now();
    final timeSinceAccess = now.difference(lastAccessedAt!);
    
    return switch (priority) {
      PreloadPriority.current => false, // Never clean up current video
      PreloadPriority.next => timeSinceAccess.inMinutes > 5,
      PreloadPriority.nearby => timeSinceAccess.inMinutes > 3,
      PreloadPriority.background => timeSinceAccess.inMinutes > 1,
    };
  }
}

/// Memory usage statistics for the video manager
@freezed
class VideoMemoryStats with _$VideoMemoryStats {
  const factory VideoMemoryStats({
    @Default(0) int totalControllers,
    @Default(0) int readyControllers,
    @Default(0) int loadingControllers,
    @Default(0) int failedControllers,
    @Default(0.0) double estimatedMemoryMB,
    @Default(false) bool isMemoryPressure,
  }) = _VideoMemoryStats;
  
  const VideoMemoryStats._();
  
  /// Check if we're approaching memory limits
  bool get isNearMemoryLimit => totalControllers >= 12 || estimatedMemoryMB >= 400;
  
  /// Check if we need aggressive cleanup
  bool get needsCleanup => totalControllers >= 15 || estimatedMemoryMB >= 500;
}

/// Main state for the Riverpod video manager
@freezed
class VideoManagerState with _$VideoManagerState {
  const factory VideoManagerState({
    /// Map of video ID to controller state
    @Default({}) Map<String, VideoControllerState> controllers,
    
    /// Current video index for preloading context
    @Default(0) int currentIndex,
    
    /// Configuration for the video manager
    VideoManagerConfig? config,
    
    /// Memory usage statistics
    @Default(VideoMemoryStats()) VideoMemoryStats memoryStats,
    
    /// Whether the manager is currently under memory pressure
    @Default(false) bool isMemoryPressure,
    
    /// Currently playing video ID
    String? currentlyPlayingId,
    
    /// Last cleanup timestamp
    DateTime? lastCleanup,
    
    /// Whether the manager is disposed
    @Default(false) bool isDisposed,
    
    /// Error state if the manager encounters issues
    String? error,
    
    /// Number of successful preloads
    @Default(0) int successfulPreloads,
    
    /// Number of failed loads
    @Default(0) int failedLoads,
  }) = _VideoManagerState;
  
  const VideoManagerState._();
  
  /// Get all video controllers
  List<VideoControllerState> get allControllers => controllers.values.toList();
  
  /// Get ready video controllers
  List<VideoControllerState> get readyControllers => 
      controllers.values.where((c) => c.isReady).toList();
  
  /// Get loading video controllers
  List<VideoControllerState> get loadingControllers => 
      controllers.values.where((c) => c.isLoading).toList();
  
  /// Get failed video controllers
  List<VideoControllerState> get failedControllers => 
      controllers.values.where((c) => c.isFailed).toList();
  
  /// Get video controller by ID
  VideoControllerState? getController(String videoId) => controllers[videoId];
  
  /// Check if a video has a controller
  bool hasController(String videoId) => controllers.containsKey(videoId);
  
  /// Get video state for a specific video
  VideoState? getVideoState(String videoId) => controllers[videoId]?.state;
  
  /// Get VideoPlayerController for a specific video
  VideoPlayerController? getPlayerController(String videoId) => controllers[videoId]?.controller;
  
  /// Check if we need memory cleanup
  bool get needsMemoryCleanup {
    final maxVideos = config?.maxVideos ?? 100;
    return memoryStats.needsCleanup || 
           controllers.length > maxVideos ||
           isMemoryPressure;
  }
  
  /// Get controllers that should be cleaned up (oldest, background priority, stale)
  List<VideoControllerState> get controllersForCleanup {
    final candidates = controllers.values
        .where((c) => c.priority != PreloadPriority.current)
        .toList();
    
    // Sort by priority (background first), then by age
    candidates.sort((a, b) {
      // First sort by priority (background gets cleaned up first)
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return -priorityCompare; // Reverse for background first
      
      // Then by age (oldest first)
      return a.createdAt.compareTo(b.createdAt);
    });
    
    return candidates;
  }
  
  /// Get preload success rate
  double get preloadSuccessRate {
    final total = successfulPreloads + failedLoads;
    return total > 0 ? successfulPreloads / total : 1.0;
  }
  
  /// Check if memory usage is high
  bool get isMemoryHigh => memoryStats.estimatedMemoryMB > 400;
  
  /// Check if memory usage is critical
  bool get isMemoryCritical => memoryStats.estimatedMemoryMB > 500;
  
  /// Get debug information map
  Map<String, dynamic> get debugInfo => {
    'totalControllers': controllers.length,
    'readyControllers': readyControllers.length,
    'loadingControllers': loadingControllers.length,
    'failedControllers': failedControllers.length,
    'estimatedMemoryMB': memoryStats.estimatedMemoryMB,
    'maxVideos': config?.maxVideos ?? 100,
    'preloadAhead': config?.preloadAhead ?? 3,
    'preloadBehind': config?.preloadBehind ?? 1,
    'memoryPressure': isMemoryPressure,
    'needsCleanup': needsMemoryCleanup,
    'currentIndex': currentIndex,
    'currentlyPlayingId': currentlyPlayingId,
    'lastCleanup': lastCleanup?.toIso8601String(),
    'isDisposed': isDisposed,
    'error': error,
    'successfulPreloads': successfulPreloads,
    'failedLoads': failedLoads,
    'preloadSuccessRate': preloadSuccessRate,
  };
}