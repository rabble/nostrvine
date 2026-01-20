import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' show VoidCallback;

import 'package:pooled_video_player/src/constants/pool_constants.dart';
import 'package:pooled_video_player/src/utils/device_memory_util.dart';
import 'package:video_player/video_player.dart';

/// Factory for creating video controllers. Allows injection for testing.
typedef VideoControllerFactory =
    Future<VideoPlayerController?> Function(
      String videoUrl, {
      File? cachedFile,
    });

/// Wraps a [VideoPlayerController] with pool metadata.
class PooledController {
  PooledController({
    required this.controller,
    required this.videoId,
    required this.videoUrl,
    required this.assignedAt,
  });

  final VideoPlayerController controller;
  final String videoId;
  final String videoUrl;
  final DateTime assignedAt;

  @override
  String toString() => 'PooledController(videoId: $videoId)';
}

/// Manages a fixed pool of [VideoPlayerController] instances with LRU eviction.
class VideoControllerPoolManager {
  VideoControllerPoolManager._({
    required this.poolSize,
    required VideoControllerFactory controllerFactory,
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

  static bool get isInitialized => _instance != null;

  /// Initialize the singleton. Call early in app lifecycle (e.g., main()).
  ///
  /// If [poolSize] is not provided, automatically detects optimal size based
  /// on device memory tier using [memoryClassifier].
  ///
  /// [controllerFactory] is required and creates video player controllers.
  /// For testing, inject a mock factory that returns test controllers.
  ///
  /// [memoryClassifier] can be provided for testing. If not provided, uses
  /// [DeviceMemoryUtil] for automatic device tier detection.
  static Future<VideoControllerPoolManager> initialize({
    required VideoControllerFactory controllerFactory,
    int? poolSize,
    DeviceMemoryUtil? memoryClassifier,
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
    await _instance!._initialize();
    return _instance!;
  }

  /// Get default pool size based on device memory tier.
  static Future<int> _getDefaultPoolSize(
    DeviceMemoryUtil classifier,
  ) async {
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

  final int poolSize;

  /// Custom controller factory for testing.
  final VideoControllerFactory _controllerFactory;

  final Map<String, PooledController> _pool = {};

  final LinkedHashMap<String, DateTime> _lruMap = LinkedHashMap();

  String? _activeVideoId;

  final Set<String> _prewarmVideoIds = {};

  /// Current scroll position for distance-aware eviction.
  int? _currentScrollIndex;

  /// Maps video IDs to their feed indices for distance calculation.
  final Map<String, int> _videoIndexMap = {};

  final Map<String, DateTime> _failedUrls = {};

  static const Duration _failedUrlCacheDuration =
      PoolConstants.failedUrlCacheDuration;

  bool _isInitialized = false;

  bool _isDisposed = false;

  final Set<VoidCallback> _listeners = <VoidCallback>{};

  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  /// Number of concurrent video initializations currently in progress.
  int _activeInitializations = 0;

  /// Maximum concurrent initializations allowed.
  /// Allows active video + 3 prewarms to init simultaneously.
  /// Higher value helps with short videos where users scroll quickly.
  static const int _maxConcurrentInitializations =
      PoolConstants.maxConcurrentInitializations;

  /// Video IDs whose acquisition has been cancelled.
  /// Used to abort in-flight controller initializations during fast scroll.
  final Set<String> _cancelledVideoIds = <String>{};

  /// Video IDs currently being initialized (in-flight requests).
  final Set<String> _inFlightVideoIds = <String>{};

  /// Distance threshold for cancelling distant in-flight requests during scroll.
  static const int _cancelDistanceThreshold =
      PoolConstants.distanceCancellationThreshold;

  /// Feed context tracking for multi-feed isolation.
  /// Active feed context - controllers for this context are prioritized.
  String? _activeFeedContext;

  /// Maps feed context IDs to sets of video IDs belonging to that context.
  final Map<String, Set<String>> _feedContextVideos = <String, Set<String>>{};

  /// Paused feed contexts - controllers in paused contexts are protected.
  final Set<String> _pausedContexts = <String>{};

  /// Add a listener for pool state changes. Returns unsubscribe function.
  VoidCallback addPoolChangeListener(VoidCallback listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  String? get activeVideoId => _activeVideoId;

  Set<String> get prewarmVideoIds => Set.unmodifiable(_prewarmVideoIds);

  /// Returns the currently active feed context, if any.
  ///
  /// Useful for debugging multi-feed scenarios to understand which feed
  /// currently has priority for controller retention.
  String? get activeFeedContext => _activeFeedContext;

  /// Register a video's position in the feed for distance-aware eviction.
  void registerVideoIndex(String videoId, int index) {
    _videoIndexMap[videoId] = index;
  }

  /// Set the active feed context. Controllers for this context are prioritized
  /// for retention during eviction.
  ///
  /// Pass null to clear the active context.
  void setActiveFeedContext(String? contextId) {
    _activeFeedContext = contextId;
    _notifyListeners();
  }

  /// Register a video as belonging to a specific feed context.
  ///
  /// This allows the pool to understand which videos belong to which feed
  /// and make smarter eviction decisions when switching between feeds.
  void registerVideoForContext(String videoId, String contextId) {
    _feedContextVideos.putIfAbsent(contextId, () => {}).add(videoId);
  }

  /// Pause a feed context. Controllers for videos in paused contexts are
  /// protected from eviction until the context is resumed or cleared.
  ///
  /// Use this when navigating away from a feed to preserve its controllers.
  void pauseFeedContext(String contextId) {
    _pausedContexts.add(contextId);
    _notifyListeners();
  }

  /// Resume a feed context, allowing normal eviction of its videos.
  void resumeFeedContext(String contextId) {
    _pausedContexts.remove(contextId);
    _notifyListeners();
  }

  /// Clear all videos for a feed context. Call when a feed is permanently
  /// destroyed (not just navigated away).
  ///
  /// Does not immediately evict controllers - they will be evicted naturally
  /// via LRU when needed.
  void clearFeedContext(String contextId) {
    _feedContextVideos.remove(contextId);
    _pausedContexts.remove(contextId);
    _notifyListeners();
  }

  VideoPlayerController? getController(String videoId) {
    return _pool[videoId]?.controller;
  }

  Map<String, PooledController> get assignedControllers =>
      Map.unmodifiable(_pool);

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Cancel a pending acquisition for [videoId].
  ///
  /// If the video is currently being initialized, the acquisition will be
  /// aborted and the controller will not be added to the pool.
  void cancelAcquisition(String videoId) {
    if (_inFlightVideoIds.contains(videoId)) {
      _cancelledVideoIds.add(videoId);
    }
  }

  /// Cancel all in-flight acquisitions for videos far from [currentIndex].
  ///
  /// This is useful during fast scrolling to abort requests for videos
  /// that are no longer relevant.
  void cancelDistantInFlightRequests(int currentIndex) {
    final videosToCancel = <String>[];

    for (final videoId in _inFlightVideoIds) {
      if (videoId == _activeVideoId) continue;

      final index = _videoIndexMap[videoId];
      if (index != null) {
        final distance = (index - currentIndex).abs();
        if (distance > _cancelDistanceThreshold) {
          videosToCancel.add(videoId);
        }
      }
    }

    videosToCancel.forEach(cancelAcquisition);
  }

  /// Returns the set of video IDs currently being initialized.
  Set<String> get inFlightVideoIds => Set.unmodifiable(_inFlightVideoIds);

  bool _isUrlFailed(String videoUrl) {
    final failedAt = _failedUrls[videoUrl];
    if (failedAt == null) return false;

    final age = DateTime.now().difference(failedAt);
    if (age > _failedUrlCacheDuration) {
      _failedUrls.remove(videoUrl);
      return false;
    }
    return true;
  }

  /// Acquire a controller for [videoId]. Uses LRU eviction when pool is full.
  ///
  /// If [getCachedFile] is provided, it will be used to check if the video
  /// is available in the local cache. Cached videos use file-based controllers
  /// which initialize faster (5s timeout vs 15s for network).
  Future<PooledController?> acquireController({
    required String videoId,
    required String videoUrl,
    File? Function(String videoId)? getCachedFile,
  }) async {
    if (_isDisposed) {
      return null;
    }

    if (_isUrlFailed(videoUrl)) {
      return null;
    }

    if (_pool.containsKey(videoId)) {
      _updateLRU(videoId);
      final pooled = _pool[videoId]!;
      _notifyListeners();
      return pooled;
    }

    // Track this video as in-flight
    _inFlightVideoIds.add(videoId);

    // Wait if at max concurrent initializations
    if (_activeInitializations >= _maxConcurrentInitializations) {
      final waiter = Completer<void>();
      _waitQueue.add(waiter);
      await waiter.future;
    }
    _activeInitializations++;

    try {
      // Check if acquisition was cancelled while waiting
      if (_cancelledVideoIds.remove(videoId)) {
        return null;
      }

      if (_pool.containsKey(videoId)) {
        _updateLRU(videoId);
        final pooled = _pool[videoId]!;
        _notifyListeners();
        return pooled;
      }

      var evictionAttempts = 0;
      const maxEvictionAttempts = 3;
      while (_pool.length >= poolSize) {
        final evicted = await _evictLRU();
        if (!evicted) {
          evictionAttempts++;
          if (evictionAttempts >= maxEvictionAttempts) {
            return null;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      // Check cache first for instant playback
      final cachedFile = getCachedFile?.call(videoId);

      // Use the injected controller factory
      final controller = await _controllerFactory(
        videoUrl,
        cachedFile: cachedFile,
      );

      if (controller == null) {
        return null;
      }

      // Check if acquisition was cancelled during controller creation
      if (_cancelledVideoIds.remove(videoId)) {
        // Dispose the controller we just created since we don't need it
        try {
          await controller.dispose();
        } on Exception {
          // Ignore disposal errors
        }
        return null;
      }

      final pooled = PooledController(
        controller: controller,
        videoId: videoId,
        videoUrl: videoUrl,
        assignedAt: DateTime.now(),
      );

      _pool[videoId] = pooled;
      _updateLRU(videoId);

      _notifyListeners();
      return pooled;
    } finally {
      // Clean up in-flight tracking
      _inFlightVideoIds.remove(videoId);
      _cancelledVideoIds.remove(videoId);

      _activeInitializations--;
      // Wake up next waiter if any
      if (_waitQueue.isNotEmpty) {
        _waitQueue.removeFirst().complete();
      }
    }
  }

  /// Release controller back to pool (pauses but keeps for reuse).
  void releaseController(String videoId) {
    if (!_pool.containsKey(videoId)) return;

    final pooled = _pool[videoId]!;

    if (pooled.controller.value.isPlaying) {
      unawaited(pooled.controller.pause());
    }

    _prewarmVideoIds.remove(videoId);
    _notifyListeners();
  }

  /// Set currently active video. Active videos are never evicted.
  ///
  /// Optionally pass [index] for distance-aware eviction. If [cancelDistant]
  /// is true (default), in-flight requests for videos far from the current
  /// position will be cancelled.
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
  /// Optionally pass [currentIndex] for distance-aware eviction.
  void setPrewarmVideos(List<String> videoIds, {int? currentIndex}) {
    if (currentIndex != null) {
      _currentScrollIndex = currentIndex;
    }

    // Relaxed limit: poolSize - 1 (just reserve 1 slot for active video)
    // Distance-aware eviction will handle contention intelligently
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

  Future<void> dispose() async {
    if (_isDisposed) return;

    await _disposeAllControllers();
    _resetState();
    _isDisposed = true;
    _listeners.clear();
  }

  /// Distance-aware eviction: prefer evicting videos furthest from current
  /// scroll position to keep nearby videos ready for smooth playback.
  ///
  /// With feed context tracking, prioritizes evicting videos from:
  /// 1. Inactive/unpaused contexts (furthest first)
  /// 2. Active context (furthest first)
  /// 3. Prewarmed videos in inactive contexts (furthest first)
  /// 4. Prewarmed videos in active context (last resort, furthest first)
  /// 5. Never evicts videos in paused contexts
  Future<bool> _evictLRU() async {
    if (_lruMap.isEmpty) return false;

    String? victimId;
    var maxDistance = -1;

    // Helper: Check if video is in a paused context
    bool isInPausedContext(String videoId) {
      for (final pausedContext in _pausedContexts) {
        final videos = _feedContextVideos[pausedContext];
        if (videos != null && videos.contains(videoId)) {
          return true;
        }
      }
      return false;
    }

    // Helper: Check if video is in active context
    bool isInActiveContext(String videoId) {
      if (_activeFeedContext == null) return false;
      final videos = _feedContextVideos[_activeFeedContext];
      return videos != null && videos.contains(videoId);
    }

    // First pass: Non-protected videos NOT in active/paused contexts
    for (final id in _lruMap.keys) {
      if (id == _activeVideoId) continue;
      if (_prewarmVideoIds.contains(id)) continue;
      if (isInPausedContext(id)) continue;
      if (isInActiveContext(id)) continue;

      final distance = _getDistanceFromCurrent(id);
      if (distance > maxDistance) {
        maxDistance = distance;
        victimId = id;
      }
    }

    // Second pass: Non-protected videos in active context (but not paused)
    if (victimId == null) {
      maxDistance = -1;
      for (final id in _lruMap.keys) {
        if (id == _activeVideoId) continue;
        if (_prewarmVideoIds.contains(id)) continue;
        if (isInPausedContext(id)) continue;
        if (!isInActiveContext(id)) continue; // Only active context now

        final distance = _getDistanceFromCurrent(id);
        if (distance > maxDistance) {
          maxDistance = distance;
          victimId = id;
        }
      }
    }

    // Third pass: Prewarmed videos NOT in active/paused contexts
    if (victimId == null && _prewarmVideoIds.isNotEmpty) {
      maxDistance = -1;
      for (final id in _prewarmVideoIds) {
        if (id == _activeVideoId) continue;
        if (!_pool.containsKey(id)) continue;
        if (isInPausedContext(id)) continue;
        if (isInActiveContext(id)) continue;

        final distance = _getDistanceFromCurrent(id);
        if (distance > maxDistance) {
          maxDistance = distance;
          victimId = id;
        }
      }
    }

    // Fourth pass: Prewarmed videos in active context (last resort)
    if (victimId == null && _prewarmVideoIds.isNotEmpty) {
      maxDistance = -1;
      for (final id in _prewarmVideoIds) {
        if (id == _activeVideoId) continue;
        if (!_pool.containsKey(id)) continue;
        if (isInPausedContext(id)) continue;
        if (!isInActiveContext(id)) continue; // Only active context now

        final distance = _getDistanceFromCurrent(id);
        if (distance > maxDistance) {
          maxDistance = distance;
          victimId = id;
        }
      }
    }

    if (victimId == null) {
      return false;
    }

    await _evictController(victimId);
    return true;
  }

  /// Calculate distance from current scroll position.
  /// Returns large value if no index is known (fallback to LRU behavior).
  int _getDistanceFromCurrent(String videoId) {
    final index = _videoIndexMap[videoId];
    if (index == null || _currentScrollIndex == null) {
      // No position info - use LRU order as tiebreaker (return 0)
      // This ensures videos without index info are evicted before those with
      return 0;
    }
    return (index - _currentScrollIndex!).abs();
  }

  Future<void> _evictController(String videoId) async {
    final pooled = _pool.remove(videoId);
    if (pooled == null) return;

    _lruMap.remove(videoId);
    _prewarmVideoIds.remove(videoId);

    try {
      if (pooled.controller.value.isPlaying) {
        await pooled.controller.pause();
      }
      await pooled.controller.dispose();
    } on Exception {
      // Ignore disposal errors
    }
  }

  void _updateLRU(String videoId) {
    _lruMap.remove(videoId);
    _lruMap[videoId] = DateTime.now();
  }

  /// Dispose all controllers in the pool.
  Future<void> _disposeAllControllers() async {
    for (final pooled in _pool.values) {
      try {
        await pooled.controller.dispose();
      } on Exception {
        // Ignore disposal errors
      }
    }
  }

  /// Reset all pool state.
  void _resetState() {
    _pool.clear();
    _lruMap.clear();
    _activeVideoId = null;
    _prewarmVideoIds.clear();
    _currentScrollIndex = null;
    _videoIndexMap.clear();
    _cancelledVideoIds.clear();
    _inFlightVideoIds.clear();
    _activeFeedContext = null;
    _feedContextVideos.clear();
    _pausedContexts.clear();
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
