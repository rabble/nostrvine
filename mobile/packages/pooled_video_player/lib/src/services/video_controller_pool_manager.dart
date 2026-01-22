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

/// Represents the initialization phase of a pooled video controller.
///
/// Two-phase initialization provides instant visual feedback:
/// - [none]: Controller not yet created
/// - [firstFrame]: First frame available for display (fast)
/// - [buffered]: Buffering complete, ready for smooth playback
enum ControllerPhase {
  /// Controller not yet created.
  none,

  /// First frame is available for display.
  /// The controller is initialized and seeked to frame 0.
  /// Widget can display the first frame immediately.
  firstFrame,

  /// Buffering is complete, ready for smooth playback.
  buffered,
}

/// Wraps a [VideoPlayerController] with pool metadata and initialization phase.
///
/// The [phase] tracks the two-phase initialization progress:
/// 1. [ControllerPhase.firstFrame] - First frame available for instant display
/// 2. [ControllerPhase.buffered] - Ready for smooth playback
class PooledController {
  /// Creates a pooled controller wrapper.
  PooledController({
    required this.controller,
    required this.videoId,
    this.phase = ControllerPhase.none,
  });

  /// The underlying video player controller.
  final VideoPlayerController controller;

  /// Unique identifier for this video in the pool.
  final String videoId;

  /// Current initialization phase.
  ///
  /// Starts at [ControllerPhase.none], transitions to
  /// [ControllerPhase.firstFrame] when the first frame is available for
  /// display, then to [ControllerPhase.buffered] when buffering is complete.
  ControllerPhase phase;

  /// Whether the first frame is available for display.
  bool get hasFirstFrame =>
      phase == ControllerPhase.firstFrame || phase == ControllerPhase.buffered;

  /// Whether buffering is complete and ready for smooth playback.
  bool get isBuffered => phase == ControllerPhase.buffered;

  @override
  String toString() => 'PooledController(videoId: $videoId, phase: $phase)';
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

  // ══════════════════════════════════════════════════════════════════════════
  // Configuration
  // ══════════════════════════════════════════════════════════════════════════

  /// Maximum number of controllers maintained in the pool.
  final int poolSize;

  /// Optional factory for creating controllers. Used for testing only.
  /// When null, controllers are created using the default implementation.
  final VideoControllerFactory? _controllerFactory;

  // ══════════════════════════════════════════════════════════════════════════
  // Pool Storage
  // ══════════════════════════════════════════════════════════════════════════

  /// Video ID → PooledController mapping for all controllers in the pool.
  final Map<String, PooledController> _pool = {};

  /// Video ID → last access time for LRU eviction ordering.
  final LinkedHashMap<String, DateTime> _lruMap = LinkedHashMap();

  // ══════════════════════════════════════════════════════════════════════════
  // Active/Prewarm State
  // ══════════════════════════════════════════════════════════════════════════

  /// Currently visible/playing video ID. Never evicted.
  String? _activeVideoId;

  /// Video IDs marked for prewarming. Protected from eviction unless necessary.
  final Set<String> _prewarmVideoIds = {};

  // ══════════════════════════════════════════════════════════════════════════
  // Distance-Aware Eviction
  // ══════════════════════════════════════════════════════════════════════════

  /// Current scroll position for distance-aware eviction.
  int? _currentScrollIndex;

  /// Maps video IDs to their feed indices for distance calculation.
  final Map<String, int> _videoIndexMap = {};

  // ══════════════════════════════════════════════════════════════════════════
  // Concurrency Control
  // ══════════════════════════════════════════════════════════════════════════

  /// Number of controllers currently being initialized.
  int _activeInitializations = 0;

  /// Queue of waiters blocked on max concurrent initializations.
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  /// Video IDs whose acquisition has been cancelled.
  final Set<String> _cancelledVideoIds = <String>{};

  /// Pending acquisition Futures for deduplication.
  ///
  /// When multiple callers request the same videoId concurrently, they share
  /// the same Future instead of creating duplicate network requests.
  final Map<String, Future<PooledController?>> _pendingAcquisitions = {};

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  /// Whether the pool manager has been disposed.
  bool _isDisposed = false;

  /// Pool change listeners for reactive updates.
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  // Public API

  /// The ID of the currently active video, if any.
  String? get activeVideoId => _activeVideoId;

  /// IDs of videos marked for prewarming (protected from eviction).
  Set<String> get prewarmVideoIds => Set.unmodifiable(_prewarmVideoIds);

  /// IDs of videos currently being initialized (in-flight requests).
  Set<String> get inFlightVideoIds =>
      Set.unmodifiable(_pendingAcquisitions.keys.toSet());

  /// Read-only map of video IDs to their assigned pooled controllers.
  Map<String, PooledController> get assignedControllers =>
      Map.unmodifiable(_pool);

  /// Returns the controller for [videoId], or null if not in pool.
  VideoPlayerController? getController(String videoId) {
    return _pool[videoId]?.controller;
  }

  /// Returns the pooled controller (with phase info) for [videoId].
  ///
  /// Use this to check the initialization phase for instant visual feedback.
  PooledController? getPooledController(String videoId) {
    return _pool[videoId];
  }

  /// Returns the current phase of the controller for [videoId].
  ControllerPhase getControllerPhase(String videoId) {
    return _pool[videoId]?.phase ?? ControllerPhase.none;
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
    if (_pendingAcquisitions.containsKey(videoId)) {
      _cancelledVideoIds.add(videoId);
    }
  }

  /// Cancel all in-flight acquisitions for videos far from [currentIndex].
  void cancelDistantInFlightRequests(int currentIndex) {
    final videosToCancel = <String>[];

    for (final videoId in _pendingAcquisitions.keys) {
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
  ///
  /// Concurrent requests for the same videoId return the same Future,
  /// preventing duplicate network requests.
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

    // Return existing pending acquisition if already in-flight (deduplication)
    if (_pendingAcquisitions.containsKey(videoId)) {
      return _pendingAcquisitions[videoId];
    }

    // Create and track the acquisition Future
    final acquisitionFuture = _executeAcquisition(
      videoId: videoId,
      videoUrl: videoUrl,
      getCachedFile: getCachedFile,
    );

    _pendingAcquisitions[videoId] = acquisitionFuture;

    try {
      return await acquisitionFuture;
    } finally {
      // Remove from pending map - the Future value is intentionally discarded
      unawaited(_pendingAcquisitions.remove(videoId));
    }
  }

  /// Execute the actual controller acquisition logic.
  Future<PooledController?> _executeAcquisition({
    required String videoId,
    required String videoUrl,
    File? Function(String videoId)? getCachedFile,
  }) async {
    await _waitForInitializationSlot();

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
      if (!await _makeRoomInPool()) return null;

      // Create and initialize controller
      final controller = await _createController(
        videoId: videoId,
        videoUrl: videoUrl,
        getCachedFile: getCachedFile,
      );
      if (controller == null) return null;

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

      // Initialize for first frame display
      final pooled = await _initializeForFirstFrame(controller, videoId);

      _pool[videoId] = pooled;
      _updateLRU(videoId);
      _notifyListeners();

      // Phase 2: Complete buffering in background (non-blocking)
      unawaited(_completeBufferingPhase(pooled));

      return pooled;
    } finally {
      _cancelledVideoIds.remove(videoId);
      _releaseInitializationSlot();
    }
  }

  /// Waits for a slot in the concurrent initialization queue.
  Future<void> _waitForInitializationSlot() async {
    if (_activeInitializations >= PoolConstants.maxConcurrentInitializations) {
      final waiter = Completer<void>();
      _waitQueue.add(waiter);
      await waiter.future;
    }
    _activeInitializations++;
  }

  /// Signals completion of an initialization, releasing the slot.
  void _releaseInitializationSlot() {
    _activeInitializations--;
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeFirst().complete();
    }
  }

  /// Evicts controllers until there's room in the pool.
  ///
  /// Returns true if room was made, false if eviction failed after max attempts.
  Future<bool> _makeRoomInPool() async {
    var evictionAttempts = 0;
    const maxEvictionAttempts = 3;

    while (_pool.length >= poolSize) {
      final evicted = await _evictFurthestController();
      if (!evicted) {
        evictionAttempts++;
        if (evictionAttempts >= maxEvictionAttempts) return false;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    return true;
  }

  /// Creates a video controller for the given URL.
  ///
  /// Uses the injected factory for testing, or default implementation.
  Future<VideoPlayerController?> _createController({
    required String videoId,
    required String videoUrl,
    File? Function(String videoId)? getCachedFile,
  }) async {
    final cachedFile = getCachedFile?.call(videoId);

    if (_controllerFactory != null) {
      // Use injected factory (for testing)
      return _controllerFactory(videoUrl, cachedFile: cachedFile);
    }

    // coverage:ignore-start
    // Default implementation - requires real video files/network
    final controller = cachedFile != null
        ? VideoPlayerController.file(cachedFile)
        : VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    return controller;
    // coverage:ignore-end
  }

  /// Phase 1: Seek to beginning and pause for instant first frame display.
  Future<PooledController> _initializeForFirstFrame(
    VideoPlayerController controller,
    String videoId,
  ) async {
    try {
      await controller.seekTo(Duration.zero);
      await controller.pause();
    } on Exception {
      // Seek/pause may fail on some platforms - continue anyway
    }

    return PooledController(
      controller: controller,
      videoId: videoId,
      phase: ControllerPhase.firstFrame,
    );
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
      await _disposeAndRemoveController(id);
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

  // ══════════════════════════════════════════════════════════════════════════
  // TWO-PHASE INITIALIZATION
  // Phase 1: firstFrame - Seek to 0, pause (instant visual feedback)
  // Phase 2: buffered - Set playback speed to fill buffer (smooth playback)
  // ══════════════════════════════════════════════════════════════════════════

  /// Phase 2 of two-phase initialization: complete buffering for smooth
  /// playback.
  ///
  /// Called after the first frame is available. Triggers buffering by
  /// ensuring playback speed is set, then marks the controller as buffered.
  Future<void> _completeBufferingPhase(PooledController pooled) async {
    if (pooled.phase != ControllerPhase.firstFrame) return;
    if (!_isControllerValid(pooled.controller)) return;

    try {
      // Setting playback speed ensures the buffer starts filling
      await pooled.controller.setPlaybackSpeed(1);
      pooled.phase = ControllerPhase.buffered;
      _notifyListeners();
    } on Exception {
      // Buffering errors are non-fatal - first frame is still available
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISTANCE-AWARE EVICTION
  // Priority: Active (never) > Prewarmed > Cached, then by distance from
  // current. Videos furthest from scroll position are evicted first.
  // ══════════════════════════════════════════════════════════════════════════

  /// Distance-aware eviction: evict the video furthest from current position.
  ///
  /// Eviction priority:
  /// 1. Active video is never evicted
  /// 2. Prewarmed videos are protected but can be evicted if no other option
  /// 3. Among remaining videos, the one furthest from current scroll position
  ///    is evicted first
  Future<bool> _evictFurthestController() async {
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

    await _disposeAndRemoveController(victimId);
    return true;
  }

  /// Large distance for videos without registered indices.
  /// These should be prioritized for eviction over videos with known positions.
  static const int _unknownIndexDistance = 1000;

  int _getDistanceFromCurrent(String videoId) {
    final index = _videoIndexMap[videoId];
    if (index == null || _currentScrollIndex == null) {
      return _unknownIndexDistance;
    }
    return (index - _currentScrollIndex!).abs();
  }

  /// Disposes a controller and removes it from all tracking structures.
  ///
  /// Pauses playback if currently playing, disposes the controller,
  /// and removes from pool, LRU map, and prewarm set.
  Future<void> _disposeAndRemoveController(String videoId) async {
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
    _pendingAcquisitions.clear();
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
