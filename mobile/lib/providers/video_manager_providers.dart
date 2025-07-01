// ABOUTME: Pure Riverpod implementation of video manager replacing VideoEventBridge
// ABOUTME: Implements IVideoManager interface with reactive state management

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';

import '../models/video_event.dart';
import '../models/video_state.dart';
import '../state/video_manager_state.dart';
import '../services/video_manager_interface.dart';
import '../utils/unified_logger.dart';
import 'video_feed_provider.dart';

part 'video_manager_providers.g.dart';

/// Configuration provider for video manager settings
@riverpod
VideoManagerConfig videoManagerConfig(VideoManagerConfigRef ref) {
  // Default to WiFi config, could be made dynamic based on connection
  return VideoManagerConfig.wifi();
}

/// Main Riverpod video manager provider
@riverpod
class VideoManager extends _$VideoManager {
  StreamController<void>? _stateChangesController;
  Timer? _cleanupTimer;
  Timer? _memoryMonitorTimer;
  
  @override
  VideoManagerState build() {
    final config = ref.watch(videoManagerConfigProvider);
    
    // Set up cleanup on dispose
    ref.onDispose(() {
      _dispose();
    });
    
    // Initialize state change stream
    _stateChangesController = StreamController<void>.broadcast();
    
    // Start memory monitoring
    _startMemoryMonitoring();
    
    // Watch video feed changes and sync videos
    ref.listen(videoFeedProvider, (previous, next) {
      next.whenData((feedState) {
        _syncVideosFromFeed(feedState.videos);
      });
    });
    
    return VideoManagerState(
      config: config,
    );
  }
  
  /// Start monitoring memory usage and trigger cleanup when needed
  void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final currentState = state;
      if (currentState.needsMemoryCleanup) {
        _performMemoryCleanup();
      }
    });
  }
  
  /// Sync videos from the video feed provider
  void _syncVideosFromFeed(List<VideoEvent> feedVideos) {
    Log.debug('VideoManager: Syncing ${feedVideos.length} videos from feed', 
      name: 'VideoManagerProvider', category: LogCategory.video);
    
    // Add any new videos that don't have controllers yet
    for (final video in feedVideos) {
      if (!state.hasController(video.id)) {
        _addVideoEvent(video);
      }
    }
    
    // Remove controllers for videos no longer in feed (optional cleanup)
    final feedVideoIds = feedVideos.map((v) => v.id).toSet();
    final controllersToRemove = state.controllers.keys
        .where((id) => !feedVideoIds.contains(id))
        .toList();
    
    if (controllersToRemove.isNotEmpty) {
      Log.debug('VideoManager: Removing ${controllersToRemove.length} obsolete controllers', 
        name: 'VideoManagerProvider', category: LogCategory.video);
      
      for (final videoId in controllersToRemove) {
        _disposeVideo(videoId);
      }
    }
    
    _notifyStateChange();
  }
  
  /// Add a video event to the manager
  void _addVideoEvent(VideoEvent event) {
    final currentState = state;
    
    // Don't add if already exists
    if (currentState.hasController(event.id)) return;
    
    // Video event added to tracking
    
    Log.debug('VideoManager: Added video ${event.id}', 
      name: 'VideoManagerProvider', category: LogCategory.video);
  }
  
  /// Preload a video with the given priority
  Future<void> _preloadVideo(String videoId, PreloadPriority priority) async {
    final currentState = state;
    
    // Check if already preloaded or loading
    final existingController = currentState.getController(videoId);
    if (existingController != null) {
      if (existingController.isReady || existingController.isLoading) {
        return; // Already preloaded or loading
      }
    }
    
    // Get video event from feed
    final feedState = await ref.read(videoFeedProvider.future);
    final videoEvent = feedState.videos.firstWhere(
      (v) => v.id == videoId,
      orElse: () => throw VideoManagerException('Video not found: $videoId'),
    );
    
    try {
      Log.debug('VideoManager: Starting preload for $videoId', 
        name: 'VideoManagerProvider', category: LogCategory.video);
      
      // Create video player controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoEvent.videoUrl ?? ''),
      );
      
      // Create loading state
      final loadingState = VideoState(
        event: videoEvent,
        loadingState: VideoLoadingState.loading,
      );
      
      final controllerState = VideoControllerState(
        videoId: videoId,
        controller: controller,
        state: loadingState,
        createdAt: DateTime.now(),
        priority: priority,
      );
      
      // Add to state
      state = currentState.copyWith(
        controllers: {...currentState.controllers, videoId: controllerState},
      );
      
      // Initialize controller
      await controller.initialize();
      
      // Update to ready state
      final readyState = loadingState.toReady();
      
      final readyControllerState = controllerState.copyWith(
        state: readyState,
        lastAccessedAt: DateTime.now(),
      );
      
      state = state.copyWith(
        controllers: {...state.controllers, videoId: readyControllerState},
        successfulPreloads: state.successfulPreloads + 1,
      );
      
      _updateMemoryStats();
      _notifyStateChange();
      
      Log.info('VideoManager: Successfully preloaded $videoId', 
        name: 'VideoManagerProvider', category: LogCategory.video);
      
    } catch (e) {
      Log.error('VideoManager: Failed to preload $videoId: $e', 
        name: 'VideoManagerProvider', category: LogCategory.video);
      
      // Handle failure state
      
      // Update state with failure
      state = state.copyWith(
        failedLoads: state.failedLoads + 1,
        error: 'Failed to preload $videoId: $e',
      );
      
      // Remove any partial controller state
      final updatedControllers = Map<String, VideoControllerState>.from(state.controllers);
      updatedControllers.remove(videoId);
      
      state = state.copyWith(controllers: updatedControllers);
      
      _notifyStateChange();
    }
  }
  
  /// Preload videos around the current index
  void _preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    final config = state.config;
    if (config == null) return;
    
    final preloadAhead = preloadRange ?? config.preloadAhead;
    final preloadBehind = preloadRange ?? config.preloadBehind;
    
    // Get current videos from feed
    final feedState = ref.read(videoFeedProvider).valueOrNull;
    if (feedState == null) return;
    
    final videos = feedState.videos;
    if (videos.isEmpty) return;
    
    // Ensure currentIndex is valid
    final safeIndex = currentIndex.clamp(0, videos.length - 1);
    
    // Update current index in state
    state = state.copyWith(currentIndex: safeIndex);
    
    Log.debug('VideoManager: Preloading around index $safeIndex (ahead: $preloadAhead, behind: $preloadBehind)', 
      name: 'VideoManagerProvider', category: LogCategory.video);
    
    // Preload current video with highest priority
    final currentVideo = videos[safeIndex];
    _preloadVideo(currentVideo.id, PreloadPriority.current);
    
    // Preload videos ahead
    for (int i = 1; i <= preloadAhead && safeIndex + i < videos.length; i++) {
      final video = videos[safeIndex + i];
      final priority = i == 1 ? PreloadPriority.next : PreloadPriority.nearby;
      _preloadVideo(video.id, priority);
    }
    
    // Preload videos behind
    for (int i = 1; i <= preloadBehind && safeIndex - i >= 0; i++) {
      final video = videos[safeIndex - i];
      _preloadVideo(video.id, PreloadPriority.nearby);
    }
  }
  
  /// Perform memory cleanup by disposing least important controllers
  void _performMemoryCleanup() {
    final currentState = state;
    final controllersToCleanup = currentState.controllersForCleanup;
    
    if (controllersToCleanup.isEmpty) return;
    
    // Calculate how many to remove (remove half or enough to get under limit)
    final targetCount = (currentState.config?.maxVideos ?? 100) * 0.7; // Keep 70% of max
    final toRemoveCount = (currentState.controllers.length - targetCount).ceil().clamp(1, controllersToCleanup.length);
    
    Log.info('VideoManager: Cleaning up $toRemoveCount controllers for memory management', 
      name: 'VideoManagerProvider', category: LogCategory.video);
    
    for (int i = 0; i < toRemoveCount && i < controllersToCleanup.length; i++) {
      final controller = controllersToCleanup[i];
      _disposeVideo(controller.videoId);
    }
    
    state = state.copyWith(lastCleanup: DateTime.now());
    _updateMemoryStats();
    _notifyStateChange();
  }
  
  /// Dispose a specific video's controller
  void _disposeVideo(String videoId) {
    final currentState = state;
    final controllerState = currentState.getController(videoId);
    
    if (controllerState == null) return;
    
    try {
      controllerState.controller.dispose();
      Log.debug('VideoManager: Disposed controller for $videoId', 
        name: 'VideoManagerProvider', category: LogCategory.video);
    } catch (e) {
      Log.error('VideoManager: Error disposing controller for $videoId: $e', 
        name: 'VideoManagerProvider', category: LogCategory.video);
    }
    
    // Remove from state
    final updatedControllers = Map<String, VideoControllerState>.from(currentState.controllers);
    updatedControllers.remove(videoId);
    
    state = currentState.copyWith(controllers: updatedControllers);
    _updateMemoryStats();
  }
  
  /// Update memory statistics
  void _updateMemoryStats() {
    final currentState = state;
    final controllers = currentState.allControllers;
    
    // Estimate memory usage (rough calculation)
    final estimatedMemory = controllers.length * 25.0; // ~25MB per video controller
    
    final memoryStats = VideoMemoryStats(
      totalControllers: controllers.length,
      readyControllers: currentState.readyControllers.length,
      loadingControllers: currentState.loadingControllers.length,
      failedControllers: currentState.failedControllers.length,
      estimatedMemoryMB: estimatedMemory,
      isMemoryPressure: estimatedMemory > 400,
    );
    
    state = currentState.copyWith(
      memoryStats: memoryStats,
      isMemoryPressure: memoryStats.isMemoryPressure,
    );
  }
  
  /// Notify listeners of state changes
  void _notifyStateChange() {
    _stateChangesController?.add(null);
  }
  
  /// Dispose all resources
  void _dispose() {
    Log.info('VideoManager: Disposing all resources', 
      name: 'VideoManagerProvider', category: LogCategory.video);
    
    // Cancel timers
    _cleanupTimer?.cancel();
    _memoryMonitorTimer?.cancel();
    
    // Dispose all controllers
    for (final controllerState in state.allControllers) {
      try {
        controllerState.controller.dispose();
      } catch (e) {
        Log.error('VideoManager: Error disposing controller ${controllerState.videoId}: $e', 
          name: 'VideoManagerProvider', category: LogCategory.video);
      }
    }
    
    // Close stream
    _stateChangesController?.close();
    _stateChangesController = null;
    
    // Mark as disposed
    state = state.copyWith(
      isDisposed: true,
      controllers: {},
    );
  }
  
  // Public interface methods for external use
  
  /// Preload video with specific priority (public interface)
  Future<void> preloadVideo(String videoId, {PreloadPriority priority = PreloadPriority.nearby}) async {
    await _preloadVideo(videoId, priority);
  }
  
  /// Preload videos around current index (public interface)
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    _preloadAroundIndex(currentIndex, preloadRange: preloadRange);
  }
  
  /// Pause a specific video
  void pauseVideo(String videoId) {
    final controllerState = state.getController(videoId);
    if (controllerState?.controller.value.isPlaying == true) {
      controllerState!.controller.pause();
      Log.debug('VideoManager: Paused video $videoId', 
        name: 'VideoManagerProvider', category: LogCategory.video);
    }
  }
  
  /// Resume a specific video
  void resumeVideo(String videoId) {
    final controllerState = state.getController(videoId);
    if (controllerState?.controller.value.isPlaying == false) {
      controllerState!.controller.play();
      Log.debug('VideoManager: Resumed video $videoId', 
        name: 'VideoManagerProvider', category: LogCategory.video);
    }
  }
  
  /// Pause all videos
  void pauseAllVideos() {
    for (final controllerState in state.readyControllers) {
      if (controllerState.controller.value.isPlaying) {
        controllerState.controller.pause();
      }
    }
    Log.debug('VideoManager: Paused all videos', 
      name: 'VideoManagerProvider', category: LogCategory.video);
  }
  
  /// Stop and dispose all videos
  void stopAllVideos() {
    for (final controllerState in state.allControllers) {
      _disposeVideo(controllerState.videoId);
    }
    Log.info('VideoManager: Stopped and disposed all videos', 
      name: 'VideoManagerProvider', category: LogCategory.video);
  }
  
  /// Handle memory pressure by aggressive cleanup
  Future<void> handleMemoryPressure() async {
    Log.warning('VideoManager: Handling memory pressure', 
      name: 'VideoManagerProvider', category: LogCategory.video);
    
    state = state.copyWith(isMemoryPressure: true);
    
    // Keep only current video if possible
    final currentVideoId = state.currentlyPlayingId;
    final controllersToKeep = currentVideoId != null ? [currentVideoId] : <String>[];
    
    // Dispose all other controllers
    for (final controllerState in state.allControllers) {
      if (!controllersToKeep.contains(controllerState.videoId)) {
        _disposeVideo(controllerState.videoId);
      }
    }
    
    _updateMemoryStats();
    _notifyStateChange();
    
    // Try to force garbage collection on mobile platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Note: Dart doesn't expose System.gc() directly, but disposing resources should help
    }
  }
  
  /// Get state changes stream
  Stream<void> get stateChanges => _stateChangesController?.stream ?? const Stream.empty();
}

/// Helper provider to get video player controller by ID
@riverpod
VideoPlayerController? videoPlayerController(VideoPlayerControllerRef ref, String videoId) {
  final managerState = ref.watch(videoManagerProvider);
  return managerState.getPlayerController(videoId);
}

/// Helper provider to get video state by ID  
@riverpod
VideoState? videoStateById(VideoStateByIdRef ref, String videoId) {
  final managerState = ref.watch(videoManagerProvider);
  return managerState.getVideoState(videoId);
}

/// Helper provider to check if video is ready
@riverpod
bool isVideoReady(IsVideoReadyRef ref, String videoId) {
  final managerState = ref.watch(videoManagerProvider);
  return managerState.getController(videoId)?.isReady ?? false;
}

/// Helper provider for memory statistics
@riverpod
VideoMemoryStats videoMemoryStats(VideoMemoryStatsRef ref) {
  final managerState = ref.watch(videoManagerProvider);
  return managerState.memoryStats;
}

/// Helper provider for debug information
@riverpod
Map<String, dynamic> videoManagerDebugInfo(VideoManagerDebugInfoRef ref) {
  final managerState = ref.watch(videoManagerProvider);
  return managerState.debugInfo;
}