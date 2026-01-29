import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'package:pooled_video_player/src/constants/pool_constants.dart';
import 'package:pooled_video_player/src/controllers/memory_pressure_handler.dart';
import 'package:pooled_video_player/src/controllers/player_pool.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/player_lease.dart';
import 'package:pooled_video_player/src/models/pool_status.dart';
import 'package:pooled_video_player/src/models/video_pool_config.dart';
import 'package:pooled_video_player/src/utils/device_memory_util.dart';

/// Factory for creating PlayerPool instances.
@visibleForTesting
typedef PlayerPoolFactory = PlayerPool Function(VideoPoolConfig config);

/// Global singleton that manages the shared [PlayerPool].
///
/// Coordinates resource allocation across all video feeds, handles memory
/// pressure, and manages [PlayerLease] transfers between contexts (e.g.,
/// from a feed to a detail page).
///
/// Example usage:
/// ```dart
/// // Initialize once at app startup
/// await PlayerPoolManager.initialize();
///
/// // Access the singleton instance
/// final manager = PlayerPoolManager.instance;
///
/// // Clean up when done
/// await PlayerPoolManager.reset();
/// ```
class PlayerPoolManager extends ChangeNotifier with MemoryPressureHandler {
  /// Private constructor for singleton pattern.
  PlayerPoolManager._({
    required this.config,
    PlayerPoolFactory? playerPoolFactory,
  }) {
    _playerPool =
        playerPoolFactory?.call(config) ??
        PlayerPool(
          maxPoolSize: config.poolSize,
          maxTotalPlayers: config.maxActivePlayers,
        );
    initMemoryPressureHandling();
  }

  // ============================================
  // Singleton Pattern
  // ============================================

  static PlayerPoolManager? _instance;

  /// Returns the singleton instance.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  static PlayerPoolManager get instance {
    if (_instance == null) {
      throw StateError(
        'PlayerPoolManager not initialized. '
        'Call PlayerPoolManager.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Returns true if the singleton has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initializes the singleton with the given configuration.
  ///
  /// If configuration values are not provided, they will be auto-detected
  /// based on the device's memory tier.
  ///
  /// If an instance already exists, it will be disposed before creating
  /// a new one.
  static Future<PlayerPoolManager> initialize({
    int? poolSize,
    int? preloadAhead,
    int? preloadBehind,
    int? maxActivePlayers,
    DeviceMemoryUtil? memoryClassifier,
    @visibleForTesting PlayerPoolFactory? playerPoolFactory,
    @visibleForTesting bool skipMediaKitInit = false,
  }) async {
    // Initialize MediaKit - safe to call multiple times (idempotent)
    if (!skipMediaKitInit) {
      MediaKit.ensureInitialized();
    }

    // Dispose existing instance if any
    if (_instance != null) {
      await _instance!._dispose();
      _instance = null;
    }

    final classifier = memoryClassifier ?? DeviceMemoryUtil();
    final tier = await classifier.getMemoryTier();

    final effectiveConfig = VideoPoolConfig(
      poolSize: poolSize ?? _getPoolSizeForTier(tier),
      preloadAhead: preloadAhead ?? _getPreloadAheadForTier(tier),
      preloadBehind: preloadBehind ?? _getPreloadBehindForTier(tier),
      maxActivePlayers: maxActivePlayers ?? _getMaxActivePlayersForTier(tier),
    );

    _instance = PlayerPoolManager._(
      config: effectiveConfig,
      playerPoolFactory: playerPoolFactory,
    );

    // Prewarm the pool
    unawaited(_instance!._playerPool.prewarm(2));

    return _instance!;
  }

  /// Resets the singleton, disposing the current instance.
  ///
  /// After calling this, [isInitialized] will return false and
  /// [instance] will throw until [initialize] is called again.
  static Future<void> reset() async {
    await _instance?._dispose();
    _instance = null;
  }

  // ============================================
  // Tier Configuration Helpers
  // ============================================

  static int _getPoolSizeForTier(MemoryTier tier) => switch (tier) {
    MemoryTier.low => MemoryTierConfig.lowMemoryPoolSize,
    MemoryTier.medium => MemoryTierConfig.mediumMemoryPoolSize,
    MemoryTier.high => MemoryTierConfig.highMemoryPoolSize,
  };

  static int _getPreloadAheadForTier(MemoryTier tier) => switch (tier) {
    MemoryTier.low => MemoryTierConfig.lowMemoryPreloadAhead,
    MemoryTier.medium => MemoryTierConfig.mediumMemoryPreloadAhead,
    MemoryTier.high => MemoryTierConfig.highMemoryPreloadAhead,
  };

  static int _getPreloadBehindForTier(MemoryTier tier) => switch (tier) {
    MemoryTier.low => MemoryTierConfig.lowMemoryPreloadBehind,
    MemoryTier.medium => MemoryTierConfig.mediumMemoryPreloadBehind,
    MemoryTier.high => MemoryTierConfig.highMemoryPreloadBehind,
  };

  static int _getMaxActivePlayersForTier(MemoryTier tier) => switch (tier) {
    MemoryTier.low => MemoryTierConfig.lowMemoryMaxActivePlayers,
    MemoryTier.medium => MemoryTierConfig.mediumMemoryMaxActivePlayers,
    MemoryTier.high => MemoryTierConfig.highMemoryMaxActivePlayers,
  };

  // ============================================
  // Instance Members
  // ============================================

  /// Configuration for preloading and pooling behavior.
  final VideoPoolConfig config;

  /// The shared player pool.
  late final PlayerPool _playerPool;

  /// All registered feed controllers.
  final Set<VideoFeedController> _registeredFeeds = {};

  /// Active leases by unique key (ownerId:videoId).
  final Map<String, PlayerLease> _activeLeases = {};

  /// Track disposal state.
  bool _isDisposed = false;

  /// Lock for serializing acquire operations to prevent race conditions.
  Completer<void>? _pendingAcquire;

  /// Lock for memory pressure handling to ensure cleanup completes
  /// before new acquire operations proceed.
  Completer<void>? _memoryPressureLock;

  // ============================================
  // Feed Registration
  // ============================================

  /// Register a feed controller to participate in shared pool management.
  void registerFeed(VideoFeedController feed) {
    _registeredFeeds.add(feed);
  }

  /// Unregister a feed controller (e.g., when disposed).
  void unregisterFeed(VideoFeedController feed) {
    _registeredFeeds.remove(feed);
  }

  /// Get all registered feeds.
  Set<VideoFeedController> get registeredFeeds =>
      Set.unmodifiable(_registeredFeeds);

  // ============================================
  // Player Acquisition & Lease Management
  // ============================================

  /// Get total active players across all feeds.
  int get totalActivePlayers => _activeLeases.length;

  /// Check if we can acquire more players.
  bool get canAcquireMore => totalActivePlayers < config.maxActivePlayers;

  /// Acquire a player for a specific video.
  ///
  /// Returns a [PlayerLease] that can be transferred between contexts.
  /// If the pool is exhausted and no eviction is possible, throws [StateError].
  ///
  /// This method is serialized to prevent race conditions between concurrent
  /// acquire requests (e.g., when eviction frees a slot that another caller
  /// could claim before the original requester).
  Future<PlayerLease> acquirePlayer({
    required String videoId,
    required String ownerId,
    int priority = PlayerPriority.distant,
  }) async {
    if (_isDisposed) {
      throw StateError('PlayerPoolManager has been disposed');
    }

    // Wait for memory pressure handling to complete before acquiring
    if (_memoryPressureLock != null) {
      await _memoryPressureLock!.future;
    }

    final leaseKey = '$ownerId:$videoId';

    // Check if we already have a lease for this video from this owner
    if (_activeLeases.containsKey(leaseKey)) {
      return _activeLeases[leaseKey]!;
    }

    // Serialize acquire operations to prevent race conditions
    while (_pendingAcquire != null) {
      await _pendingAcquire!.future;
    }
    _pendingAcquire = Completer<void>();

    try {
      // Double-check after acquiring lock (another caller may have created it)
      if (_activeLeases.containsKey(leaseKey)) {
        return _activeLeases[leaseKey]!;
      }

      // Atomic: check capacity, evict if needed, then acquire
      if (!canAcquireMore) {
        final evicted = await requestEviction(
          requesterPriority: priority,
          requesterId: ownerId,
        );
        if (!evicted) {
          throw StateError(
            'Cannot acquire player: pool exhausted and no evictable leases. '
            'Total: $totalActivePlayers, max: ${config.maxActivePlayers}',
          );
        }
      }

      final pooledPlayer = await _playerPool.acquire();

      if (_isDisposed) {
        await _playerPool.release(pooledPlayer);
        throw StateError('PlayerPoolManager was disposed during acquisition');
      }

      final lease = PlayerLease(
        pooledPlayer: pooledPlayer,
        videoId: videoId,
        ownerId: ownerId,
        priority: priority,
      );

      _activeLeases[leaseKey] = lease;
      notifyListeners();

      return lease;
    } finally {
      _pendingAcquire?.complete();
      _pendingAcquire = null;
    }
  }

  /// Transfer a lease to a new owner.
  ///
  /// Used during handoff from feed to detail page or vice versa.
  void transferLease({
    required PlayerLease lease,
    required String newOwnerId,
  }) {
    if (_isDisposed) return;

    final oldKey = '${lease.ownerId}:${lease.videoId}';
    final newKey = '$newOwnerId:${lease.videoId}';

    // Remove from old location
    _activeLeases.remove(oldKey);

    // Update lease ownership
    lease.transferTo(newOwnerId);

    // Add to new location
    _activeLeases[newKey] = lease;

    notifyListeners();
  }

  /// Release a player lease back to the pool.
  Future<void> releaseLease(PlayerLease lease) async {
    if (_isDisposed) return;

    final leaseKey = '${lease.ownerId}:${lease.videoId}';
    _activeLeases.remove(leaseKey);

    if (lease.isValid) {
      await _playerPool.release(lease.pooledPlayer);
    }

    notifyListeners();
  }

  /// Get a lease by owner and video ID.
  PlayerLease? getLease(String ownerId, String videoId) {
    return _activeLeases['$ownerId:$videoId'];
  }

  /// Get all leases for a specific owner.
  List<PlayerLease> getLeasesForOwner(String ownerId) {
    return _activeLeases.values
        .where((lease) => lease.ownerId == ownerId)
        .toList();
  }

  // ============================================
  // Eviction
  // ============================================

  /// Request eviction of a lower-importance lease to make room.
  ///
  /// Priority numbers: lower = more important (0=current, 30=distant).
  /// We evict the lease with the HIGHEST number (least important).
  /// Returns true if eviction succeeded, false if no suitable lease found.
  Future<bool> requestEviction({
    required int requesterPriority,
    required String requesterId,
  }) async {
    if (canAcquireMore) return true; // No eviction needed

    // Find the least important lease (highest priority NUMBER)
    // that has lower importance than the requester
    PlayerLease? leaseToEvict;
    var highestEvictablePriority = requesterPriority;

    for (final lease in _activeLeases.values) {
      // Never evict the requester's own leases
      if (lease.ownerId == requesterId) continue;

      // Never evict current video of any feed
      if (_isCurrentForAnyFeed(lease)) continue;

      // Higher number = less important = better eviction candidate
      if (lease.priority > highestEvictablePriority) {
        highestEvictablePriority = lease.priority;
        leaseToEvict = lease;
      }
    }

    if (leaseToEvict != null) {
      await releaseLease(leaseToEvict);
      return true;
    }

    return false; // Cannot evict - all leases are more important
  }

  /// Check if a lease is for the current video of any registered feed.
  bool _isCurrentForAnyFeed(PlayerLease lease) {
    for (final feed in _registeredFeeds) {
      if (feed.feedId == lease.ownerId) {
        final currentIndex = feed.currentIndex;
        if (currentIndex >= 0 && currentIndex < feed.videos.length) {
          final currentVideo = feed.videos[currentIndex];
          if (currentVideo.id == lease.videoId) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // ============================================
  // Memory Pressure
  // ============================================

  @override
  void onMemoryPressure() {
    // Skip if already handling memory pressure
    if (_memoryPressureLock != null) return;

    // Set lock so acquirePlayer waits for cleanup to complete
    _memoryPressureLock = Completer<void>();

    // Run async cleanup and release lock when done
    unawaited(
      _handleMemoryPressureAsync().whenComplete(() {
        _memoryPressureLock?.complete();
        _memoryPressureLock = null;
      }),
    );
  }

  Future<void> _handleMemoryPressureAsync() async {
    // 1. Notify all feeds to reduce their footprint
    for (final feed in _registeredFeeds) {
      feed.onMemoryPressure();
    }

    // 2. Evict all non-essential leases
    final toEvict =
        _activeLeases.values
            .where((lease) => lease.priority > PlayerPriority.current)
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority)); // Highest first

    // Release sequentially to avoid concurrent disposal issues
    for (final lease in toEvict) {
      if (totalActivePlayers <= 3) break; // Keep minimum
      try {
        await releaseLease(lease);
      } on Exception {
        // Ignore errors during memory pressure cleanup
      }
    }

    // 3. Shrink the available pool
    await _playerPool.shrinkTo(1);
  }

  // ============================================
  // Pool Access (for advanced usage)
  // ============================================

  /// Get the current pool size.
  int get poolSize => _playerPool.maxPoolSize;

  /// Get the number of available players in the pool.
  int get availablePlayersCount => _playerPool.availableCount;

  /// Get the number of players in use.
  int get inUsePlayersCount => _playerPool.inUseCount;

  /// Get current pool status for monitoring and debugging.
  ///
  /// Returns an immutable snapshot of the pool's current state.
  PoolStatus get status => PoolStatus(
    availablePlayers: _playerPool.availableCount,
    inUsePlayers: _playerPool.inUseCount,
    totalPlayers: _playerPool.totalPlayers,
    maxPoolSize: _playerPool.maxPoolSize,
    maxTotalPlayers: _playerPool.maxTotalPlayers,
    activeLeaseCount: _activeLeases.length,
    registeredFeedCount: _registeredFeeds.length,
    isMemoryConstrained: isMemoryConstrained,
  );

  // ============================================
  // Lifecycle
  // ============================================

  /// Internal dispose method. Use [reset] to dispose the singleton.
  Future<void> _dispose() async {
    _isDisposed = true;

    disposeMemoryPressureHandling();

    // Clear all leases
    _activeLeases.clear();

    // Clear registered feeds
    _registeredFeeds.clear();

    // Dispose the pool
    await _playerPool.dispose();

    super.dispose();
  }
}
