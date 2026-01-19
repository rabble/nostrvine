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

  final Map<String, DateTime> _failedUrls = {};

  static const _failedUrlCacheDuration = Duration(minutes: 5);

  final Queue<VideoPlayerController> _freeControllers = Queue();

  bool _isInitialized = false;

  bool _isDisposed = false;

  final Set<VoidCallback> _listeners = {};

  final Queue<Completer<void>> _waitQueue = Queue();

  bool _isAcquiring = false;

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
  Future<PooledController?> acquireController({
    required String videoId,
    required String videoUrl,
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

    if (_isAcquiring) {
      final waiter = Completer<void>();
      _waitQueue.add(waiter);
      await waiter.future;
    }
    _isAcquiring = true;

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
    } finally {
      _isAcquiring = false;
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
  void setActiveVideo(String videoId) {
    if (_activeVideoId == videoId) return;

    _activeVideoId = videoId;
    _updateLRU(videoId);

    developer.log(
      'Set active video: $videoId',
      name: 'VideoControllerPoolManager',
    );

    _notifyListeners();
  }

  /// Set videos to prewarm. Limited to poolSize-2 to leave room for active + buffer.
  void setPrewarmVideos(List<String> videoIds) {
    final maxPrewarm = (poolSize - 2).clamp(0, poolSize);
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
      'Set prewarm videos: $limitedVideoIds',
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

  /// Handle app backgrounding - pause all controllers.
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

  /// Handle app foregrounding.
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

  Future<VideoPlayerController?> _getOrCreateController(String videoUrl) async {
    if (_freeControllers.isNotEmpty) {
      final controller = _freeControllers.removeFirst();
      await controller.dispose();
    }

    return _createController(videoUrl);
  }

  Future<VideoPlayerController?> _createController(String videoUrl) async {
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
        'Failed to create controller for $videoUrl: $e',
        name: 'VideoControllerPoolManager',
      );
      _markUrlFailed(videoUrl);
      return null;
    }
  }

  Future<bool> _evictLRU() async {
    if (_lruMap.isEmpty) return false;

    String? victimId;

    for (final id in _lruMap.keys) {
      if (id != _activeVideoId && !_prewarmVideoIds.contains(id)) {
        victimId = id;
        break;
      }
    }

    if (victimId == null && _prewarmVideoIds.isNotEmpty) {
      for (final id in _lruMap.keys) {
        if (_prewarmVideoIds.contains(id)) {
          victimId = id;
          break;
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

    await _evictController(victimId);
    return true;
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
