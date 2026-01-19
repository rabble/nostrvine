import 'dart:async';
import 'dart:collection';

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show VoidCallback;

import 'package:video_player/video_player.dart';

/// Function type for synchronous cache file lookup.
/// Returns [File] if video is cached, null otherwise.
typedef CacheFileLookup = File? Function(String videoId);

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

  Duration get age => DateTime.now().difference(assignedAt);

  @override
  String toString() =>
      'PooledController(videoId: $videoId, age: ${age.inSeconds}s)';
}

/// Manages a fixed pool of [VideoPlayerController] instances with LRU eviction.
class VideoControllerPoolManager {
  VideoControllerPoolManager._({required this.poolSize});

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

  /// Reset the singleton (useful for testing).
  static Future<void> reset() async {
    await _instance?.dispose();
    _instance = null;
  }

  final int poolSize;

  final Map<String, PooledController> _pool = {};

  final LinkedHashMap<String, DateTime> _lruMap = LinkedHashMap();

  String? _activeVideoId;

  final Set<String> _prewarmVideoIds = {};

  /// Current scroll position for distance-aware eviction.
  int? _currentScrollIndex;

  /// Maps video IDs to their feed indices for distance calculation.
  final Map<String, int> _videoIndexMap = {};

  final Map<String, DateTime> _failedUrls = {};

  static const _failedUrlCacheDuration = Duration(minutes: 5);

  bool _isInitialized = false;

  bool _isDisposed = false;

  final Set<VoidCallback> _listeners = {};

  final Queue<Completer<void>> _waitQueue = Queue();

  /// Number of concurrent video initializations currently in progress.
  int _activeInitializations = 0;

  /// Maximum concurrent initializations allowed.
  /// Allows active video + 3 prewarms to init simultaneously.
  /// Higher value helps with short videos where users scroll quickly.
  static const _maxConcurrentInitializations = 4;

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

  /// Register a video's position in the feed for distance-aware eviction.
  void registerVideoIndex(String videoId, int index) {
    _videoIndexMap[videoId] = index;
  }

  VideoPlayerController? getController(String videoId) {
    return _pool[videoId]?.controller;
  }

  Map<String, PooledController> get assignedControllers =>
      Map.unmodifiable(_pool);

  Future<void> _initialize() async {
    if (_isInitialized) return;

    developer.log(
      'Initializing video controller pool (size: $poolSize)',
      name: 'VideoControllerPoolManager',
    );

    _isInitialized = true;
  }

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

  void _markUrlFailed(String videoUrl) {
    _failedUrls[videoUrl] = DateTime.now();
    if (_failedUrls.length > 100) {
      final now = DateTime.now();
      _failedUrls.removeWhere(
        (_, failedAt) => now.difference(failedAt) > _failedUrlCacheDuration,
      );
    }
  }

  /// Acquire a controller for [videoId]. Uses LRU eviction when pool is full.
  ///
  /// If [getCachedFile] is provided, it will be used to check if the video
  /// is available in the local cache. Cached videos use file-based controllers
  /// which initialize faster (5s timeout vs 15s for network).
  Future<PooledController?> acquireController({
    required String videoId,
    required String videoUrl,
    CacheFileLookup? getCachedFile,
  }) async {
    if (_isDisposed) {
      developer.log('Attempted to acquire controller from disposed pool');
      return null;
    }

    if (_isUrlFailed(videoUrl)) {
      developer.log(
        'Skipping $videoId - URL in failed cache',
        name: 'VideoControllerPoolManager',
      );
      return null;
    }

    if (_pool.containsKey(videoId)) {
      _updateLRU(videoId);
      final pooled = _pool[videoId]!;
      developer.log(
        'Reusing existing controller for $videoId',
        name: 'VideoControllerPoolManager',
      );
      _notifyListeners();
      return pooled;
    }

    // Wait if at max concurrent initializations
    if (_activeInitializations >= _maxConcurrentInitializations) {
      final waiter = Completer<void>();
      _waitQueue.add(waiter);
      await waiter.future;
    }
    _activeInitializations++;

    try {
      if (_pool.containsKey(videoId)) {
        _updateLRU(videoId);
        final pooled = _pool[videoId]!;
        developer.log(
          'Reusing controller (after lock) for $videoId',
          name: 'VideoControllerPoolManager',
        );
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
            developer.log(
              'Pool full and cannot evict after $evictionAttempts attempts '
              '(pool: ${_pool.length}/$poolSize, active: $_activeVideoId, '
              'prewarm: $_prewarmVideoIds). Returning null for $videoId.',
              name: 'VideoControllerPoolManager',
            );
            return null;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      // Check cache first for instant playback
      final cachedFile = getCachedFile?.call(videoId);
      final VideoPlayerController? controller;

      if (cachedFile != null) {
        developer.log(
          '⚡ Cache hit for $videoId - using local file',
          name: 'VideoControllerPoolManager',
        );
        controller = await _createFileController(cachedFile);
      } else {
        developer.log(
          '🌐 Cache miss for $videoId - fetching from network',
          name: 'VideoControllerPoolManager',
        );
        controller = await _createNetworkController(videoUrl);
      }

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
    } finally {
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

    developer.log(
      'Released controller for $videoId (keeping in pool)',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Set currently active video. Active videos are never evicted.
  /// Optionally pass [index] for distance-aware eviction.
  void setActiveVideo(String videoId, {int? index}) {
    if (_activeVideoId == videoId && _currentScrollIndex == index) return;

    _activeVideoId = videoId;
    if (index != null) {
      _currentScrollIndex = index;
      _videoIndexMap[videoId] = index;
    }
    _updateLRU(videoId);

    developer.log(
      'Set active video: $videoId (index: $index)',
      name: 'VideoControllerPoolManager',
    );

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

    if (videoIds.length > maxPrewarm) {
      developer.log(
        'Prewarm limited from ${videoIds.length} to $maxPrewarm videos',
        name: 'VideoControllerPoolManager',
      );
    }

    developer.log(
      'Set prewarm videos: $limitedVideoIds (currentIndex: $currentIndex)',
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

    final sortedIds = _getSortedByPriority();

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
    _currentScrollIndex = null;
    _videoIndexMap.clear();

    developer.log(
      'Pool cleared successfully',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    developer.log(
      'Disposing video controller pool',
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
    _prewarmVideoIds.clear();
    _activeVideoId = null;
    _currentScrollIndex = null;
    _videoIndexMap.clear();
    _isDisposed = true;
    _listeners.clear();
  }

  /// Create a controller from a local cached file.
  /// Uses shorter timeout (5s) since local file access is faster.
  Future<VideoPlayerController?> _createFileController(File file) async {
    try {
      final controller = VideoPlayerController.file(file);

      await controller.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException(
            'File video initialization timed out after 5s',
            const Duration(seconds: 5),
          );
        },
      );

      await controller.setLooping(true);

      return controller;
    } on Exception catch (e) {
      developer.log(
        'Failed to create file controller for ${file.path}: $e',
        name: 'VideoControllerPoolManager',
      );
      return null;
    }
  }

  /// Create a controller from a network URL.
  /// Uses longer timeout (15s) for network fetching.
  Future<VideoPlayerController?> _createNetworkController(
    String videoUrl,
  ) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
            'Video initialization timed out after 15s',
            const Duration(seconds: 15),
          );
        },
      );

      await controller.setLooping(true);

      return controller;
    } on Exception catch (e) {
      developer.log(
        'Failed to create network controller for $videoUrl: $e',
        name: 'VideoControllerPoolManager',
      );
      _markUrlFailed(videoUrl);
      return null;
    }
  }

  /// Distance-aware eviction: prefer evicting videos furthest from current
  /// scroll position to keep nearby videos ready for smooth playback.
  Future<bool> _evictLRU() async {
    if (_lruMap.isEmpty) return false;

    String? victimId;
    var maxDistance = -1;

    // First pass: Find cached (non-protected) video furthest from current pos
    for (final id in _lruMap.keys) {
      if (id == _activeVideoId) continue;
      if (_prewarmVideoIds.contains(id)) continue;

      final distance = _getDistanceFromCurrent(id);
      if (distance > maxDistance) {
        maxDistance = distance;
        victimId = id;
      }
    }

    // Second pass: If no cached videos, evict prewarmed video furthest away
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

    if (victimId == null) {
      developer.log(
        'Cannot evict: all controllers are protected '
        '(active: $_activeVideoId, prewarm: $_prewarmVideoIds)',
        name: 'VideoControllerPoolManager',
      );
      return false;
    }

    final victimIndex = _videoIndexMap[victimId];
    developer.log(
      'Evicting $victimId (index: $victimIndex, '
      'distance: $maxDistance from current: $_currentScrollIndex)',
      name: 'VideoControllerPoolManager',
    );

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

  void _updateLRU(String videoId) {
    _lruMap.remove(videoId);
    _lruMap[videoId] = DateTime.now();
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
