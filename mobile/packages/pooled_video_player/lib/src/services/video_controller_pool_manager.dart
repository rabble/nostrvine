import 'dart:async';
import 'dart:collection';

import 'dart:developer' as developer;
import 'dart:ui' show VoidCallback;

import 'package:video_player/video_player.dart';

/// Wraps a [VideoPlayerController] with pool metadata.
class PooledController {
  PooledController({
    required this.controller,
    required this.videoId,
    required this.videoUrl,
    required this.assignedAt,
  });

  /// The underlying video player controller
  final VideoPlayerController controller;

  /// Video ID this controller is assigned to
  final String videoId;

  /// Video URL this controller is playing
  final String videoUrl;

  /// Timestamp when this controller was assigned
  final DateTime assignedAt;

  /// Age of this controller assignment
  Duration get age => DateTime.now().difference(assignedAt);

  @override
  String toString() =>
      'PooledController(videoId: $videoId, age: ${age.inSeconds}s)';
}

/// Manages a fixed pool of [VideoPlayerController] instances with LRU eviction.
///
/// ```dart
/// await VideoControllerPoolManager.initialize(poolSize: 3);
/// final pool = VideoControllerPoolManager.instance;
///
/// final unsubscribe = pool.addPoolChangeListener(() {
///   final controller = pool.getController('video-id');
/// });
///
/// await pool.acquireController(videoId: 'id', videoUrl: 'url');
/// ```
class VideoControllerPoolManager {
  VideoControllerPoolManager._({required this.poolSize});

  /// Singleton instance
  static VideoControllerPoolManager? _instance;

  /// Get the singleton instance
  ///
  /// Throws [StateError] if not initialized. Call [initialize] first.
  static VideoControllerPoolManager get instance {
    if (_instance == null) {
      throw StateError(
        'VideoControllerPoolManager not initialized. '
        'Call VideoControllerPoolManager.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if the pool has been initialized
  static bool get isInitialized => _instance != null;

  /// Initialize the singleton with a specific pool size
  ///
  /// This should be called early in app lifecycle, typically in main()
  /// after determining device memory tier.
  ///
  /// If already initialized, this will dispose the existing instance
  /// and create a new one with the provided pool size.
  static Future<void> initialize({required int poolSize}) async {
    if (_instance != null) {
      developer.log(
        'Pool already initialized, disposing and recreating',
        name: 'VideoControllerPoolManager',
      );
      await _instance!.dispose();
    }
    _instance = VideoControllerPoolManager._(poolSize: poolSize);
    await _instance!._initialize();
  }

  /// Reset the singleton (useful for testing)
  static Future<void> reset() async {
    await _instance?.dispose();
    _instance = null;
  }

  /// Maximum number of controllers in the pool
  final int poolSize;

  /// Current pool of assigned controllers
  final Map<String, PooledController> _pool = {};

  /// LRU tracking - maps videoId to last access time
  final LinkedHashMap<String, DateTime> _lruMap = LinkedHashMap();

  /// Currently active (playing) video ID
  String? _activeVideoId;

  /// Video IDs to keep prewarmed (next/previous)
  final Set<String> _prewarmVideoIds = {};

  /// Free controllers available for reuse
  final Queue<VideoPlayerController> _freeControllers = Queue();

  /// Whether the pool has been initialized
  bool _isInitialized = false;

  /// Whether the pool has been disposed
  bool _isDisposed = false;

  /// Listeners for pool state changes
  final Set<VoidCallback> _listeners = {};

  /// Add a listener for pool state changes. Returns unsubscribe function.
  VoidCallback addPoolChangeListener(VoidCallback listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Notify all listeners of pool state changes.
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Get the currently active video ID
  String? get activeVideoId => _activeVideoId;

  /// Get prewarm video IDs
  Set<String> get prewarmVideoIds => Set.unmodifiable(_prewarmVideoIds);

  /// Get controller for [videoId], or null if not in pool.
  VideoPlayerController? getController(String videoId) {
    return _pool[videoId]?.controller;
  }

  /// Get all assigned controllers (read-only)
  Map<String, PooledController> get assignedControllers =>
      Map.unmodifiable(_pool);

  /// Initialize the pool. Safe to call multiple times.
  Future<void> _initialize() async {
    if (_isInitialized) return;

    developer.log(
      'Initializing video controller pool (size: $poolSize)',
      name: 'VideoControllerPoolManager',
    );

    // Note: Memory pressure and lifecycle callbacks would ideally be registered here
    // via WidgetsBindingObserver, but for simplicity we'll handle them via
    // external lifecycle management
    _isInitialized = true;
  }

  /// Acquire a controller for [videoId]. Uses LRU eviction when pool is full.
  Future<PooledController?> acquireController({
    required String videoId,
    required String videoUrl,
  }) async {
    if (_isDisposed) {
      developer.log('Attempted to acquire controller from disposed pool');
      return null;
    }

    // Check if already in pool (reuse existing)
    if (_pool.containsKey(videoId)) {
      _updateLRU(videoId);
      final pooled = _pool[videoId]!;
      developer.log(
        'Reusing existing controller for $videoId',
        name: 'VideoControllerPoolManager',
      );
      return pooled;
    }

    // Pool is full - evict LRU
    if (_pool.length >= poolSize) {
      await _evictLRU();
    }

    // Create or reuse controller
    final controller = await _getOrCreateController(videoUrl);
    if (controller == null) {
      developer.log(
        'Failed to create controller for $videoId',
        name: 'VideoControllerPoolManager',
      );
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

    developer.log(
      'Assigned controller to $videoId (pool: ${_pool.length}/$poolSize)',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
    return pooled;
  }

  /// Release controller back to pool (pauses but keeps for reuse).
  void releaseController(String videoId) {
    if (!_pool.containsKey(videoId)) return;

    final pooled = _pool[videoId]!;

    // Pause controller to save resources
    if (pooled.controller.value.isPlaying) {
      unawaited(pooled.controller.pause());
    }

    _prewarmVideoIds.remove(videoId);

    developer.log(
      'Released controller for $videoId (keeping in pool)',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Set currently active video. Active videos are never evicted.
  void setActiveVideo(String videoId) {
    if (_activeVideoId == videoId) return;

    _activeVideoId = videoId;
    _updateLRU(videoId); // Move to end (most recently used)

    developer.log(
      'Set active video: $videoId',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Set videos to prewarm. Prewarmed videos have higher eviction priority.
  void setPrewarmVideos(List<String> videoIds) {
    _prewarmVideoIds
      ..clear()
      ..addAll(videoIds);

    developer.log(
      'Set prewarm videos: $videoIds',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Release up to 50% of controllers under memory pressure.
  Future<void> handleMemoryPressure() async {
    developer.log(
      'Memory pressure detected - releasing controllers',
      name: 'VideoControllerPoolManager',
    );

    if (_pool.isEmpty) return;

    final targetSize = (_pool.length / 2).ceil().clamp(1, _pool.length);
    final releaseCount = _pool.length - targetSize;

    developer.log(
      'Releasing $releaseCount controllers (from ${_pool.length} to $targetSize)',
      name: 'VideoControllerPoolManager',
    );

    // Sort by priority (lowest first)
    final sortedIds = _getSortedByPriority();

    // Release lowest priority controllers
    var released = 0;
    for (final id in sortedIds) {
      if (released >= releaseCount) break;

      await _evictController(id);
      released++;
    }

    developer.log(
      'Released $released controllers, pool size now: ${_pool.length}',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Handle app backgrounding - pause all controllers
  void handleBackground() {
    developer.log(
      'App backgrounded - pausing all controllers',
      name: 'VideoControllerPoolManager',
    );

    for (final pooled in _pool.values) {
      if (pooled.controller.value.isPlaying) {
        unawaited(pooled.controller.pause());
      }
    }
  }

  /// Handle app foregrounding - ready for restoration
  void handleForeground() {
    developer.log(
      'App foregrounded - pool ready for restoration',
      name: 'VideoControllerPoolManager',
    );
  }

  /// Dispose all controllers and reset pool state.
  Future<void> clearPool() async {
    developer.log(
      'Clearing pool - disposing ${_pool.length} controllers',
      name: 'VideoControllerPoolManager',
    );

    for (final pooled in _pool.values) {
      try {
        await pooled.controller.dispose();
      } on Exception catch (e) {
        developer.log(
          'Error disposing controller ${pooled.videoId}: $e',
          name: 'VideoControllerPoolManager',
        );
      }
    }

    _pool.clear();
    _lruMap.clear();
    _activeVideoId = null;
    _prewarmVideoIds.clear();

    developer.log(
      'Pool cleared successfully',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Dispose all controllers and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    developer.log(
      'Disposing video controller pool',
      name: 'VideoControllerPoolManager',
    );

    // Dispose all pooled controllers
    for (final pooled in _pool.values) {
      try {
        await pooled.controller.dispose();
      } on Exception catch (e) {
        developer.log(
          'Error disposing controller ${pooled.videoId}: $e',
          name: 'VideoControllerPoolManager',
        );
      }
    }

    // Dispose free controllers
    for (final controller in _freeControllers) {
      try {
        await controller.dispose();
      } on Exception catch (e) {
        developer.log(
          'Error disposing free controller: $e',
          name: 'VideoControllerPoolManager',
        );
      }
    }

    _pool.clear();
    _lruMap.clear();
    _freeControllers.clear();
    _prewarmVideoIds.clear();
    _activeVideoId = null;
    _isDisposed = true;
    _listeners.clear();
  }

  // Private methods

  /// Get or create a controller for the given URL
  Future<VideoPlayerController?> _getOrCreateController(String videoUrl) async {
    // Try to reuse a free controller
    if (_freeControllers.isNotEmpty) {
      final controller = _freeControllers.removeFirst();
      // Note: video_player doesn't support URL changes, so we dispose and create new
      await controller.dispose();
    }

    // Create new controller
    return _createController(videoUrl);
  }

  /// Create a new video player controller
  Future<VideoPlayerController?> _createController(String videoUrl) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize();

      // Set looping for short videos
      await controller.setLooping(true);

      return controller;
    } on Exception catch (e) {
      developer.log(
        'Failed to create controller for $videoUrl: $e',
        name: 'VideoControllerPoolManager',
      );
      return null;
    }
  }

  /// Evict the least recently used controller
  Future<void> _evictLRU() async {
    if (_lruMap.isEmpty) return;

    // Find LRU that is not active or prewarmed
    String? victimId;

    // First pass: find cached (non-active, non-prewarm)
    for (final id in _lruMap.keys) {
      if (id != _activeVideoId && !_prewarmVideoIds.contains(id)) {
        victimId = id;
        break;
      }
    }

    // Second pass: find oldest prewarm (if no cached available)
    if (victimId == null && _prewarmVideoIds.isNotEmpty) {
      for (final id in _lruMap.keys) {
        if (_prewarmVideoIds.contains(id)) {
          victimId = id;
          break;
        }
      }
    }

    // Last resort: evict LRU even if active (shouldn't happen)
    victimId ??= _lruMap.keys.first;

    await _evictController(victimId);
  }

  /// Evict a specific controller from the pool
  Future<void> _evictController(String videoId) async {
    final pooled = _pool.remove(videoId);
    if (pooled == null) return;

    _lruMap.remove(videoId);
    _prewarmVideoIds.remove(videoId);

    // Pause and dispose controller
    try {
      if (pooled.controller.value.isPlaying) {
        await pooled.controller.pause();
      }
      await pooled.controller.dispose();
    } on Exception catch (e) {
      developer.log(
        'Error evicting controller $videoId: $e',
        name: 'VideoControllerPoolManager',
      );
    }

    developer.log(
      'Evicted controller for $videoId',
      name: 'VideoControllerPoolManager',
    );
  }

  /// Update LRU timestamp for a video
  void _updateLRU(String videoId) {
    _lruMap.remove(videoId);
    _lruMap[videoId] = DateTime.now();
  }

  /// Get video IDs sorted by eviction priority (lowest first).
  List<String> _getSortedByPriority() {
    final cached = <String>[];
    final prewarm = <String>[];

    for (final id in _lruMap.keys) {
      if (id == _activeVideoId) {
        continue; // Skip active - it's highest priority
      } else if (_prewarmVideoIds.contains(id)) {
        prewarm.add(id);
      } else {
        cached.add(id);
      }
    }

    // Return: cached (lowest) → prewarm → active (highest, but not included)
    return [...cached, ...prewarm];
  }
}
