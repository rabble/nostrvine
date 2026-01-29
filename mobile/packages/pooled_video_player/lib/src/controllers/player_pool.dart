import 'dart:async';
import 'dart:collection';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// A pooled player instance containing both Player and VideoController.
/// Keeps native resources alive for reuse instead of expensive recreation.
class PooledPlayer {
  /// Creates a pooled player with the given player and video controller.
  PooledPlayer({required this.player, required this.videoController})
    : lastUsed = DateTime.now();

  /// The underlying media player instance.
  final Player player;

  /// The video controller for rendering.
  final VideoController videoController;

  /// Timestamp of last usage for LRU eviction.
  DateTime lastUsed;

  /// Tracks whether this player has been disposed.
  /// Used to prevent operations on disposed native objects.
  bool isDisposed = false;

  /// Completer for coordinating operations. Null when no operation in progress.
  Completer<void>? _operationCompleter;

  /// Maximum time to wait for an operation to complete before forcing disposal.
  static const _operationTimeout = Duration(seconds: 5);

  /// Reset player state for reuse (keeps native resources intact).
  /// Uses stop() instead of dispose() to preserve the native player.
  Future<void> reset() async {
    if (isDisposed) return;

    // Wait for any pending operation
    await _waitForPendingOperation();

    // Check again after waiting
    if (isDisposed) return;

    _operationCompleter = Completer<void>();
    try {
      await player.stop();
      await player.setVolume(100);
      lastUsed = DateTime.now();
    } finally {
      _operationCompleter?.complete();
      _operationCompleter = null;
    }
  }

  /// Safely dispose the player with proper native callback cleanup.
  Future<void> safeDispose() async {
    if (isDisposed) return;

    // Wait for any ongoing operation with timeout
    await _waitForPendingOperation();

    // Prevent any new operations
    if (isDisposed) return;
    isDisposed = true;

    _operationCompleter = Completer<void>();

    try {
      // Stop playback first to halt native callback dispatching
      await player.stop();

      // Small delay to allow native callbacks to settle.
      // This prevents FFI callback crashes during disposal.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Now safe to dispose
      await player.dispose();
    } on Exception {
      // Ignore errors - player may already be partially disposed
    } finally {
      _operationCompleter?.complete();
      _operationCompleter = null;
    }
  }

  /// Wait for any pending operation with timeout.
  Future<void> _waitForPendingOperation() async {
    final completer = _operationCompleter;
    if (completer != null && !completer.isCompleted) {
      try {
        await completer.future.timeout(_operationTimeout);
      } on TimeoutException {
        // Operation timed out - proceed anyway to avoid deadlock
        // In production, consider logging this warning
      }
    }
  }
}

/// Object pool for Player instances to avoid expensive ~200ms recreation.
///
/// Instead of disposing players when scrolling away from videos, this pool
/// keeps a limited number of players available for immediate reuse.
class PlayerPool {
  /// Creates a player pool with the given configuration.
  PlayerPool({
    int maxPoolSize = 3,
    this.maxTotalPlayers = 7,
    int bufferSize = 32 * 1024 * 1024, // 32MB default
  }) : _maxPoolSize = maxPoolSize,
       _bufferSize = bufferSize;
  int _maxPoolSize;

  /// Maximum total players allowed (both in-use and pooled).
  final int maxTotalPlayers;
  final Queue<PooledPlayer> _available = Queue<PooledPlayer>();
  final Set<PooledPlayer> _inUse = {};

  // Buffer configuration optimized for short-form video
  final int _bufferSize;

  /// Tracks whether the pool is being disposed.
  bool _isDisposing = false;

  /// Tracks whether the pool has been disposed.
  bool _isDisposed = false;

  /// Current maximum pool size.
  int get maxPoolSize => _maxPoolSize;

  /// Update the maximum pool size dynamically.
  ///
  /// If the new size is smaller than the current available count,
  /// excess players will be disposed.
  Future<void> updatePoolSize(int newSize) async {
    _maxPoolSize = newSize;
    if (_available.length > newSize) {
      await shrinkTo(newSize);
    }
  }

  /// Total players currently managed (both in-use and available).
  int get totalPlayers => _available.length + _inUse.length;

  /// Number of available players in the pool.
  int get availableCount => _available.length;

  /// Number of players currently in use.
  int get inUseCount => _inUse.length;

  /// Acquire a player from the pool or create new if pool is empty.
  ///
  /// Returns an existing player from the pool (fast, <10ms) or creates
  /// a new one if the pool is empty (slow, ~200ms).
  ///
  /// Throws [StateError] if the pool is disposed or being disposed.
  Future<PooledPlayer> acquire() async {
    if (_isDisposed || _isDisposing) {
      throw StateError('Cannot acquire from disposed pool');
    }

    PooledPlayer pooledPlayer;

    if (_available.isNotEmpty) {
      // Reuse existing player from pool - fast path
      pooledPlayer = _available.removeFirst();
      await pooledPlayer.reset();
    } else if (totalPlayers < maxTotalPlayers) {
      // Create new player - slow path (~200ms)
      pooledPlayer = await _createPlayer();
    } else {
      // At capacity - this shouldn't happen with proper window management
      // but handle gracefully by reusing oldest available after force-release
      throw StateError(
        'Player pool exhausted. Max players: $maxTotalPlayers, '
        'in use: $inUseCount, available: $availableCount',
      );
    }

    _inUse.add(pooledPlayer);
    return pooledPlayer;
  }

  /// Release a player back to the pool for reuse.
  ///
  /// The player is reset (stopped, not disposed) and returned to the pool
  /// if there's room. Only disposes if the pool is already full.
  Future<void> release(PooledPlayer pooledPlayer) async {
    // Allow release during disposal to clean up properly
    if (_isDisposed) return;

    if (!_inUse.contains(pooledPlayer)) {
      return; // Already released or never acquired
    }

    _inUse.remove(pooledPlayer);

    // During disposal, just dispose the player directly
    if (_isDisposing) {
      await _disposePooledPlayer(pooledPlayer);
      return;
    }

    // Reset player state for reuse
    await pooledPlayer.reset();

    if (_available.length < maxPoolSize) {
      // Return to pool for reuse
      _available.addLast(pooledPlayer);
    } else {
      // Pool is full - dispose excess player
      await _disposePooledPlayer(pooledPlayer);
    }
  }

  /// Pre-warm the pool with ready-to-use players.
  ///
  /// Call during app startup or idle time to avoid creation latency
  /// during scrolling.
  Future<void> prewarm(int count) async {
    if (_isDisposed || _isDisposing) return;

    final toCreate = (count - totalPlayers).clamp(
      0,
      maxPoolSize - _available.length,
    );

    for (var i = 0; i < toCreate; i++) {
      if (_isDisposed || _isDisposing) return;
      if (totalPlayers < maxTotalPlayers) {
        final player = await _createPlayer();
        _available.addLast(player);
      }
    }
  }

  /// Shrink pool to specified size (for memory pressure situations).
  ///
  /// Disposes excess available players to free memory.
  Future<void> shrinkTo(int targetAvailable) async {
    if (_isDisposed) return;

    while (_available.length > targetAvailable) {
      final player = _available.removeLast();
      await _disposePooledPlayer(player);
    }
  }

  /// Release all players and clear the pool.
  ///
  /// Call when the controller is being disposed.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposing = true;

    // Copy collections to avoid modification during iteration
    final availablePlayers = _available.toList();
    final inUsePlayers = _inUse.toList();

    _available.clear();
    _inUse.clear();

    // Dispose all available players sequentially
    for (final pooledPlayer in availablePlayers) {
      await _disposePooledPlayer(pooledPlayer);
    }

    // Dispose all in-use players sequentially
    for (final pooledPlayer in inUsePlayers) {
      await _disposePooledPlayer(pooledPlayer);
    }

    _isDisposing = false;
    _isDisposed = true;
  }

  Future<PooledPlayer> _createPlayer() async {
    final player = Player(
      configuration: PlayerConfiguration(bufferSize: _bufferSize),
    );

    final videoController = VideoController(player);

    return PooledPlayer(player: player, videoController: videoController);
  }

  Future<void> _disposePooledPlayer(PooledPlayer pooledPlayer) async {
    if (pooledPlayer.isDisposed) return;
    // Use safeDispose which handles proper native callback cleanup
    await pooledPlayer.safeDispose();
  }
}
