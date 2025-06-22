// ABOUTME: Fully controllable MockVideoManager implementation for testing
// ABOUTME: Provides deterministic behavior and test scenario control

import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';

/// Fully controllable mock implementation of IVideoManager for testing
/// 
/// This mock provides complete control over video manager behavior,
/// allowing tests to simulate various scenarios including:
/// - Success and failure states
/// - Memory pressure conditions
/// - Network issues and recovery
/// - Edge cases and race conditions
/// 
/// ## Basic Usage Examples
/// 
/// ```dart
/// // Basic video management
/// final mock = MockVideoManager();
/// await mock.addVideoEvent(testVideo);
/// await mock.preloadVideo(testVideo.id);
/// expect(mock.getVideoState(testVideo.id)!.isReady, isTrue);
/// 
/// // Check statistics
/// final stats = mock.getStatistics();
/// expect(stats['preloadCallCount'], equals(1));
/// 
/// // Always clean up
/// mock.dispose();
/// ```
/// 
/// ## Advanced Test Scenarios
/// 
/// ```dart
/// // Test failure scenarios
/// mock.setPreloadBehavior(PreloadBehavior.alwaysFail);
/// await mock.preloadVideo(testVideo.id);
/// expect(mock.getVideoState(testVideo.id)!.hasFailed, isTrue);
/// 
/// // Test retry logic
/// mock.setPreloadBehavior(PreloadBehavior.failOnce);
/// await mock.preloadVideo(testVideo.id); // Fails first time
/// await mock.preloadVideo(testVideo.id); // Succeeds second time
/// expect(mock.getPreloadAttempts(testVideo.id), equals(2));
/// 
/// // Test memory pressure
/// mock.setMemoryPressureThreshold(2);
/// await mock.addVideoEvent(video1);
/// await mock.addVideoEvent(video2); // Triggers memory pressure
/// expect(mock.getStatistics()['memoryPressureCallCount'], greaterThan(0));
/// 
/// // Test timing-sensitive operations
/// mock.setPreloadDelay(Duration(milliseconds: 100));
/// final start = DateTime.now();
/// await mock.preloadVideo(testVideo.id);
/// final elapsed = DateTime.now().difference(start);
/// expect(elapsed.inMilliseconds, greaterThanOrEqualTo(90));
/// 
/// // Test operation logging
/// mock.clearOperationLog();
/// await mock.addVideoEvent(testVideo);
/// final log = mock.getOperationLog();
/// expect(log.first, contains('addVideoEvent'));
/// 
/// // Reset between tests
/// mock.resetTestSettings(); // Resets all control settings
/// ```
/// 
/// ## Error Simulation Patterns
/// 
/// ```dart
/// // Simulate permanent failures
/// mock.markVideoPermanentlyFailed(testVideo.id);
/// await mock.preloadVideo(testVideo.id); // Won't attempt preload
/// 
/// // Disable exception throwing for graceful failure testing
/// mock.setThrowOnInvalidOperations(false);
/// mock.dispose();
/// await mock.addVideoEvent(testVideo); // Won't throw, returns gracefully
/// 
/// // Test state change notifications
/// final stateChanges = <void>[];
/// final subscription = mock.stateChanges.listen(stateChanges.add);
/// await mock.addVideoEvent(testVideo);
/// expect(stateChanges.length, greaterThan(0));
/// await subscription.cancel();
/// ```
class MockVideoManager implements IVideoManager {
  final List<VideoEvent> _videos = [];
  final Map<String, VideoState> _videoStates = {};
  final Map<String, VideoPlayerController?> _controllers = {};
  final StreamController<void> _stateChangesController = StreamController<void>.broadcast();
  
  // Configuration (ignored in mock but needed for compatibility)
  final VideoManagerConfig? _config;
  
  bool _disposed = false;
  
  // Test control properties
  PreloadBehavior _preloadBehavior = PreloadBehavior.normal;
  Duration _preloadDelay = const Duration(milliseconds: 50);
  int _memoryPressureThreshold = 10;
  bool _throwOnInvalidOperations = true;
  Map<String, int> _preloadAttempts = {};
  Set<String> _permanentlyFailedVideos = {};
  
  // Debug info for test control
  Map<String, dynamic> _debugInfo = {};
  
  // Test error control
  bool _shouldThrowOnAddVideo = false;
  bool _shouldThrowOnPreload = false;
  bool _shouldThrowOnOperation = false;
  
  // Call tracking for test verification
  List<VideoEvent> _addVideoEventCalls = [];
  List<String> _preloadVideoCalls = [];
  List<String> _disposeVideoCalls = [];
  List<List<dynamic>> _preloadAroundIndexCalls = [];
  
  // Statistics for test verification
  int _preloadCallCount = 0;
  int _disposeCallCount = 0;
  int _memoryPressureCallCount = 0;
  int _getDebugInfoCallCount = 0;
  List<String> _operationLog = [];
  
  /// Creates a MockVideoManager with optional configuration (for compatibility)
  MockVideoManager({VideoManagerConfig? config}) : _config = config;

  @override
  List<VideoEvent> get videos => List.unmodifiable(_videos);

  @override
  List<VideoEvent> get readyVideos => _videos
      .where((video) => getVideoState(video.id)?.isReady == true)
      .toList();

  @override
  VideoState? getVideoState(String videoId) => _videoStates[videoId];

  @override
  VideoPlayerController? getController(String videoId) => _controllers[videoId];

  @override
  Stream<void> get stateChanges => _stateChangesController.stream;

  @override
  Future<void> addVideoEvent(VideoEvent event) async {
    _logOperation('addVideoEvent', event.id);
    _addVideoEventCalls.add(event);
    
    if (_shouldThrowOnAddVideo || _shouldThrowOnOperation) {
      throw VideoManagerException('Mock configured to throw on addVideo');
    }
    
    if (_disposed) {
      if (_throwOnInvalidOperations) {
        throw VideoManagerException('Manager is disposed');
      }
      return;
    }
    
    if (event.id.isEmpty) {
      if (_throwOnInvalidOperations) {
        throw VideoManagerException('Invalid video event');
      }
      return;
    }
    
    // Prevent duplicates
    if (_videos.any((v) => v.id == event.id)) return;
    
    // Add in newest-first order
    _videos.insert(0, event);
    _videoStates[event.id] = VideoState(event: event);
    
    // Check for memory pressure
    if (_videos.length > _memoryPressureThreshold) {
      await handleMemoryPressure();
    }
    
    _notifyStateChange();
  }

  @override
  Future<void> preloadVideo(String videoId) async {
    _logOperation('preloadVideo', videoId);
    _preloadCallCount++;
    _preloadVideoCalls.add(videoId);
    
    if (_shouldThrowOnPreload || _shouldThrowOnOperation) {
      throw VideoManagerException('Mock configured to throw on preload');
    }
    
    if (_disposed) {
      if (_throwOnInvalidOperations) {
        throw VideoManagerException('Manager is disposed');
      }
      return;
    }
    
    final state = getVideoState(videoId);
    if (state == null) {
      if (_throwOnInvalidOperations) {
        throw VideoManagerException('Video not found', videoId: videoId);
      }
      return;
    }
    
    if (state.isReady) return; // Already preloaded
    
    // Track preload attempts
    _preloadAttempts[videoId] = (_preloadAttempts[videoId] ?? 0) + 1;
    
    // Check if permanently failed
    if (_permanentlyFailedVideos.contains(videoId)) {
      return; // Don't attempt preload
    }
    
    // Update to loading state (only if not already loading)
    if (!state.isLoading) {
      _videoStates[videoId] = state.toLoading();
      _notifyStateChange();
    }
    
    // Simulate loading delay
    await Future.delayed(_preloadDelay);
    
    // Determine outcome based on behavior setting
    final currentState = getVideoState(videoId);
    if (currentState == null || !currentState.isLoading) {
      return; // State changed during loading
    }
    
    switch (_preloadBehavior) {
      case PreloadBehavior.normal:
        _handleNormalPreload(videoId, currentState);
        break;
      case PreloadBehavior.alwaysFail:
        _handleFailedPreload(videoId, currentState, 'Mock configured to always fail');
        break;
      case PreloadBehavior.failOnce:
        if ((_preloadAttempts[videoId] ?? 0) == 1) {
          _handleFailedPreload(videoId, currentState, 'Mock configured to fail once');
        } else {
          _handleNormalPreload(videoId, currentState);
        }
        break;
      case PreloadBehavior.failOnRetry:
        if ((_preloadAttempts[videoId] ?? 0) > 1) {
          _handleFailedPreload(videoId, currentState, 'Mock configured to fail on retry');
        } else {
          _handleNormalPreload(videoId, currentState);
        }
        break;
      case PreloadBehavior.randomFail:
        if (videoId.hashCode % 3 == 0) {
          _handleFailedPreload(videoId, currentState, 'Mock random failure');
        } else {
          _handleNormalPreload(videoId, currentState);
        }
        break;
    }
    
    _notifyStateChange();
  }

  @override
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    _logOperation('preloadAroundIndex', 'index:$currentIndex, range:$preloadRange');
    _preloadAroundIndexCalls.add([currentIndex, preloadRange]);
    
    if (_disposed) return;
    
    if (_videos.isEmpty) return;
    
    final range = preloadRange ?? 2;
    final start = (currentIndex - range).clamp(0, _videos.length - 1);
    final end = (currentIndex + range).clamp(0, _videos.length - 1);
    
    for (int i = start; i <= end; i++) {
      if (i < _videos.length) {
        final videoId = _videos[i].id;
        final state = getVideoState(videoId);
        if (state != null && !state.isLoading && !state.isReady && !state.hasFailed) {
          preloadVideo(videoId);
        }
      }
    }
  }

  @override
  void disposeVideo(String videoId) {
    _logOperation('disposeVideo', videoId);
    _disposeCallCount++;
    _disposeVideoCalls.add(videoId);
    
    if (_disposed) return;
    
    _controllers[videoId]?.dispose();
    _controllers.remove(videoId);
    
    final state = getVideoState(videoId);
    if (state != null) {
      _videoStates[videoId] = state.toDisposed();
      _notifyStateChange();
    }
  }

  @override
  Future<void> handleMemoryPressure() async {
    _logOperation('handleMemoryPressure', '');
    _memoryPressureCallCount++;
    
    if (_disposed) return;
    
    await _triggerMemoryPressure();
  }

  @override
  Map<String, dynamic> getDebugInfo() {
    _getDebugInfoCallCount++;
    
    // Return custom debug info if set, otherwise return default
    if (_debugInfo.isNotEmpty) {
      return Map<String, dynamic>.from(_debugInfo);
    }
    
    return {
      'totalVideos': _videos.length,
      'readyVideos': readyVideos.length,
      'loadingVideos': _videoStates.values.where((s) => s.isLoading).length,
      'failedVideos': _videoStates.values.where((s) => s.hasFailed).length,
      'controllers': _controllers.length,
      'disposed': _disposed,
      'preloadCallCount': _preloadCallCount,
      'disposeCallCount': _disposeCallCount,
      'memoryPressureCallCount': _memoryPressureCallCount,
      'preloadBehavior': _preloadBehavior.toString(),
      'preloadDelay': _preloadDelay.inMilliseconds,
      'memoryPressureThreshold': _memoryPressureThreshold,
      'operationLog': List.from(_operationLog),
    };
  }

  @override
  void dispose() {
    _logOperation('dispose', '');
    
    _disposed = true;
    
    for (final controller in _controllers.values) {
      controller?.dispose();
    }
    _controllers.clear();
    _videoStates.clear();
    _videos.clear();
    _preloadAttempts.clear();
    _permanentlyFailedVideos.clear();
    _operationLog.clear();
    _addVideoEventCalls.clear();
    _preloadVideoCalls.clear();
    _disposeVideoCalls.clear();
    _preloadAroundIndexCalls.clear();
    _debugInfo.clear();
    
    _stateChangesController.close();
  }

  // Test control methods

  /// Set the preload behavior for controlling test scenarios
  void setPreloadBehavior(PreloadBehavior behavior) {
    _preloadBehavior = behavior;
  }

  /// Set the delay for preload operations
  void setPreloadDelay(Duration delay) {
    _preloadDelay = delay;
  }

  /// Set the threshold for triggering memory pressure
  void setMemoryPressureThreshold(int threshold) {
    _memoryPressureThreshold = threshold;
  }

  /// Control whether to throw exceptions on invalid operations
  void setThrowOnInvalidOperations(bool shouldThrow) {
    _throwOnInvalidOperations = shouldThrow;
  }

  /// Mark a video as permanently failed
  void markVideoPermanentlyFailed(String videoId) {
    _permanentlyFailedVideos.add(videoId);
  }

  /// Reset all test control settings to defaults
  void resetTestSettings() {
    _preloadBehavior = PreloadBehavior.normal;
    _preloadDelay = const Duration(milliseconds: 50);
    _memoryPressureThreshold = 10;
    _throwOnInvalidOperations = true;
    _shouldThrowOnAddVideo = false;
    _shouldThrowOnPreload = false;
    _shouldThrowOnOperation = false;
    _preloadAttempts.clear();
    _permanentlyFailedVideos.clear();
    _debugInfo.clear();
    _addVideoEventCalls.clear();
    _preloadVideoCalls.clear();
    _disposeVideoCalls.clear();
    _preloadAroundIndexCalls.clear();
    
    // Reset statistics
    _preloadCallCount = 0;
    _disposeCallCount = 0;
    _memoryPressureCallCount = 0;
    _getDebugInfoCallCount = 0;
  }

  /// Clear operation log for fresh test runs
  void clearOperationLog() {
    _operationLog.clear();
  }

  /// Get count of preload attempts for a specific video
  int getPreloadAttempts(String videoId) {
    return _preloadAttempts[videoId] ?? 0;
  }

  /// Check if a video is marked as permanently failed
  bool isVideoPermanentlyFailed(String videoId) {
    return _permanentlyFailedVideos.contains(videoId);
  }

  /// Get the operation log for test verification
  List<String> getOperationLog() {
    return List.from(_operationLog);
  }

  /// Get statistics for test verification
  Map<String, int> getStatistics() {
    return {
      'preloadCallCount': _preloadCallCount,
      'disposeCallCount': _disposeCallCount,
      'memoryPressureCallCount': _memoryPressureCallCount,
      'getDebugInfoCallCount': _getDebugInfoCallCount,
      'totalVideos': _videos.length,
      'readyVideos': readyVideos.length,
    };
  }
  
  // Test getters and setters for enhanced test control
  
  /// Set debug info to be returned by getDebugInfo()
  set debugInfo(Map<String, dynamic> info) {
    _debugInfo = Map<String, dynamic>.from(info);
  }
  
  /// Get debug info (for test verification)
  Map<String, dynamic> get debugInfo => Map<String, dynamic>.from(_debugInfo);
  
  /// Get list of addVideoEvent calls
  List<VideoEvent> get addVideoEventCalls => List.from(_addVideoEventCalls);
  
  /// Get count of addVideoEvent calls
  int get addVideoEventCallCount => _addVideoEventCalls.length;
  
  /// Get list of preloadVideo calls
  List<String> get preloadVideoCalls => List.from(_preloadVideoCalls);
  
  /// Get count of preloadVideo calls
  int get preloadVideoCallCount => _preloadVideoCalls.length;
  
  /// Get list of disposeVideo calls
  List<String> get disposeVideoCalls => List.from(_disposeVideoCalls);
  
  /// Get count of disposeVideo calls
  int get disposeVideoCallCount => _disposeVideoCalls.length;
  
  /// Get list of preloadAroundIndex calls
  List<List<dynamic>> get preloadAroundIndexCalls => List.from(_preloadAroundIndexCalls);
  
  /// Get count of preloadAroundIndex calls
  int get preloadAroundIndexCallCount => _preloadAroundIndexCalls.length;
  
  /// Get count of getDebugInfo calls
  int get getDebugInfoCallCount => _getDebugInfoCallCount;
  
  /// Get count of handleMemoryPressure calls
  int get handleMemoryPressureCallCount => _memoryPressureCallCount;
  
  /// Get count of dispose calls
  int get disposeCallCount => _disposeCallCount;
  
  /// Check if disposed
  bool get isDisposed => _disposed;
  
  /// Control exception throwing for addVideo operations
  set shouldThrowOnAddVideo(bool shouldThrow) {
    _shouldThrowOnAddVideo = shouldThrow;
  }
  
  /// Control exception throwing for preload operations
  set shouldThrowOnPreload(bool shouldThrow) {
    _shouldThrowOnPreload = shouldThrow;
  }
  
  /// Control exception throwing for all operations
  set shouldThrowOnOperation(bool shouldThrow) {
    _shouldThrowOnOperation = shouldThrow;
  }
  
  /// Set video state for testing
  void setVideoState(String videoId, VideoState state) {
    _videoStates[videoId] = state;
  }
  
  /// Set controller for testing
  void setController(String videoId, VideoPlayerController? controller) {
    _controllers[videoId] = controller;
  }
  
  /// Simulate state change for testing notifications
  void simulateStateChange() {
    _notifyStateChange();
  }
  
  /// Create a mock controller for testing
  static VideoPlayerController? createMockController() {
    // Return null for simplicity in testing - real implementation would return mock
    return null;
  }
  
  /// Override videos list for testing
  set videos(List<VideoEvent> videoList) {
    _videos.clear();
    _videos.addAll(videoList);
  }
  
  /// Override ready videos list for testing
  set readyVideos(List<VideoEvent> videoList) {
    // Clear existing videos and states
    _videos.clear();
    _videoStates.clear();
    
    // Add videos and set up states as ready
    _videos.addAll(videoList);
    for (final video in videoList) {
      // Proper state transition: notLoaded -> loading -> ready
      final initialState = VideoState(event: video);
      final loadingState = initialState.toLoading();
      _videoStates[video.id] = loadingState.toReady();
    }
  }

  // Private helper methods

  void _handleNormalPreload(String videoId, VideoState currentState) {
    if (videoId.contains('fail')) {
      _handleFailedPreload(videoId, currentState, 'Simulated failure based on ID');
    } else {
      _videoStates[videoId] = currentState.toReady();
      _controllers[videoId] = null; // Would be real controller in implementation
    }
  }

  void _handleFailedPreload(String videoId, VideoState currentState, String errorMessage) {
    try {
      _videoStates[videoId] = currentState.toFailed(errorMessage);
    } catch (e) {
      // If max retries exceeded, state becomes permanently failed
      _permanentlyFailedVideos.add(videoId);
    }
  }

  Future<void> _triggerMemoryPressure() async {
    _logOperation('_triggerMemoryPressure', '');
    // Don't increment count here - it's already incremented in the caller
    
    // Dispose all but the most recent video
    final controllersToDispose = List.from(_controllers.keys);
    for (final videoId in controllersToDispose.skip(1)) {
      disposeVideo(videoId);
    }
  }

  void _logOperation(String operation, String context) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _operationLog.add('$timestamp: $operation($context)');
    
    // Keep log size manageable
    if (_operationLog.length > 100) {
      _operationLog.removeRange(0, _operationLog.length - 100);
    }
  }

  void _notifyStateChange() {
    if (!_disposed && !_stateChangesController.isClosed) {
      _stateChangesController.add(null);
    }
  }
}

/// Enum for controlling preload behavior in tests
enum PreloadBehavior {
  /// Normal preload behavior - success unless video ID contains 'fail'
  normal,
  
  /// Always fail preload operations
  alwaysFail,
  
  /// Fail on first attempt, succeed on subsequent attempts
  failOnce,
  
  /// Succeed on first attempt, fail on retry attempts
  failOnRetry,
  
  /// Randomly fail based on video ID hash
  randomFail,
}