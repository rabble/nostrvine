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

  /// Set to `true` by [recycle] to indicate this player was re-keyed from
  /// a previous URL.
  ///
  /// Callers use this to defer publishing the [VideoController] to the UI
  /// until after new media has been opened, preventing the previous video's
  /// surface from flashing on the new index even after `stop()` has cleared it.
  ///
  /// Reset to `false` automatically once the caller has consumed it.
  bool _wasRecycled = false;

  /// Whether this player was recycled from another URL since the last open.
  ///
  /// Callers must reset this to `false` once they have deferred UI exposure
  /// past the `open()` call.
  bool get wasRecycled => _wasRecycled;

  /// Resets the [wasRecycled] flag. Called after `open()` completes for a
  /// recycled player.
  void clearRecycled() => _wasRecycled = false;

  /// Callbacks invoked synchronously when this player is evicted (recycled
  /// or disposed).
  ///
  /// Used by `VideoFeedController` to detect pool eviction and update
  /// the widget tree before Flutter rebuilds with a stale controller.
  final List<VoidCallback> _onEvictedCallbacks = [];

  /// Registers a callback to be invoked when this player is evicted.
  void addOnEvictedCallback(VoidCallback callback) {
    _onEvictedCallbacks.add(callback);
  }

  /// Removes a previously registered eviction callback.
  void removeOnEvictedCallback(VoidCallback callback) {
    _onEvictedCallbacks.remove(callback);
  }

  /// Fires all eviction callbacks and clears them without touching native
  /// resources.
  ///
  /// Called by [PlayerPool] when this player is recycled under a new URL.
  /// Consumers (e.g. `VideoFeedController`) react identically to a real
  /// disposal — they null-out widget state — but the underlying [Player] and
  /// [VideoController] remain valid for immediate reuse.
  ///
  /// Is a no-op if already disposed.
  void recycle() {
    if (_isDisposed) return;
    _wasRecycled = true;
    for (final callback in List<VoidCallback>.of(_onEvictedCallbacks)) {
      callback();
    }
    _onEvictedCallbacks.clear();
  }

  /// Safely dispose the player.
  ///
  /// Invokes all registered [_onEvictedCallbacks] synchronously before
  /// disposing native resources, allowing consumers to react (e.g., update
  /// widget state) before the underlying [VideoController] becomes invalid.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Notify listeners synchronously so they can update UI state before
    // native resources (including VideoController's ValueNotifier<int?>)
    // are torn down.
    for (final callback in List<VoidCallback>.of(_onEvictedCallbacks)) {
      callback();
    }
    _onEvictedCallbacks.clear();

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

  /// Lock to serialize concurrent [getPlayer] calls and prevent
  /// over-eviction when multiple callers see the pool at capacity.
  Completer<void>? _operationLock;

  /// Waits for any in-flight [getPlayer] operation to complete.
  ///
  /// Call this in test teardowns before iterating shared state that the
  /// mock player factory writes to, to avoid concurrent modification errors
  /// caused by in-flight lock completions firing after the test body returns.
  @visibleForTesting
  Future<void> drainPendingOperations() async {
    while (_operationLock != null) {
      await _operationLock!.future;
    }
  }

  /// Number of players currently in the pool.
  int get playerCount => _players.length;

  /// Get or create a player for the given URL.
  ///
  /// If a player already exists for this URL, it is returned and marked
  /// as recently used. Otherwise, a new player is created. If the pool
  /// is at capacity, the least recently used player is evicted first.
  ///
  /// Concurrent calls are serialized to prevent multiple callers from
  /// seeing the pool at capacity and each triggering independent evictions.
  Future<PooledPlayer> getPlayer(String url) async {
    // Wait for any in-flight operation to complete.
    while (_operationLock != null) {
      await _operationLock!.future;
    }
    _operationLock = Completer<void>();
    try {
      return await _getPlayerInternal(url);
    } finally {
      final lock = _operationLock;
      _operationLock = null;
      lock?.complete();
    }
  }

  /// Performs the actual pool lookup and eviction logic without the
  /// concurrency lock.
  ///
  /// Exposed so test subclasses can bypass the [Completer]-based lock when
  /// they need deterministic, synchronous-equivalent behaviour without
  /// racing against teardown operations.
  @visibleForTesting
  @visibleForOverriding
  Future<PooledPlayer> getPlayerInternal(String url) => _getPlayerInternal(url);

  Future<PooledPlayer> _getPlayerInternal(String url) async {
    if (_isDisposed) {
      throw StateError('PlayerPool has been disposed');
    }

    // Check if player already exists
    if (_players.containsKey(url)) {
      _touch(url);
      final existing = _players[url]!;
      // Reset audio state to prevent leaking audio from a previous session.
      // The caller (_loadPlayer) will set volume/play state as needed.
      // Use unawaited to avoid introducing a yield point that could allow
      // concurrent getPlayer calls to interleave and cause race conditions.
      unawaited(existing.player.setVolume(0));
      return existing;
    }

    // Recycle or evict LRU players until there is room.
    PooledPlayer? recycled;
    while (_players.length >= maxPlayers && _lruOrder.isNotEmpty) {
      recycled = await _recycleLru();
      if (recycled != null) break; // Got a reusable player — stop evicting.
    }

    if (recycled != null) {
      // Re-key the recycled player under the new URL and return it directly,
      // avoiding a native player allocation entirely.
      _players[url] = recycled;
      _lruOrder.add(url);
      return recycled;
    }

    // No reusable player found (all LRU entries were already disposed) —
    // fall back to allocating a new native player.
    final player = await createPlayerForUrl(url);
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

  /// Removes the LRU entry, fires its eviction callbacks, awaits
  /// `player.stop()`, and returns the player for reuse.
  ///
  /// Returns `null` if the LRU order is empty or the player is already
  /// disposed. In that case the caller must fall back to [createPlayer].
  ///
  /// Awaiting `player.stop()` before returning provides a hard ordering
  /// guarantee: the previous video's media surface is fully cleared before
  /// [getPlayer] resolves, so callers can safely expose the recycled
  /// [VideoController] to the UI without risk of stale content.
  Future<PooledPlayer?> _recycleLru() async {
    if (_lruOrder.isEmpty) return null;

    final url = _lruOrder.removeAt(0);
    final player = _players.remove(url);
    if (player == null || player.isDisposed) return null;
    player.recycle();
    // Await stop() so the surface is cleared before this player is returned
    // to _loadPlayer(), stored in _loadedPlayers, and exposed via _notifyIndex.
    try {
      await player.player.stop();
    } on Exception {
      // Ignore — mirrors the same pattern in dispose().
    }
    return player;
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

  /// Release all cached players while keeping the pool reusable.
  ///
  /// Used when the app fully deactivates so native media resources do not
  /// remain open while iOS is suspending the process.
  Future<void> releaseAll() async {
    final players = _players.values.toList();
    _players.clear();
    _lruOrder.clear();

    for (final player in players) {
      if (!player.isDisposed) {
        await player.dispose();
      }
    }
  }

  /// Dispose all players and clear the pool.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await releaseAll();
  }

  /// Creates a new [PooledPlayer] for [url].
  ///
  /// The default implementation ignores [url] and delegates to
  /// [createPlayer]. Override in tests when you need URL-aware player
  /// creation (e.g., to return a specific mock for a given URL) without
  /// duplicating the pool's LRU and recycle logic.
  @visibleForTesting
  @visibleForOverriding
  Future<PooledPlayer> createPlayerForUrl(String url) => createPlayer();

  /// Creates a new [PooledPlayer] with native media resources.
  ///
  /// Override in tests to return mock players without creating native
  /// resources.
  @visibleForTesting
  @visibleForOverriding
  Future<PooledPlayer> createPlayer() async {
    final player = Player();

    // Suppress FFmpeg codec warnings (e.g. smpte170m color transfer) that
    // bypass MPV's API log callback and go directly to stderr. Skip on web,
    // and use dynamic dispatch so Dart2JS does not type-check the missing
    // setProperty member on the web NativePlayer stub.
    if (!kIsWeb) {
      try {
        final nativePlayer = player.platform;
        if (nativePlayer is NativePlayer) {
          await (nativePlayer as dynamic).setProperty('msg-level', 'all=error');
          // Start playback immediately without waiting for the cache to fill.
          // Without this, fragmented MP4 (fMP4) takes ~3s to start because
          // mpv parses all moof/mdat fragments before declaring cache ready.
          await (nativePlayer as dynamic).setProperty(
            'cache-pause-initial',
            '0',
          );
        }
      } on Object catch (_) {
        // Ignore — some platforms or stubs don't support setProperty.
      }
    }

    final videoController = VideoController(player);
    return PooledPlayer(player: player, videoController: videoController);
  }
}
