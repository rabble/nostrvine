import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/models/video_pool_config.dart';

/// A pooled player instance containing both Player and VideoController.
///
/// Keeps native resources alive for reuse instead of expensive recreation.
class PooledPlayer {
  /// Creates a pooled player with the given player and video controller.
  PooledPlayer({required this.player, required this.videoController});

  /// The underlying media player instance.
  final Player player;

  /// The video controller for rendering.
  final VideoController videoController;

  /// Tracks whether this player has been disposed.
  bool _isDisposed = false;

  /// Whether this player has been disposed.
  bool get isDisposed => _isDisposed;

  /// Safely dispose the player.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      await player.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await player.dispose();
    } on Exception {
      // Ignore errors - player may already be disposed
    }
  }
}

/// URL-keyed pool of video players with LRU eviction.
///
/// Players are cached by URL for efficient reuse. When the pool reaches
/// capacity, the least recently used player is evicted.
///
/// ## Singleton Usage
///
/// Initialize once at app startup:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   MediaKit.ensureInitialized();
///
///   await PlayerPool.init(config: VideoPoolConfig(maxPlayers: 5));
///
///   runApp(MyApp());
/// }
/// ```
///
/// Access anywhere via the singleton:
/// ```dart
/// final pool = PlayerPool.instance;
/// final player = await pool.getPlayer(videoUrl);
/// ```
///
/// ## Manual Instantiation (for testing or multiple pools)
///
/// ```dart
/// final customPool = PlayerPool(maxPlayers: 3);
/// ```
class PlayerPool {
  /// Creates a player pool with the given maximum size.
  ///
  /// Use this constructor when you need a separate pool instance
  /// (e.g., for testing or multiple isolated pools).
  ///
  /// For most use cases, prefer the singleton via [init] and [instance].
  PlayerPool({this.maxPlayers = 5});

  /// Private constructor for singleton initialization.
  PlayerPool._({this.maxPlayers = 5});

  // ============================================
  // Singleton Pattern
  // ============================================

  static PlayerPool? _instance;

  /// Returns the singleton instance.
  ///
  /// Throws [StateError] if [init] has not been called.
  static PlayerPool get instance {
    if (_instance == null) {
      throw StateError(
        'PlayerPool not initialized. '
        'Call PlayerPool.init() at app startup.',
      );
    }
    return _instance!;
  }

  /// Returns true if the singleton has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initializes the singleton with the given configuration.
  ///
  /// Should be called once at app startup, after
  /// `MediaKit.ensureInitialized()`.
  ///
  /// If called when already initialized, the existing instance is disposed
  /// and a new one is created.
  ///
  /// Example:
  /// ```dart
  /// await PlayerPool.init(config: VideoPoolConfig(maxPlayers: 5));
  /// // or with defaults:
  /// await PlayerPool.init();
  /// ```
  static Future<void> init({
    VideoPoolConfig config = const VideoPoolConfig(),
  }) async {
    // Dispose existing instance if re-initializing
    if (_instance != null) {
      await _instance!.dispose();
      _instance = null;
    }

    _instance = PlayerPool._(maxPlayers: config.maxPlayers);
  }

  /// Resets the singleton, disposing all players.
  ///
  /// After calling this, [isInitialized] returns false and [instance] throws.
  /// Useful for cleanup on app shutdown or in tests.
  static Future<void> reset() async {
    await _instance?.dispose();
    _instance = null;
  }

  /// Returns the current singleton instance for testing.
  @visibleForTesting
  static PlayerPool? get instanceForTesting => _instance;

  /// Replaces the singleton instance for testing.
  ///
  /// Allows injecting a mock or custom pool in tests.
  /// The previous instance is NOT disposed - caller is responsible.
  @visibleForTesting
  static set instanceForTesting(PlayerPool? pool) {
    _instance = pool;
  }

  // ============================================
  // Instance Members
  // ============================================

  /// Maximum number of players to keep in the pool.
  final int maxPlayers;

  /// Players keyed by URL.
  final Map<String, PooledPlayer> _players = {};

  /// LRU order - most recently used at the end.
  final List<String> _lruOrder = [];

  /// Whether the pool has been disposed.
  bool _isDisposed = false;

  /// Number of players currently in the pool.
  int get playerCount => _players.length;

  /// Get or create a player for the given URL.
  ///
  /// If a player already exists for this URL, it is returned and marked
  /// as recently used. Otherwise, a new player is created. If the pool
  /// is at capacity, the least recently used player is evicted first.
  Future<PooledPlayer> getPlayer(String url) async {
    if (_isDisposed) {
      throw StateError('PlayerPool has been disposed');
    }

    // Check if player already exists
    if (_players.containsKey(url)) {
      _touch(url);
      return _players[url]!;
    }

    // Evict if at capacity
    while (_players.length >= maxPlayers && _lruOrder.isNotEmpty) {
      await _evictLru();
    }

    // Create new player
    final player = await _createPlayer();
    _players[url] = player;
    _lruOrder.add(url);

    return player;
  }

  /// Check if a player exists for the given URL.
  bool hasPlayer(String url) => _players.containsKey(url);

  /// Get existing player for URL without creating new one.
  PooledPlayer? getExistingPlayer(String url) {
    if (_players.containsKey(url)) {
      _touch(url);
      return _players[url];
    }
    return null;
  }

  /// Mark a URL as recently used.
  void _touch(String url) {
    _lruOrder
      ..remove(url)
      ..add(url);
  }

  /// Evict the least recently used player.
  Future<void> _evictLru() async {
    if (_lruOrder.isEmpty) return;

    final url = _lruOrder.removeAt(0);
    final player = _players.remove(url);
    if (player != null && !player.isDisposed) {
      await player.dispose();
    }
  }

  /// Release a specific URL from the pool.
  Future<void> release(String url) async {
    final player = _players.remove(url);
    _lruOrder.remove(url);
    if (player != null && !player.isDisposed) {
      await player.dispose();
    }
  }

  /// Stop all active player playback without disposing.
  ///
  /// Used during hot reload to prevent native mpv callbacks from firing
  /// on invalidated Dart FFI handles, which causes a fatal crash:
  /// "Callback invoked after it has been deleted."
  void stopAll() {
    for (final player in _players.values) {
      if (!player.isDisposed) {
        try {
          unawaited(player.player.stop());
        } on Exception {
          // Ignore errors during emergency stop
        }
      }
    }
  }

  /// Dispose all players and clear the pool.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    final players = _players.values.toList();
    _players.clear();
    _lruOrder.clear();

    for (final player in players) {
      if (!player.isDisposed) {
        await player.dispose();
      }
    }
  }

  Future<PooledPlayer> _createPlayer() async {
    final player = Player();
    final videoController = VideoController(player);
    return PooledPlayer(player: player, videoController: videoController);
  }
}
