import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pooled_video_player/src/constants/pool_constants.dart';
import 'package:pooled_video_player/src/utils/device_memory_util.dart';
import 'package:video_player/video_player.dart';

/// Factory for creating video controllers. Used for testing only.
@visibleForTesting
typedef VideoControllerFactory =
    Future<VideoPlayerController?> Function(
      String videoUrl, {
      File? cachedFile,
    });

/// Wraps a [VideoPlayerController] with pool metadata.
class PooledController {
  /// Creates a pooled controller wrapper.
  PooledController({
    required this.controller,
    required this.videoId,
  });

  /// The underlying video player controller.
  final VideoPlayerController controller;

  /// Unique identifier for this video in the pool.
  final String videoId;

  @override
  String toString() => 'PooledController(videoId: $videoId)';
}

/// Manages a fixed pool of [VideoPlayerController] instances with LRU eviction.
///
/// This singleton class provides efficient video controller management for
/// scrollable video feeds (like TikTok-style UIs). It maintains a limited pool
/// of pre-initialized controllers to ensure smooth playback while minimizing
/// memory usage.
///
/// ## Initialization
///
/// Call [initialize] early in the app lifecycle (e.g., in `main()`):
///
/// ```dart
/// await VideoControllerPoolManager.initialize();
/// ```
///
/// ## Pool Size
///
/// Pool size is automatically determined based on device memory tier:
/// - Low memory devices (older phones): 2 controllers
/// - Medium memory devices: 3 controllers
/// - High memory devices (modern phones): 4 controllers
///
/// Override with explicit `poolSize` parameter if needed.
///
/// ## Distance-Aware Eviction
///
/// When the pool is full and a new controller is needed, the pool uses
/// distance-aware LRU eviction:
///
/// 1. Active video is never evicted
/// 2. Prewarmed videos are protected but can be evicted if no other option
/// 3. Among remaining videos, the one furthest from current scroll position
///    is evicted first
///
/// This ensures videos near the user's current position stay ready for
/// instant playback during scrolling.
///
/// ## Usage with Feed Widgets
///
/// Typically used with `PooledVideoFeed` and `PooledVideoPlayer`:
///
/// ```dart
/// PooledVideoFeed(
///   videos: videos,
///   itemBuilder: (context, video, index, isActive) => PooledVideoPlayer(
///     video: video,
///     autoPlay: isActive,
///     videoBuilder: (context, controller) => VideoPlayer(controller),
///   ),
/// )
/// ```
class VideoControllerPoolManager {
  VideoControllerPoolManager._({
    required this.poolSize,
    VideoControllerFactory? controllerFactory,
  }) : _controllerFactory = controllerFactory;

  static VideoControllerPoolManager? _instance;

  /// Throws [StateError] if not initialized.
  static VideoControllerPoolManager get instance {
    if (_instance == null) {
      throw StateError(
        'VideoControllerPoolManager not initialized. '
        'Call VideoControllerPoolManager.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Whether the pool manager has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initialize the singleton. Call early in app lifecycle (e.g., main()).
  ///
  /// If [poolSize] is not provided, automatically detects optimal size based
  /// on device memory tier.
  ///
  /// The [controllerFactory] parameter is for testing only. In production,
  /// controllers are created using the default implementation.
  static Future<VideoControllerPoolManager> initialize({
    int? poolSize,
    DeviceMemoryUtil? memoryClassifier,
    @visibleForTesting VideoControllerFactory? controllerFactory,
  }) async {
    if (_instance != null) {
      await _instance!.dispose();
    }

    final classifier = memoryClassifier ?? DeviceMemoryUtil();
    final effectivePoolSize = poolSize ?? await _getDefaultPoolSize(classifier);

    _instance = VideoControllerPoolManager._(
      poolSize: effectivePoolSize,
      controllerFactory: controllerFactory,
    );
    return _instance!;
  }

  static Future<int> _getDefaultPoolSize(DeviceMemoryUtil classifier) async {
    final tier = await classifier.getMemoryTier();
    return switch (tier) {
      MemoryTier.low => MemoryTierConfig.lowMemoryPoolSize,
      MemoryTier.medium => MemoryTierConfig.mediumMemoryPoolSize,
      MemoryTier.high => MemoryTierConfig.highMemoryPoolSize,
    };
  }

  /// Reset the singleton (useful for testing).
  static Future<void> reset() async {
    await _instance?.dispose();
    _instance = null;
  }

  /// Maximum number of controllers maintained in the pool.
  final int poolSize;

  /// Optional factory for creating controllers. Used for testing only.
  /// When null, controllers are created using the default implementation.
  final VideoControllerFactory? _controllerFactory;

  final Map<String, PooledController> _pool = {};
  final LinkedHashMap<String, DateTime> _lruMap = LinkedHashMap();

  String? _activeVideoId;
  final Set<String> _prewarmVideoIds = {};

  /// Current scroll position for distance-aware eviction.
  int? _currentScrollIndex;

  /// Maps video IDs to their feed indices for distance calculation.
  final Map<String, int> _videoIndexMap = {};

  bool _isDisposed = false;

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  int _activeInitializations = 0;

  /// Video IDs whose acquisition has been cancelled.
  final Set<String> _cancelledVideoIds = <String>{};

  /// Video IDs currently being initialized (in-flight requests).
  final Set<String> _inFlightVideoIds = <String>{};

  // Public API

  /// The ID of the currently active video, if any.
  String? get activeVideoId => _activeVideoId;

  /// IDs of videos marked for prewarming (protected from eviction).
  Set<String> get prewarmVideoIds => Set.unmodifiable(_prewarmVideoIds);

  /// IDs of videos currently being initialized (in-flight requests).
  Set<String> get inFlightVideoIds => Set.unmodifiable(_inFlightVideoIds);

  /// Read-only map of video IDs to their assigned pooled controllers.
  Map<String, PooledController> get assignedControllers =>
      Map.unmodifiable(_pool);

  /// Returns the controller for [videoId], or null if not in pool.
  VideoPlayerController? getController(String videoId) {
    return _pool[videoId]?.controller;
  }

  /// Register a video's position in the feed for distance-aware eviction.
  void registerVideoIndex(String videoId, int index) {
    _videoIndexMap[videoId] = index;
  }

  /// Add a listener for pool state changes. Returns unsubscribe function.
  VoidCallback addPoolChangeListener(VoidCallback listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notifyListeners() {
    // Copy list to prevent concurrent modification if listener unsubscribes
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  /// Cancel a pending acquisition for [videoId].
  void cancelAcquisition(String videoId) {
    if (_inFlightVideoIds.contains(videoId)) {
      _cancelledVideoIds.add(videoId);
    }
  }

  /// Cancel all in-flight acquisitions for videos far from [currentIndex].
  void cancelDistantInFlightRequests(int currentIndex) {
    final videosToCancel = <String>[];

    for (final videoId in _inFlightVideoIds) {
      if (videoId == _activeVideoId) continue;

      final index = _videoIndexMap[videoId];
      if (index != null) {
        final distance = (index - currentIndex).abs();
        if (distance > PoolConstants.distanceCancellationThreshold) {
          videosToCancel.add(videoId);
        }
      }
    }

    videosToCancel.forEach(cancelAcquisition);
  }

  /// Acquire a controller for [videoId]. Uses LRU eviction when pool is full.
  Future<PooledController?> acquireController({
    required String videoId,
    required String videoUrl,
    File? Function(String videoId)? getCachedFile,
  }) async {
    if (_isDisposed) return null;

    // Return existing controller if already in pool
    if (_pool.containsKey(videoId)) {
      _updateLRU(videoId);
      _notifyListeners();
      return _pool[videoId];
    }

    // Track this video as in-flight
    _inFlightVideoIds.add(videoId);

    // Wait if at max concurrent initializations
    if (_activeInitializations >= PoolConstants.maxConcurrentInitializations) {
      final waiter = Completer<void>();
      _waitQueue.add(waiter);
      await waiter.future;
    }
    _activeInitializations++;

    try {
      // Check if acquisition was cancelled while waiting
      if (_cancelledVideoIds.remove(videoId)) return null;

      // Double-check pool (might have been added while waiting)
      if (_pool.containsKey(videoId)) {
        _updateLRU(videoId);
        _notifyListeners();
        return _pool[videoId];
      }

      // Evict if pool is full
      var evictionAttempts = 0;
      const maxEvictionAttempts = 3;
      while (_pool.length >= poolSize) {
        final evicted = await _evictLRU();
        if (!evicted) {
          evictionAttempts++;
          if (evictionAttempts >= maxEvictionAttempts) return null;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      // Create controller
      final cachedFile = getCachedFile?.call(videoId);
      final VideoPlayerController controller;

      if (_controllerFactory != null) {
        // Use injected factory (for testing)
        final factoryController = await _controllerFactory(
          videoUrl,
          cachedFile: cachedFile,
        );
        if (factoryController == null) return null;
        controller = factoryController;
      } else {
        // coverage:ignore-start
        // Default implementation - requires real video files/network
        controller = cachedFile != null
            ? VideoPlayerController.file(cachedFile)
            : VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await controller.initialize();
        // coverage:ignore-end
      }

      // Check if cancelled during creation
      // coverage:ignore-start
      if (_cancelledVideoIds.remove(videoId)) {
        try {
          await controller.dispose();
        } on Exception {
          // Ignore disposal errors
        }
        return null;
      }
      // coverage:ignore-end

      final pooled = PooledController(
        controller: controller,
        videoId: videoId,
      );

      _pool[videoId] = pooled;
      _updateLRU(videoId);
      _notifyListeners();
      return pooled;
    } finally {
      _inFlightVideoIds.remove(videoId);
      _cancelledVideoIds.remove(videoId);
      _activeInitializations--;

      if (_waitQueue.isNotEmpty) {
        _waitQueue.removeFirst().complete();
      }
    }
  }

  /// Release controller back to pool (pauses but keeps for reuse).
  void releaseController(String videoId) {
    if (!_pool.containsKey(videoId)) return;

    final pooled = _pool[videoId]!;

    // Only pause if controller is still valid
    if (_isControllerValid(pooled.controller) &&
        pooled.controller.value.isPlaying) {
      unawaited(pooled.controller.pause());
    }

    _prewarmVideoIds.remove(videoId);
    _notifyListeners();
  }

  /// Set currently active video. Active videos are never evicted.
  void setActiveVideo(
    String videoId, {
    int? index,
    bool cancelDistant = true,
  }) {
    if (_activeVideoId == videoId && _currentScrollIndex == index) return;

    final previousIndex = _currentScrollIndex;
    _activeVideoId = videoId;

    if (index != null) {
      _currentScrollIndex = index;
      _videoIndexMap[videoId] = index;

      // Cancel distant in-flight requests during fast scroll
      if (cancelDistant &&
          previousIndex != null &&
          (index - previousIndex).abs() > 2) {
        cancelDistantInFlightRequests(index);
      }
    }

    _updateLRU(videoId);
    _notifyListeners();
  }

  /// Set videos to prewarm. Limited to poolSize-1 to leave room for active.
  void setPrewarmVideos(List<String> videoIds, {int? currentIndex}) {
    if (currentIndex != null) {
      _currentScrollIndex = currentIndex;
    }

    final maxPrewarm = (poolSize - 1).clamp(0, poolSize);
    final limitedVideoIds = videoIds.take(maxPrewarm).toList();

    _prewarmVideoIds
      ..clear()
      ..addAll(limitedVideoIds);

    _notifyListeners();
  }

  /// Release up to 50% of controllers under memory pressure.
  Future<void> handleMemoryPressure() async {
    if (_pool.isEmpty) return;

    final targetSize = (_pool.length / 2).ceil().clamp(1, _pool.length);
    final releaseCount = _pool.length - targetSize;

    final sortedIds = _getSortedByPriority();

    var released = 0;
    for (final id in sortedIds) {
      if (released >= releaseCount) break;
      await _evictController(id);
      released++;
    }

    _notifyListeners();
  }

  /// Dispose all controllers and reset pool state.
  Future<void> clearPool() async {
    await _disposeAllControllers();
    _resetState();
    _notifyListeners();
  }

  /// Disposes all controllers and marks the pool manager as disposed.
  Future<void> dispose() async {
    if (_isDisposed) return;

    await _disposeAllControllers();
    _resetState();
    _isDisposed = true;
    _listeners.clear();
  }

  // Private helpers

  bool _isControllerValid(VideoPlayerController controller) {
    try {
      controller.value;
      return true;
      // coverage:ignore-start
    } on Exception {
      return false;
    }
    // coverage:ignore-end
  }

  /// Distance-aware eviction: evict videos furthest from current position.
  Future<bool> _evictLRU() async {
    if (_lruMap.isEmpty) return false;

    String? victimId;
    var maxDistance = -1;

    // First pass: find non-protected video furthest from current position
    for (final id in _lruMap.keys) {
      if (id == _activeVideoId) continue;
      if (_prewarmVideoIds.contains(id)) continue;

      final distance = _getDistanceFromCurrent(id);
      if (distance > maxDistance) {
        maxDistance = distance;
        victimId = id;
      }
    }

    // Fallback: evict furthest prewarmed video if no other option
    if (victimId == null && _prewarmVideoIds.isNotEmpty) {
      maxDistance = -1;
      for (final id in _prewarmVideoIds) {
        if (id == _activeVideoId) continue;
        if (!_pool.containsKey(id)) continue;

        final distance = _getDistanceFromCurrent(id);
        if (distance > maxDistance) {
          maxDistance = distance;
          victimId = id;
        }
      }
    }

    if (victimId == null) return false;

    await _evictController(victimId);
    return true;
  }

  int _getDistanceFromCurrent(String videoId) {
    final index = _videoIndexMap[videoId];
    if (index == null || _currentScrollIndex == null) return 0;
    return (index - _currentScrollIndex!).abs();
  }

  Future<void> _evictController(String videoId) async {
    final pooled = _pool.remove(videoId);
    if (pooled == null) return;

    _lruMap.remove(videoId);
    _prewarmVideoIds.remove(videoId);

    try {
      if (_isControllerValid(pooled.controller)) {
        if (pooled.controller.value.isPlaying) {
          await pooled.controller.pause();
        }
        await pooled.controller.dispose();
      }
      // coverage:ignore-start
    } on Exception catch (e) {
      debugPrint('Controller disposal error for $videoId: $e');
    }
    // coverage:ignore-end
  }

  void _updateLRU(String videoId) {
    _lruMap.remove(videoId);
    _lruMap[videoId] = DateTime.now();
  }

  Future<void> _disposeAllControllers() async {
    for (final pooled in _pool.values) {
      try {
        await pooled.controller.dispose();
        // coverage:ignore-start
      } on Exception {
        // Ignore disposal errors
      }
      // coverage:ignore-end
    }
  }

  void _resetState() {
    _pool.clear();
    _lruMap.clear();
    _activeVideoId = null;
    _prewarmVideoIds.clear();
    _currentScrollIndex = null;
    _videoIndexMap.clear();
    _cancelledVideoIds.clear();
    _inFlightVideoIds.clear();
  }

  List<String> _getSortedByPriority() {
    final cached = <String>[];
    final prewarm = <String>[];

    for (final id in _lruMap.keys) {
      if (id == _activeVideoId) {
        continue;
      } else if (_prewarmVideoIds.contains(id)) {
        prewarm.add(id);
      } else {
        cached.add(id);
      }
    }

    return [...cached, ...prewarm];
  }
}
