// ABOUTME: Mock implementation of IVideoManager for testing purposes
// ABOUTME: Provides controllable behavior for testing video system contract compliance

import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';

/// Mock VideoPlayerController for testing purposes
class MockVideoPlayerController extends VideoPlayerController {
  MockVideoPlayerController() : super.asset(''); // Empty asset path
  
  @override
  Future<void> initialize() async {
    // Mock successful initialization without actually loading anything
    return;
  }
  
  @override
  Future<void> dispose() async {
    // Mock disposal
    return;
  }
}

/// Mock implementation of IVideoManager for testing
/// 
/// This implementation provides full control over behavior for testing purposes.
/// It simulates real video manager behavior including state transitions,
/// memory management, error conditions, and performance characteristics.
class MockVideoManager implements IVideoManager {
  final VideoManagerConfig _config;
  final Map<String, VideoState> _videoStates = {};
  final Map<String, VideoPlayerController> _controllers = {};
  final List<String> _orderedVideoIds = []; // Newest first
  final StreamController<void> _stateController = StreamController<void>.broadcast();
  
  // Test control flags
  bool _shouldFailPreload = false;
  String? _failurePattern;
  Duration _preloadDelay = Duration.zero;
  bool _disposed = false;
  
  MockVideoManager({VideoManagerConfig? config}) 
      : _config = config ?? const VideoManagerConfig();
  
  @override
  List<VideoEvent> get videos {
    if (_disposed) return [];
    
    return _orderedVideoIds
        .map((id) => _videoStates[id])
        .where((state) => state != null && 
                         state.loadingState != VideoLoadingState.permanentlyFailed &&
                         state.loadingState != VideoLoadingState.failed)
        .map((state) => state!.event)
        .toList();
  }
  
  @override
  List<VideoEvent> get readyVideos {
    if (_disposed) return [];
    
    return _videoStates.values
        .where((state) => state.isReady)
        .map((state) => state.event)
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
    
    final state = _videoStates[videoId];
    if (state?.isReady == true && !state!.isDisposed) {
      return _controllers[videoId];
    }
    return null;
  }
  
  @override
  Future<void> addVideoEvent(VideoEvent event) async {
    if (_disposed) {
      throw VideoManagerException(
        'Cannot add video to disposed manager',
      );
    }
    
    // Validate event - this will throw TypeError if event is null
    if (event.id.isEmpty) {
      throw VideoManagerException('Video ID cannot be empty', videoId: event.id);
    }
    
    // Prevent duplicates
    if (_videoStates.containsKey(event.id)) {
      return; // No-op for duplicates
    }
    
    // Create initial state
    _videoStates[event.id] = VideoState(event: event);
    _orderedVideoIds.insert(0, event.id); // Newest first
    
    // Handle GIFs immediately (they don't need preloading)
    if (event.isGif) {
      _videoStates[event.id] = _videoStates[event.id]!.toReady();
    }
    
    // Enforce memory limits
    _enforceMemoryLimits();
    
    _notifyStateChange();
  }
  
  @override
  Future<void> preloadVideo(String videoId) async {
    if (_disposed) return;
    
    final state = _videoStates[videoId];
    if (state == null) {
      // Silently handle nonexistent videos
      return;
    }
    
    // Skip if already loading/ready/permanently failed
    if (state.isLoading || state.isReady || 
        state.loadingState == VideoLoadingState.permanentlyFailed) {
      return;
    }
    
    // Allow retries for failed videos (but not permanently failed)
    
    // Update to loading
    _videoStates[videoId] = state.toLoading();
    _notifyStateChange();
    
    try {
      // Simulate loading delay
      if (_preloadDelay > Duration.zero) {
        await Future.delayed(_preloadDelay);
      } else {
        await Future.delayed(const Duration(milliseconds: 50)); // Minimal delay
      }
      
      // Check if this video should fail
      bool shouldFail = _shouldFailPreload || 
                       _shouldVideoFail(state.event.videoUrl ?? '');
      
      if (shouldFail) {
        throw Exception('Mock preload failure for testing');
      }
      
      try {
        // Create mock controller for successful load
        _controllers[videoId] = MockVideoPlayerController();
        
        // Mark as ready (use current state from the map, which should be 'loading')
        final currentState = _videoStates[videoId]!;
        _videoStates[videoId] = currentState.toReady();
      } catch (controllerError) {
        // If controller creation fails, just mark as ready without controller
        // This is for testing purposes only
        final currentState = _videoStates[videoId]!;
        _videoStates[videoId] = currentState.toReady();
      }
      
    } catch (e) {
      // Handle failure with retry logic
      final currentState = _videoStates[videoId];
      if (currentState != null) {
        _videoStates[videoId] = currentState.toFailed(e.toString());
      }
    }
    
    _notifyStateChange();
  }
  
  @override
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    if (_disposed) return;
    
    // Validate index
    if (currentIndex < 0 || currentIndex >= _orderedVideoIds.length) {
      return; // Silently handle invalid indices
    }
    
    // Use provided range or config default
    final range = preloadRange ?? _config.preloadAhead;
    
    // Preload current + next N videos
    final endIndex = (currentIndex + range).clamp(0, _orderedVideoIds.length - 1);
    
    for (int i = currentIndex; i <= endIndex; i++) {
      final videoId = _orderedVideoIds[i];
      preloadVideo(videoId); // Fire and forget
    }
    
    // Simulate cleanup of distant videos (if memory management enabled)
    if (_config.enableMemoryManagement) {
      _cleanupDistantVideos(currentIndex);
    }
  }
  
  @override
  void disposeVideo(String videoId) {
    if (_disposed) return;
    
    final state = _videoStates[videoId];
    if (state != null && !state.isDisposed) {
      // Dispose the controller if it exists
      final controller = _controllers.remove(videoId);
      controller?.dispose();
      
      // Update to disposed state
      _videoStates[videoId] = state.toDisposed();
      _notifyStateChange();
    }
  }

  @override
  Future<void> handleMemoryPressure() async {
    if (_disposed) return;
    
    // Simulate aggressive memory cleanup
    // Keep only current video (first in list) plus 1 ahead
    final videosToKeep = 2;
    final toRemove = _orderedVideoIds.skip(videosToKeep).toList();
    
    for (final videoId in toRemove) {
      // Dispose controller if it exists
      final controller = _controllers.remove(videoId);
      controller?.dispose();
      
      // Update state to disposed (but keep video in list)
      final state = _videoStates[videoId];
      if (state != null && !state.isDisposed) {
        _videoStates[videoId] = state.toDisposed();
      }
    }
    
    // Notify of aggressive cleanup
    _notifyStateChange();
  }
  
  @override
  Map<String, dynamic> getDebugInfo() {
    if (_disposed) {
      return {
        'disposed': true,
        'totalVideos': 0,
        'readyVideos': 0,
        'loadingVideos': 0,
        'failedVideos': 0,
        'controllers': 0,
        'estimatedMemoryMB': 0,
      };
    }
    
    final totalVideos = _videoStates.length;
    final readyCount = _videoStates.values.where((s) => s.isReady).length;
    final loadingCount = _videoStates.values.where((s) => s.isLoading).length;
    final failedCount = _videoStates.values.where((s) => s.hasFailed).length;
    final controllerCount = _controllers.length; // Actual controller count
    
    return {
      'totalVideos': totalVideos,
      'readyVideos': readyCount,
      'loadingVideos': loadingCount,
      'failedVideos': failedCount,
      'controllers': controllerCount,
      'estimatedMemoryMB': controllerCount * 30, // Mock: 30MB per controller
      'maxVideos': _config.maxVideos,
      'preloadAhead': _config.preloadAhead,
      'maxRetries': _config.maxRetries,
      'memoryManagement': _config.enableMemoryManagement,
    };
  }
  
  @override
  Stream<void> get stateChanges => _stateController.stream;
  
  @override
  void dispose() {
    if (_disposed) return;
    
    _disposed = true;
    
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    // Clear all state
    _videoStates.clear();
    _orderedVideoIds.clear();
    
    // Close stream
    _stateController.close();
  }
  
  // Test control methods
  
  /// Control whether preloading should fail for testing
  void setFailPreload(bool shouldFail) {
    _shouldFailPreload = shouldFail;
  }
  
  /// Set URL pattern that should trigger failures
  void setFailurePattern(String pattern) {
    _failurePattern = pattern;
  }
  
  /// Set artificial delay for preloading operations
  void setPreloadDelay(Duration delay) {
    _preloadDelay = delay;
  }
  
  /// Add multiple videos for bulk testing
  void addMockVideos(List<VideoEvent> videos) {
    for (final video in videos) {
      addVideoEvent(video);
    }
  }
  
  /// Simulate a video load with specific result
  void simulateVideoLoad(String videoId, {bool success = true}) {
    final state = _videoStates[videoId];
    if (state != null) {
      if (success) {
        _videoStates[videoId] = state.toReady();
      } else {
        _videoStates[videoId] = state.toFailed('Mock failure simulation');
      }
      _notifyStateChange();
    }
  }
  
  /// Simulate memory pressure cleanup
  void simulateMemoryPressure() {
    // Force cleanup by reducing limit temporarily
    final videosToKeep = _config.maxVideos ~/ 2;
    final toRemove = _orderedVideoIds.skip(videosToKeep).toList();
    
    for (final videoId in toRemove) {
      // Dispose controller if it exists
      final controller = _controllers.remove(videoId);
      controller?.dispose();
      
      // Remove from state tracking
      _videoStates.remove(videoId);
      _orderedVideoIds.remove(videoId);
    }
    
    _notifyStateChange();
  }
  
  /// Get count of videos in specific state for testing
  int getVideoCountInState(VideoLoadingState state) {
    return _videoStates.values.where((s) => s.loadingState == state).length;
  }
  
  // Private helper methods
  
  /// Enforce memory limits by removing old videos
  void _enforceMemoryLimits() {
    if (_videoStates.length <= _config.maxVideos) return;
    
    final videosToRemove = _orderedVideoIds.skip(_config.maxVideos).toList();
    
    for (final videoId in videosToRemove) {
      // Dispose controller if it exists
      final controller = _controllers.remove(videoId);
      controller?.dispose();
      
      // Remove from state tracking
      _videoStates.remove(videoId);
      _orderedVideoIds.remove(videoId);
    }
  }
  
  /// Cleanup videos far from current position  
  void _cleanupDistantVideos(int currentIndex) {
    final keepRange = _config.preloadAhead + 2; // Use preloadAhead + buffer
    final startKeep = (currentIndex - keepRange).clamp(0, _orderedVideoIds.length - 1);
    final endKeep = (currentIndex + keepRange).clamp(0, _orderedVideoIds.length - 1);
    
    // Dispose controllers outside keep range
    for (int i = 0; i < _orderedVideoIds.length; i++) {
      if (i < startKeep || i > endKeep) {
        final videoId = _orderedVideoIds[i];
        final state = _videoStates[videoId];
        if (state != null && state.isReady && !state.isDisposed) {
          // Dispose the controller
          final controller = _controllers.remove(videoId);
          controller?.dispose();
          
          // Update state to disposed
          _videoStates[videoId] = state.toDisposed();
        }
      }
    }
  }
  
  /// Check if a video URL should trigger failure (for testing)
  bool _shouldVideoFail(String videoUrl) {
    if (_failurePattern != null && videoUrl.contains(_failurePattern!)) {
      return true;
    }
    
    // Built-in failure patterns for testing
    return videoUrl.contains('invalid-url') || 
           videoUrl.contains('will-fail') ||
           videoUrl.contains('fail.mp4');
  }
  
  void _notifyStateChange() {
    if (!_disposed && !_stateController.isClosed) {
      _stateController.add(null);
    }
  }
}