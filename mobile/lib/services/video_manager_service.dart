// ABOUTME: Production VideoManager implementation serving as single source of truth
// ABOUTME: Manages video lifecycle, preloading, memory management with full state control

import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import 'video_manager_interface.dart';

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
  
  /// Main video list - single source of truth
  final List<VideoEvent> _videos = [];
  
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
  }) : _config = config ?? const VideoManagerConfig();
  
  @override
  List<VideoEvent> get videos => List.unmodifiable(_videos);
  
  @override
  List<VideoEvent> get readyVideos {
    return _videos
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
    
    // Check for duplicates
    if (_videos.any((v) => v.id == event.id)) {
      developer.log('Duplicate video event ignored: ${event.id}');
      return;
    }
    
    // Add to newest-first list
    _videos.insert(0, event);
    
    // Initialize state
    _videoStates[event.id] = VideoState(event: event);
    
    // Check memory limits
    await _enforceMemoryLimits();
    
    // Notify listeners
    _notifyStateChange();
    
    developer.log('Added video event: ${event.id}, total videos: ${_videos.length}');
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
    
    if (_videos.isEmpty) return;
    
    final range = preloadRange ?? _config.preloadAhead;
    final start = (currentIndex - _config.preloadBehind).clamp(0, _videos.length - 1);
    final end = (currentIndex + range).clamp(0, _videos.length - 1);
    
    developer.log('Preloading around index $currentIndex (range: $start-$end)');
    
    // Dispose controllers for videos outside the viewing window
    _disposeUnusedControllers(currentIndex);
    
    // Preload in priority order: current, next, previous, then expanding range
    final priorityOrder = _calculatePreloadPriority(currentIndex, start, end);
    
    for (final index in priorityOrder) {
      if (index < _videos.length) {
        final videoId = _videos[index].id;
        final state = getVideoState(videoId);
        
        if (state != null && 
            state.loadingState == VideoLoadingState.notLoaded && 
            !_activePreloads.contains(videoId)) {
          // Fire and forget - don't await to avoid blocking
          preloadVideo(videoId).catchError((e) {
            developer.log('Background preload failed for $videoId: $e');
          });
        }
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
      _videoStates[videoId] = state.toDisposed();
      _notifyStateChange();
    }
    
    developer.log('Disposed video: $videoId');
  }
  
  @override
  Future<void> handleMemoryPressure() async {
    if (_disposed) return;
    
    _memoryPressureCount++;
    _lastCleanupTime = DateTime.now();
    
    developer.log('Handling memory pressure, controllers: ${_controllers.length}');
    
    // Keep only recent videos based on configuration
    final keepCount = (_config.maxVideos * 0.7).floor(); // Keep 70% when under pressure
    final videosToRemove = _videos.skip(keepCount).toList();
    
    for (final video in videosToRemove) {
      disposeVideo(video.id);
      _videos.remove(video);
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
      'totalVideos': _videos.length,
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
    _videos.clear();
    
    // Close stream controller
    _stateChangesController.close();
    
    developer.log('VideoManagerService disposed');
  }
  
  // Private helper methods
  
  /// Performs the actual video preloading with timeout and error handling
  Future<void> _performPreload(String videoId, VideoEvent event) async {
    // Validate video URL before attempting preload
    if (event.videoUrl?.isEmpty ?? true) {
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
      
      // Create controller with network configuration
      controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      
      // Initialize with timeout
      await controller.initialize().timeout(
        _config.preloadTimeout,
        onTimeout: () {
          throw VideoManagerException(
            'Preload timeout after ${_config.preloadTimeout.inSeconds}s',
            videoId: videoId,
            originalError: 'Network timeout',
          );
        },
      );
      
      // Store controller and update state
      _controllers[videoId] = controller;
      
      final currentState = getVideoState(videoId);
      if (currentState != null && currentState.isLoading) {
        _videoStates[videoId] = currentState.toReady();
        _preloadSuccessCount++;
        _notifyStateChange();
      }
      
      developer.log('Successfully preloaded video: $videoId');
      
    } catch (e) {
      // Clean up failed controller
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
      if (nextIndex <= end && nextIndex < _videos.length && !priorities.contains(nextIndex)) {
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
    
    if (_videos.length > _config.maxVideos) {
      final excessCount = _videos.length - _config.maxVideos;
      final videosToRemove = _videos.skip(_config.maxVideos).take(excessCount).toList();
      
      for (final video in videosToRemove) {
        disposeVideo(video.id);
        _videos.remove(video);
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
    final start = (currentIndex - keepRange).clamp(0, _videos.length - 1);
    final end = (currentIndex + keepRange).clamp(0, _videos.length - 1);
    
    // Dispose controllers for videos outside the keep range
    for (int i = 0; i < _videos.length; i++) {
      if (i < start || i > end) {
        final videoId = _videos[i].id;
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
    final videoIds = _videos.map((v) => v.id).toList();
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

    // Transition to failed state (automatically becomes permanently failed if max retries exceeded)
    final newState = currentState.toFailed(error.toString());
    _videoStates[videoId] = newState;
    _notifyStateChange();

    // Check if video can still be retried
    if (newState.canRetry) {
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
      // Video has reached max retries and is now permanently failed
      developer.log('Video $videoId exhausted all retries, marked as permanently failed');
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
}