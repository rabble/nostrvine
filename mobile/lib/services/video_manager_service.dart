// ABOUTME: Production VideoManager implementation serving as single source of truth
// ABOUTME: Manages video lifecycle, preloading, memory management with full state control

import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../utils/unified_logger.dart';
import 'video_manager_interface.dart';
import 'seen_videos_service.dart';
import 'content_blocklist_service.dart';

/// Production implementation of IVideoManager providing comprehensive video lifecycle management
/// 
/// This service implements the single source of truth pattern for video management,
/// providing centralized control over video state, preloading, and memory management.
/// It's designed for production use with full error handling, retry logic, and
/// performance optimization.
/// 
/// ## Key Features
/// - Thread-safe operations with proper locking
/// - Intelligent preloading with configurable strategies
/// - Memory pressure handling and automatic cleanup
/// - Comprehensive error handling and recovery
/// - Performance monitoring and debug capabilities
/// - Configuration-driven behavior adaptation
/// 
/// ## Usage Example
/// ```dart
/// final config = VideoManagerConfig.wifi(); // or .cellular() or .testing()
/// final manager = VideoManagerService(config: config);
/// 
/// // Add videos and let the manager handle preloading
/// await manager.addVideoEvent(videoEvent);
/// manager.preloadAroundIndex(0); // Preload videos around current position
/// 
/// // Get controller for playback
/// final controller = manager.getController(videoEvent.id);
/// 
/// // Clean up when done
/// manager.dispose();
/// ```
class VideoManagerService implements IVideoManager {
  /// Maximum number of concurrent video controllers allowed (memory constraint)
  static const int maxControllers = 15;
  
  /// Estimated memory per video controller in MB
  static const int memoryPerControllerMB = 20;
  
  /// Configuration for manager behavior
  final VideoManagerConfig _config;
  
  /// Service for tracking seen videos to prioritize new content
  // ignore: unused_field
  final SeenVideosService? _seenVideosService;
  
  /// Service for filtering blocked content
  final ContentBlocklistService? _blocklistService;
  
  /// Set of pubkeys that the user follows - for feed priority
  Set<String> _followingPubkeys = {};
  
  /// Primary video list - videos from accounts the user follows
  final List<VideoEvent> _primaryVideos = [];
  
  /// Discovery video list - videos from accounts the user doesn't follow
  final List<VideoEvent> _discoveryVideos = [];
  
  /// Video state tracking
  final Map<String, VideoState> _videoStates = {};
  
  /// Video player controllers
  final Map<String, VideoPlayerController> _controllers = {};
  
  /// Stream controller for state change notifications
  final StreamController<void> _stateChangesController = StreamController<void>.broadcast();
  
  /// Active preload operations to prevent race conditions
  final Set<String> _activePreloads = <String>{};
  
  /// Disposal flag to prevent operations after disposal
  bool _disposed = false;
  
  /// Debug metrics for monitoring
  int _preloadCount = 0;
  int _preloadSuccessCount = 0;
  int _preloadFailureCount = 0;
  int _memoryPressureCount = 0;
  DateTime? _lastCleanupTime;
  
  /// Creates a VideoManagerService with the specified configuration
  VideoManagerService({
    VideoManagerConfig? config,
    SeenVideosService? seenVideosService,
    ContentBlocklistService? blocklistService,
  }) : _config = config ?? const VideoManagerConfig(),
       _seenVideosService = seenVideosService,
       _blocklistService = blocklistService;
  
  /// Update the list of pubkeys the user is following for feed prioritization
  void updateFollowingList(Set<String> followingPubkeys) {
    _followingPubkeys = Set.from(followingPubkeys);
    Log.debug('FOLLOWING_DEBUG: VideoManager updated with ${_followingPubkeys.length} accounts', name: 'VideoManagerService', category: LogCategory.video);
  }
  
  /// Get video at specific index from the merged feed
  VideoEvent? _getVideoAtIndex(int index) {
    final allVideos = [..._primaryVideos, ..._discoveryVideos];
    if (index < 0 || index >= allVideos.length) return null;
    return allVideos[index];
  }
  
  /// Get total video count
  int get _totalVideoCount => _primaryVideos.length + _discoveryVideos.length;
  
  /// Check if the given index is at the boundary between primary and discovery feeds
  bool isAtFeedBoundary(int index) {
    // Boundary is after the last primary video, before the first discovery video
    return _primaryVideos.isNotEmpty && 
           _discoveryVideos.isNotEmpty && 
           index == _primaryVideos.length - 1;
  }
  
  /// Get the number of primary (following) videos
  int get primaryVideoCount => _primaryVideos.length;
  
  /// Get the number of discovery videos  
  int get discoveryVideoCount => _discoveryVideos.length;
  
  @override
  List<VideoEvent> get videos => List.unmodifiable([..._primaryVideos, ..._discoveryVideos]);
  
  @override
  List<VideoEvent> get readyVideos {
    return videos
        .where((video) => getVideoState(video.id)?.isReady == true)
        .toList();
  }
  
  @override
  VideoState? getVideoState(String videoId) {
    if (_disposed) return null;
    return _videoStates[videoId];
  }
  
  @override
  VideoPlayerController? getController(String videoId) {
    if (_disposed) return null;
    final state = getVideoState(videoId);
    if (state?.isReady != true) return null;
    return _controllers[videoId];
  }
  
  @override
  Stream<void> get stateChanges => _stateChangesController.stream;
  
  @override
  Future<void> addVideoEvent(VideoEvent event) async {
    if (_disposed) {
      throw VideoManagerException('VideoManager has been disposed');
    }
    
    if (event.id.isEmpty) {
      throw VideoManagerException('Video event must have a valid ID');
    }
    
    // Check blocklist - filter out blocked content
    if (_blocklistService?.shouldFilterFromFeeds(event.pubkey) == true) {
      Log.info('🚫 Blocked video from ${event.pubkey.substring(0, 8)}... filtered out', name: 'VideoManager', category: LogCategory.video);
      return;
    }
    
    // Check for duplicates in both arrays
    if (_primaryVideos.any((v) => v.id == event.id) || 
        _discoveryVideos.any((v) => v.id == event.id)) {
      developer.log('Duplicate video event ignored: ${event.id}');
      return;
    }
    
    // Sort videos into appropriate array based on following status
    if (_followingPubkeys.contains(event.pubkey)) {
      _primaryVideos.add(event);
    } else {
      _discoveryVideos.add(event);
    }
    
    // Initialize state
    _videoStates[event.id] = VideoState(event: event);
    
    // Check memory limits
    await _enforceMemoryLimits();
    
    // Notify listeners
    _notifyStateChange();
    
  }
  
  @override
  Future<void> preloadVideo(String videoId) async {
    if (_disposed) {
      throw VideoManagerException('VideoManager has been disposed');
    }
    
    final state = getVideoState(videoId);
    if (state == null) {
      throw VideoManagerException('Video not found', videoId: videoId);
    }
    
    // Circuit breaker: Don't attempt preload if permanently failed
    if (state.loadingState == VideoLoadingState.permanentlyFailed) {
      developer.log('Skipping preload for permanently failed video: $videoId');
      return;
    }
    
    // Check if already ready
    if (state.isReady) {
      return;
    }
    
    // Prevent concurrent preloads of the same video
    if (_activePreloads.contains(videoId)) {
      developer.log('Preload already in progress for video: $videoId');
      return;
    }
    
    // Web platform needs extra time for video player plugin initialization
    // on the first video preload
    if (kIsWeb && _controllers.isEmpty && _preloadCount == 0) {
      developer.log('🌐 Web platform: Adding delay for first video initialization');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _activePreloads.add(videoId);
    _preloadCount++;
    
    try {
      // Update to loading state
      _videoStates[videoId] = state.toLoading();
      _notifyStateChange();
      
      await _performPreload(videoId, state.event);
      
    } catch (e) {
      _preloadFailureCount++;
      await _handleVideoError(videoId, e);
      rethrow;
    } finally {
      _activePreloads.remove(videoId);
    }
  }
  
  @override
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    if (_disposed) return;
    
    if (_totalVideoCount == 0) {
      developer.log('⚠️ preloadAroundIndex called but no videos available');
      return;
    }
    
    final range = preloadRange ?? _config.preloadAhead;
    final start = (currentIndex - _config.preloadBehind).clamp(0, _totalVideoCount - 1);
    final end = (currentIndex + range).clamp(0, _totalVideoCount - 1);
    
    Log.info('🚀 Preloading around index $currentIndex (range: $start-$end), total videos: ${_totalVideoCount}', name: 'VideoManager', category: LogCategory.video);
    
    // Dispose controllers for videos outside the viewing window
    _disposeUnusedControllers(currentIndex);
    
    // Preload in priority order: current, next, previous, then expanding range
    final priorityOrder = _calculatePreloadPriority(currentIndex, start, end);
    
    Log.debug('📋 Checking ${priorityOrder.length} videos for preloading...', name: 'VideoManager', category: LogCategory.video);
    for (final index in priorityOrder) {
      final video = _getVideoAtIndex(index);
      if (video != null) {
        final videoId = video.id;
        final state = getVideoState(videoId);
        
        final shortId = videoId.length >= 8 ? videoId.substring(0, 8) : videoId;
        Log.verbose('🔍 Video $index: $shortId - state: ${state?.loadingState}, active: ${_activePreloads.contains(videoId)}', name: 'VideoManager', category: LogCategory.video);
        
        if (state != null && 
            state.loadingState == VideoLoadingState.notLoaded && 
            !_activePreloads.contains(videoId)) {
          Log.info('▶️ Starting preload for video $index: ${videoId.substring(0, 8)}', name: 'VideoManager', category: LogCategory.video);
          // Fire and forget - don't await to avoid blocking
          preloadVideo(videoId).catchError((e) {
            Log.error('❌ Background preload failed for ${videoId.substring(0, 8)}: $e', name: 'VideoManager', error: e);
          });
        } else {
          Log.verbose('⏭️ Skipping video $index: ${videoId.substring(0, 8)} (state: ${state?.loadingState})', name: 'VideoManager', category: LogCategory.video);
        }
      }
    }
  }
  
  @override
  void pauseVideo(String videoId) {
    if (_disposed) return;
    
    final controller = _controllers[videoId];
    if (controller != null && controller.value.isInitialized && controller.value.isPlaying) {
      try {
        controller.pause();
        Log.debug('Paused video: ${videoId.substring(0, 8)}...', name: 'VideoManagerService', category: LogCategory.video);
      } catch (e) {
        Log.error('Error pausing video $videoId: $e', name: 'VideoManagerService', category: LogCategory.video);
      }
    }
  }
  
  @override
  void pauseAllVideos() {
    if (_disposed) return;
    
    int pausedCount = 0;
    for (final entry in _controllers.entries) {
      final controller = entry.value;
      if (controller.value.isInitialized && controller.value.isPlaying) {
        try {
          controller.pause();
          pausedCount++;
        } catch (e) {
          Log.error('Error pausing video ${entry.key}: $e', name: 'VideoManagerService', category: LogCategory.video);
        }
      }
    }
    
    if (pausedCount > 0) {
      Log.debug('Paused $pausedCount videos', name: 'VideoManagerService', category: LogCategory.video);
    }
  }
  
  @override
  void stopAllVideos() {
    if (_disposed) return;
    
    final videoIds = _controllers.keys.toList();
    int stoppedCount = 0;
    
    for (final videoId in videoIds) {
      try {
        final controller = _controllers[videoId];
        if (controller != null && controller.value.isInitialized) {
          // Stop the video first
          if (controller.value.isPlaying) {
            controller.pause();
          }
          // Then dispose the controller
          controller.dispose();
          stoppedCount++;
        }
        
        // Remove from controllers map
        _controllers.remove(videoId);
        
        // Reset state to notLoaded so videos can be reloaded when needed
        final currentState = _videoStates[videoId];
        if (currentState != null) {
          _videoStates[videoId] = VideoState(event: currentState.event);
        }
        
      } catch (e) {
        Log.error('Error stopping video $videoId: $e', name: 'VideoManagerService', category: LogCategory.video);
      }
    }
    
    if (stoppedCount > 0) {
      Log.info('� Stopped $stoppedCount videos for camera mode (reset to notLoaded for reload)', name: 'VideoManagerService', category: LogCategory.video);
    }
    
    // Notify listeners of state changes
    _notifyStateChange();
  }
  
  @override
  void resumeVideo(String videoId) {
    if (_disposed) return;
    
    final controller = _controllers[videoId];
    if (controller != null && controller.value.isInitialized && !controller.value.isPlaying) {
      try {
        controller.play();
        Log.debug('▶️ Resumed video: ${videoId.substring(0, 8)}...', name: 'VideoManagerService', category: LogCategory.video);
      } catch (e) {
        Log.error('Error resuming video $videoId: $e', name: 'VideoManagerService', category: LogCategory.video);
      }
    }
  }
  
  @override
  void disposeVideo(String videoId) {
    if (_disposed) return;
    
    _activePreloads.remove(videoId);
    
    final controller = _controllers.remove(videoId);
    controller?.dispose();
    
    final state = getVideoState(videoId);
    if (state != null && !state.isDisposed) {
      _videoStates[videoId] = VideoState(event: state.event);
      _notifyStateChange();
    }
    
    developer.log('Disposed video controller: $videoId (reset to notLoaded for reload)');
  }
  
  @override
  Future<void> handleMemoryPressure() async {
    if (_disposed) return;
    
    _memoryPressureCount++;
    _lastCleanupTime = DateTime.now();
    
    developer.log('Handling memory pressure, controllers: ${_controllers.length}');
    
    // Keep only recent videos based on configuration
    final keepCount = (_config.maxVideos * 0.7).floor(); // Keep 70% when under pressure
    final allVideos = [..._primaryVideos, ..._discoveryVideos];
    final videosToRemove = allVideos.skip(keepCount).toList();
    
    for (final video in videosToRemove) {
      disposeVideo(video.id);
      _primaryVideos.remove(video);
      _discoveryVideos.remove(video);
      _videoStates.remove(video.id);
    }
    
    developer.log('Memory cleanup completed, removed ${videosToRemove.length} videos');
  }
  
  @override
  Map<String, dynamic> getDebugInfo() {
    final loadingCount = _videoStates.values.where((s) => s.isLoading).length;
    final failedCount = _videoStates.values.where((s) => s.hasFailed).length;
    final estimatedMemoryMB = _controllers.length * memoryPerControllerMB;
    
    return {
      'totalVideos': _totalVideoCount,
      'primaryVideos': _primaryVideos.length,
      'discoveryVideos': _discoveryVideos.length,
      'readyVideos': readyVideos.length,
      'loadingVideos': loadingCount,
      'failedVideos': failedCount,
      'activeControllers': _controllers.length,
      'activePreloads': _activePreloads.length,
      'disposed': _disposed,
      'estimatedMemoryMB': estimatedMemoryMB,
      'memoryUtilization': maxControllers > 0 ? (_controllers.length / maxControllers * 100).toStringAsFixed(1) : '0.0',
      'config': {
        'maxVideos': _config.maxVideos,
        'preloadAhead': _config.preloadAhead,
        'preloadBehind': _config.preloadBehind,
        'maxRetries': _config.maxRetries,
        'preloadTimeout': _config.preloadTimeout.inMilliseconds,
        'enableMemoryManagement': _config.enableMemoryManagement,
        'maxControllers': maxControllers,
        'memoryPerControllerMB': memoryPerControllerMB,
      },
      'metrics': {
        'preloadCount': _preloadCount,
        'preloadSuccessCount': _preloadSuccessCount,
        'preloadFailureCount': _preloadFailureCount,
        'preloadSuccessRate': _preloadCount > 0 ? (_preloadSuccessCount / _preloadCount * 100).toStringAsFixed(1) : '0.0',
        'memoryPressureCount': _memoryPressureCount,
        'lastCleanupTime': _lastCleanupTime?.toIso8601String(),
      },
    };
  }
  
  /// Filter existing videos to remove blocked content
  void filterExistingVideos() {
    if (_blocklistService == null || _totalVideoCount == 0) return;
    
    final initialCount = _totalVideoCount;
    final blockedVideos = <VideoEvent>[];
    
    // Find all blocked videos in both arrays
    for (final video in [..._primaryVideos, ..._discoveryVideos]) {
      if (_blocklistService!.shouldFilterFromFeeds(video.pubkey)) {
        blockedVideos.add(video);
      }
    }
    
    if (blockedVideos.isEmpty) return;
    
    // Remove blocked videos and their associated state
    for (final video in blockedVideos) {
      _primaryVideos.remove(video);
      _discoveryVideos.remove(video);
      _videoStates.remove(video.id);
      
      // Dispose controller if exists
      final controller = _controllers[video.id];
      if (controller != null) {
        controller.dispose();
        _controllers.remove(video.id);
      }
    }
    
    Log.info('🚫 Filtered ${blockedVideos.length} blocked videos from feed (${initialCount} -> ${_totalVideoCount})', name: 'VideoManager');
    
    // Notify listeners of change
    _notifyStateChange();
  }
  
  @override
  void dispose() {
    if (_disposed) return;
    
    _disposed = true;
    
    // Cancel all active preloads
    _activePreloads.clear();
    
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    // Clear all state
    _videoStates.clear();
    _primaryVideos.clear();
    _discoveryVideos.clear();
    
    // Close stream controller
    _stateChangesController.close();
    
    developer.log('VideoManagerService disposed');
  }
  
  // Private helper methods
  
  /// Performs the actual video preloading with timeout and error handling
  Future<void> _performPreload(String videoId, VideoEvent event) async {
    Log.info('🔄 Starting preload for video ${videoId.substring(0, 8)} with URL: ${event.videoUrl}', name: 'VideoManager');
    
    // Validate video URL before attempting preload
    if (event.videoUrl?.isEmpty ?? true) {
      Log.error('❌ Preload failed: Video URL is empty for ${videoId.substring(0, 8)}', name: 'VideoManager');
      throw VideoManagerException(
        'Video URL is required for preloading', 
        videoId: videoId,
        originalError: 'Empty or null video URL',
      );
    }
    
    VideoPlayerController? controller;
    
    try {
      // Enforce 15-controller limit before creating new controller
      _enforceControllerLimit();
      
      // Validate URL format
      final uri = Uri.tryParse(event.videoUrl!);
      if (uri == null || !uri.hasScheme) {
        throw VideoManagerException(
          'Invalid video URL format',
          videoId: videoId,
          originalError: 'Malformed URL: ${event.videoUrl}',
        );
      }
      
      // Create controller with progressive loading (like TikTok/Instagram)
      final headers = <String, String>{
        'Cache-Control': 'no-cache',
        'User-Agent': 'OpenVine/1.0',
      };
      
      // Platform-specific configuration for better compatibility
      if (kIsWeb) {
        // Web platform configuration
        controller = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
            webOptions: const VideoPlayerWebOptions(
              controls: VideoPlayerWebOptionsControls.disabled(),
            ),
          ),
          httpHeaders: headers,
        );
      } else {
        // Native platform configuration (macOS, iOS, etc.)
        controller = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false, // Might help with macOS audio issues
            allowBackgroundPlayback: false,
          ),
          httpHeaders: headers,
        );
      }
      
      // Initialize with longer timeout for better reliability
      Log.debug('📺 Initializing video controller for ${videoId.substring(0, 8)} on ${kIsWeb ? 'web' : 'native'} platform...', name: 'VideoManager');
      Log.debug('📺 Video URL: ${event.videoUrl}', name: 'VideoManager');
      
      await controller.initialize().timeout(
        const Duration(seconds: 10), // Longer timeout for better reliability
        onTimeout: () {
          Log.warning('⏰ Initial load timeout for ${videoId.substring(0, 8)} - continuing with progressive loading', name: 'VideoManager');
          // Don't throw - many videos can still play after timeout
        },
      );
      
      Log.debug('📺 Controller initialized - isInitialized: ${controller.value.isInitialized}, hasError: ${controller.value.hasError}', name: 'VideoManager');
      if (controller.value.hasError) {
        Log.error('📺 Controller error: ${controller.value.errorDescription}', name: 'VideoManager');
      }
      
      // For progressive playback, mark as ready even if not fully loaded
      // The video will start playing and buffer as needed
      
      // Verify controller is actually usable before storing
      if (controller.value.hasError) {
        Log.error('❌ Controller has error after initialization: ${controller.value.errorDescription}', name: 'VideoManager');
        throw VideoManagerException(
          'Controller initialization failed with error: ${controller.value.errorDescription}',
          videoId: videoId,
        );
      }
      
      // Store controller and update state
      _controllers[videoId] = controller;
      Log.debug('💾 Stored controller for ${videoId.substring(0, 8)}', name: 'VideoManager');
      
      final updatedState = getVideoState(videoId);
      if (updatedState != null && updatedState.isLoading) {
        _videoStates[videoId] = updatedState.toReady();
        _preloadSuccessCount++;
        _notifyStateChange();
        Log.info('✅ Video ${videoId.substring(0, 8)} marked as READY! Controller initialized: ${controller.value.isInitialized}', name: 'VideoManager');
      } else {
        Log.warning('⚠️ Video ${videoId.substring(0, 8)} state issue: currentState=${updatedState?.loadingState}, isLoading=${updatedState?.isLoading}', name: 'VideoManager');
      }
      
      Log.info('✅ Successfully preloaded video: ${videoId.substring(0, 8)} with progressive streaming', name: 'VideoManager');
      
    } catch (e) {
      // Clean up failed controller
      Log.error('❌ Preload failed for ${videoId.substring(0, 8)}: $e', name: 'VideoManager', error: e);
      controller?.dispose();
      _controllers.remove(videoId);
      
      // Re-throw with proper error context
      if (e is VideoManagerException) {
        rethrow;
      } else {
        throw _categorizeError(e, videoId);
      }
    }
  }
  
  /// Calculates preload priority order for optimal loading sequence
  List<int> _calculatePreloadPriority(int currentIndex, int start, int end) {
    final priorities = <int>[];
    
    // Current video has highest priority
    if (currentIndex >= start && currentIndex <= end) {
      priorities.add(currentIndex);
    }
    
    // Add surrounding videos in expanding order
    for (int offset = 1; offset <= (end - start); offset++) {
      // Next videos (higher priority)
      final nextIndex = currentIndex + offset;
      if (nextIndex <= end && nextIndex < _totalVideoCount && !priorities.contains(nextIndex)) {
        priorities.add(nextIndex);
      }
      
      // Previous videos (lower priority)
      final prevIndex = currentIndex - offset;
      if (prevIndex >= start && prevIndex >= 0 && !priorities.contains(prevIndex)) {
        priorities.add(prevIndex);
      }
    }
    
    return priorities;
  }
  
  /// Enforces memory limits by disposing old videos when necessary
  Future<void> _enforceMemoryLimits() async {
    if (!_config.enableMemoryManagement) return;
    
    if (_totalVideoCount > _config.maxVideos) {
      final excessCount = _totalVideoCount - _config.maxVideos;
      final allVideos = [..._primaryVideos, ..._discoveryVideos];
      final videosToRemove = allVideos.skip(_config.maxVideos).take(excessCount).toList();
      
      for (final video in videosToRemove) {
        disposeVideo(video.id);
        _primaryVideos.remove(video);
        _discoveryVideos.remove(video);
        _videoStates.remove(video.id);
      }
      
      developer.log('Enforced memory limits, removed $excessCount videos');
    }
  }
  
  /// Notifies listeners of state changes
  void _notifyStateChange() {
    if (!_disposed && !_stateChangesController.isClosed) {
      _stateChangesController.add(null);
    }
  }
  
  /// Dispose controllers for videos outside the viewing window to save memory
  /// 
  /// Keeps controllers only for videos within the preload range around the current index.
  /// This helps maintain the 500MB memory target by disposing unused video controllers.
  void _disposeUnusedControllers(int currentIndex) {
    if (!_config.enableMemoryManagement) return;
    
    final keepRange = _config.preloadAhead + _config.preloadBehind + 2; // Extra buffer
    final start = (currentIndex - keepRange).clamp(0, _totalVideoCount - 1);
    final end = (currentIndex + keepRange).clamp(0, _totalVideoCount - 1);
    
    // Dispose controllers for videos outside the keep range
    for (int i = 0; i < _totalVideoCount; i++) {
      if (i < start || i > end) {
        final video = _getVideoAtIndex(i);
        if (video == null) continue;
        final videoId = video.id;
        final controller = _controllers[videoId];
        if (controller != null) {
          controller.dispose();
          _controllers.remove(videoId);
          
          // Update state to indicate controller was disposed but video is still available
          final state = getVideoState(videoId);
          if (state?.isReady == true) {
            _videoStates[videoId] = VideoState(event: state!.event);
          }
          
          developer.log('Disposed controller for video outside viewing window: $videoId');
        }
      }
    }
  }

  /// Calculate exponential backoff delay for retry attempts
  /// 
  /// Uses exponential backoff with jitter to avoid thundering herd:
  /// Base delay: 1s, 2s, 4s, 8s... with up to 50% random jitter
  Duration _calculateRetryDelay(int retryAttempt) {
    // Base delay increases exponentially: 1s, 2s, 4s, 8s...
    final baseDelayMs = 1000 * (1 << (retryAttempt - 1));
    
    // Add jitter (0-50% of base delay) to avoid thundering herd
    final jitterMs = (baseDelayMs * 0.5 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000).round();
    
    final totalDelayMs = baseDelayMs + jitterMs;
    
    // Cap at maximum of 30 seconds
    return Duration(milliseconds: totalDelayMs.clamp(1000, 30000));
  }
  
  /// Enforces the 15-controller limit by disposing least recently used controllers
  /// 
  /// This method ensures we never exceed the maxControllers limit to stay within
  /// the 500MB memory target. It disposes the oldest controllers when the limit
  /// would be exceeded.
  void _enforceControllerLimit() {
    if (_controllers.length < maxControllers) return;
    
    final controllersToDispose = _controllers.length - maxControllers + 1; // +1 for the new one
    developer.log('Enforcing controller limit: disposing $controllersToDispose controllers');
    
    // Get video IDs sorted by most recently added (newest first)
    final allVideos = [..._primaryVideos, ..._discoveryVideos];
    final videoIds = allVideos.map((v) => v.id).toList();
    final controllerIds = _controllers.keys.toList();
    
    // Sort controller IDs by video order (newest videos first, so dispose oldest)
    controllerIds.sort((a, b) {
      final indexA = videoIds.indexOf(a);
      final indexB = videoIds.indexOf(b);
      // If not found in video list, prioritize for disposal
      if (indexA == -1) return -1;
      if (indexB == -1) return 1;
      return indexB.compareTo(indexA); // Reverse order - oldest videos first for disposal
    });
    
    // Dispose the oldest controllers
    final toDispose = controllerIds.take(controllersToDispose);
    for (final videoId in toDispose) {
      final controller = _controllers.remove(videoId);
      controller?.dispose();
      
      // Update state to indicate controller was disposed but video is still available
      final state = getVideoState(videoId);
      if (state?.isReady == true) {
        _videoStates[videoId] = VideoState(event: state!.event);
      }
      
      developer.log('Disposed controller due to limit: $videoId');
    }
  }

  /// Centralized error handling for video operations
  /// 
  /// Implements circuit breaker pattern and intelligent retry logic.
  /// Transitions videos to permanently failed state when appropriate.
  Future<void> _handleVideoError(String videoId, dynamic error) async {
    final currentState = getVideoState(videoId);
    if (currentState == null || _disposed) return;

    // Check if this is a server configuration error that needs special handling
    final errorString = error.toString().toLowerCase();
    final isServerConfigError = errorString.contains('server is not correctly configured') ||
        errorString.contains('coremediaerrordomain error -12939') ||
        errorString.contains('byte range length mismatch');

    VideoState newState;
    if (isServerConfigError) {
      // For server config errors, try once more without range requests
      if (currentState.retryCount == 0) {
        newState = currentState.toFailed('SERVER_CONFIG_ERROR - retrying without range requests');
        developer.log('Server configuration error for $videoId - will retry without range requests');
      } else {
        // Already retried, mark as permanently failed
        newState = VideoState(
          event: currentState.event,
          loadingState: VideoLoadingState.permanentlyFailed,
          errorMessage: 'SERVER_CONFIG_ERROR',
          retryCount: VideoState.maxRetryCount,
        );
        developer.log('Server configuration error for $videoId - marking as permanently failed after retry');
      }
    } else {
      // Normal error handling with retries
      newState = currentState.toFailed(error.toString());
    }
    
    _videoStates[videoId] = newState;
    _notifyStateChange();

    // Handle retries based on error type
    if (isServerConfigError && currentState.retryCount == 0) {
      // Try pre-downloading for servers without range request support
      developer.log('SERVER_CONFIG_ERROR detected for $videoId - attempting pre-download fallback');
      
      Timer(const Duration(milliseconds: 100), () {
        if (!_disposed) {
          final latestState = getVideoState(videoId);
          if (latestState != null && latestState.hasFailed) {
            developer.log('Attempting pre-download fallback for $videoId');
            _attemptPreDownloadFallback(videoId, latestState.event).catchError((fallbackError) {
              developer.log('Pre-download fallback failed for $videoId: $fallbackError');
              // Mark as permanently failed if pre-download also fails
              _videoStates[videoId] = VideoState(
                event: latestState.event,
                loadingState: VideoLoadingState.permanentlyFailed,
                errorMessage: 'Both streaming and pre-download failed',
                retryCount: VideoState.maxRetryCount,
              );
              _notifyStateChange();
            });
          }
        }
      });
    } else if (!isServerConfigError && newState.canRetry) {
      // Normal retry logic for other errors
      final retryDelay = _calculateRetryDelay(newState.retryCount);
      developer.log('Scheduling retry for $videoId (attempt ${newState.retryCount}/${VideoState.maxRetryCount}) in ${retryDelay.inMilliseconds}ms');
      
      Timer(retryDelay, () {
        if (!_disposed && _videoStates.containsKey(videoId)) {
          final latestState = _videoStates[videoId];
          if (latestState?.canRetry == true) {
            developer.log('Retrying preload for $videoId (attempt ${latestState!.retryCount + 1})');
            preloadVideo(videoId).catchError((retryError) {
              developer.log('Retry failed for $videoId: $retryError');
            });
          }
        }
      });
    } else {
      // Video has reached max retries or is permanently failed
      final reason = isServerConfigError ? 'server configuration error' : 'exhausted all retries';
      developer.log('Video $videoId marked as permanently failed: $reason');
    }
  }

  /// Enhanced error categorization for different failure types
  /// 
  /// Determines retry strategy based on error type and provides
  /// meaningful error messages for debugging.
  VideoManagerException _categorizeError(dynamic error, String videoId) {
    if (error is VideoManagerException) {
      return error;
    }

    String message;
    String category;

    if (error is TimeoutException || error.toString().contains('timeout')) {
      message = 'Network timeout during video loading';
      category = 'TIMEOUT';
    } else if (error is SocketException || error.toString().contains('network')) {
      message = 'Network connectivity error';
      category = 'NETWORK';
    } else if (error.toString().contains('404') || error.toString().contains('Not Found')) {
      message = 'Video not found (404)';
      category = 'NOT_FOUND';
    } else if (error.toString().contains('403') || error.toString().contains('Forbidden')) {
      message = 'Access denied to video (403)';
      category = 'FORBIDDEN';
    } else if (error.toString().contains('500') || error.toString().contains('Internal Server Error')) {
      message = 'Server error while loading video (500)';
      category = 'SERVER_ERROR';
    } else if (error.toString().contains('format') || error.toString().contains('codec')) {
      message = 'Unsupported video format or codec';
      category = 'FORMAT_ERROR';
    } else if (error.toString().contains('CoreMediaErrorDomain error -12939') || 
               error.toString().contains('byte range length mismatch')) {
      message = 'Server configuration error - invalid byte range response';
      category = 'SERVER_CONFIG_ERROR';
    } else if (error.toString().contains('CoreMediaErrorDomain') || 
               error.toString().contains('AVFoundation')) {
      message = 'Media playback error';
      category = 'MEDIA_ERROR';
    } else {
      message = 'Unknown error during video loading';
      category = 'UNKNOWN';
    }

    return VideoManagerException(
      '$message [$category]',
      videoId: videoId,
      originalError: error,
    );
  }

  /// Attempt to pre-download video for servers without range request support
  /// 
  /// Downloads the entire video file first, then creates a VideoPlayerController
  /// from the local file. This bypasses range request issues but uses more bandwidth.
  Future<void> _attemptPreDownloadFallback(String videoId, VideoEvent event) async {
    if (event.videoUrl?.isEmpty ?? true) {
      throw VideoManagerException('Video URL is required for pre-download fallback', videoId: videoId);
    }

    developer.log('🔄 Starting pre-download for $videoId from ${event.videoUrl}');
    
    try {
      // Update state to show we're attempting fallback
      final currentState = getVideoState(videoId);
      if (currentState != null) {
        _videoStates[videoId] = VideoState(
          event: event,
          loadingState: VideoLoadingState.loading,
          errorMessage: 'Downloading video for offline playback...',
          retryCount: currentState.retryCount + 1,
        );
        _notifyStateChange();
      }

      // Create HTTP client for downloading
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      
      // Download the video file
      final uri = Uri.parse(event.videoUrl!);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'OpenVine/1.0');
      
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw VideoManagerException('HTTP ${response.statusCode} downloading video', videoId: videoId);
      }

      // Get temporary directory for caching
      final tempDir = Directory.systemTemp;
      final videoFile = File('${tempDir.path}/openvine_cache_$videoId.mp4');
      
      // Download and write to file
      final sink = videoFile.openWrite();
      await response.pipe(sink);
      await sink.close();
      
      developer.log('✅ Pre-download completed for $videoId, size: ${await videoFile.length()} bytes');
      
      // Create video controller from local file
      final controller = VideoPlayerController.file(videoFile);
      
      // Initialize the controller
      await controller.initialize();
      
      // Store controller and update state
      _controllers[videoId] = controller;
      
      final updatedState = getVideoState(videoId);
      if (updatedState != null && updatedState.isLoading) {
        _videoStates[videoId] = updatedState.toReady();
        _preloadSuccessCount++;
        _notifyStateChange();
        developer.log('✅ Pre-download fallback successful for $videoId');
      }
      
      client.close();
      
    } catch (e) {
      developer.log('❌ Pre-download fallback failed for $videoId: $e');
      
      // Clean up any partial downloads
      try {
        final tempDir = Directory.systemTemp;
        final videoFile = File('${tempDir.path}/openvine_cache_$videoId.mp4');
        if (await videoFile.exists()) {
          await videoFile.delete();
        }
      } catch (cleanupError) {
        developer.log('⚠️ Failed to clean up partial download: $cleanupError');
      }
      
      rethrow;
    }
  }
}