import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pooled_video_player/src/controllers/player_pool.dart';
import 'package:pooled_video_player/src/models/video_index_state.dart';
import 'package:pooled_video_player/src/models/video_item.dart';
import 'package:pooled_video_player/src/models/video_pool_config.dart';

/// State of video loading for a specific index.
enum LoadState {
  /// Not yet loaded.
  none,

  /// Currently loading/buffering.
  loading,

  /// Ready for playback.
  ready,

  /// An error occurred.
  error,
}

/// Controller for a video feed with automatic preloading.
///
/// Manages video playback and preloads adjacent videos for smooth scrolling.
/// Supports multiple feeds with `setActive()` for pausing background feeds.
class VideoFeedController extends ChangeNotifier {
  /// Creates a video feed controller.
  ///
  /// If [pool] is not provided, uses [PlayerPool.instance].
  /// This allows easy usage with the singleton while still supporting
  /// custom pools for testing.
  ///
  /// [initialIndex] sets the starting video index for preloading.
  /// Defaults to 0.
  VideoFeedController({
    required List<VideoItem> videos,
    PlayerPool? pool,
    int initialIndex = 0,
    this.preloadAhead = 2,
    this.preloadBehind = 1,
    this.mediaSourceResolver,
    this.onVideoReady,
    this.positionCallback,
    this.positionCallbackInterval = const Duration(milliseconds: 250),
  }) : pool = pool ?? PlayerPool.instance,
       _videos = List.from(videos),
       _currentIndex = initialIndex.clamp(
         0,
         videos.isEmpty ? 0 : videos.length - 1,
       ) {
    _initialize();
  }

  /// The shared player pool (singleton by default).
  final PlayerPool pool;

  /// Videos in this feed.
  final List<VideoItem> _videos;

  /// Number of videos to preload ahead of current.
  final int preloadAhead;

  /// Number of videos to preload behind current.
  final int preloadBehind;

  /// Hook: Resolve video URL to actual media source (file path or URL).
  ///
  /// Used for cache integration — return a cached file path if available,
  /// or `null` to use the original [VideoItem.url].
  final MediaSourceResolver? mediaSourceResolver;

  /// Hook: Called when a video is ready to play.
  ///
  /// Used for triggering background caching, analytics, etc.
  final VideoReadyCallback? onVideoReady;

  /// Hook: Called periodically with position updates.
  ///
  /// Used for loop enforcement, progress tracking, etc.
  /// The interval is controlled by [positionCallbackInterval].
  final PositionCallback? positionCallback;

  /// Interval for [positionCallback] invocations.
  ///
  /// Defaults to 200ms.
  final Duration positionCallbackInterval;

  /// Unmodifiable list of videos.
  List<VideoItem> get videos => List.unmodifiable(_videos);

  /// Number of videos.
  int get videoCount => _videos.length;

  // State
  int _currentIndex;
  bool _isActive = true;
  bool _isPaused = false;
  bool _isDisposed = false;

  // Loaded players by index
  final Map<int, PooledPlayer> _loadedPlayers = {};
  final Map<int, LoadState> _loadStates = {};
  final Map<int, StreamSubscription<bool>> _bufferSubscriptions = {};
  final Set<int> _loadingIndices = {};
  final Map<int, Timer> _positionTimers = {};

  // Index-specific notifiers for granular widget updates
  final Map<int, ValueNotifier<VideoIndexState>> _indexNotifiers = {};

  /// Currently visible video index.
  int get currentIndex => _currentIndex;

  /// Whether playback is paused.
  bool get isPaused => _isPaused;

  /// Whether this feed is active.
  bool get isActive => _isActive;

  /// Get the video controller for rendering at the given index.
  VideoController? getVideoController(int index) =>
      _loadedPlayers[index]?.videoController;

  /// Get the player for the given index.
  Player? getPlayer(int index) => _loadedPlayers[index]?.player;

  /// Get the load state for the given index.
  LoadState getLoadState(int index) => _loadStates[index] ?? LoadState.none;

  /// Whether the video at the given index is ready.
  bool isVideoReady(int index) => _loadStates[index] == LoadState.ready;

  /// Get a [ValueNotifier] for the state of a specific video index.
  ///
  /// This allows widgets to listen only to changes for their specific index,
  /// avoiding unnecessary rebuilds when other videos states change.
  ///
  /// The notifier is created lazily and cached for the lifetime of the
  /// controller.
  ValueNotifier<VideoIndexState> getIndexNotifier(int index) {
    return _indexNotifiers.putIfAbsent(
      index,
      () => ValueNotifier(
        VideoIndexState(
          loadState: _loadStates[index] ?? LoadState.none,
          videoController: _loadedPlayers[index]?.videoController,
          player: _loadedPlayers[index]?.player,
        ),
      ),
    );
  }

  /// Notifies the specific index's notifier of state changes.
  ///
  /// If the [PooledPlayer] for this index has been disposed (e.g. by pool
  /// eviction), the state reports null controller/player to prevent the
  /// [Video] widget from accessing disposed native resources.
  void _notifyIndex(int index) {
    if (_isDisposed) return;
    final notifier = _indexNotifiers[index];
    if (notifier != null) {
      final pooledPlayer = _loadedPlayers[index];
      // A player that exists but was disposed (e.g. pool eviction) should
      // report LoadState.none so the UI shows the placeholder, not a stale
      // Video widget referencing disposed native resources.  When no player
      // exists at all (error path, or not yet loaded), honour the stored
      // _loadStates value so LoadState.error propagates correctly.
      final isEvicted = pooledPlayer != null && pooledPlayer.isDisposed;
      final isAlive = pooledPlayer != null && !pooledPlayer.isDisposed;
      notifier.value = VideoIndexState(
        loadState: isEvicted
            ? LoadState.none
            : (_loadStates[index] ?? LoadState.none),
        videoController: isAlive ? pooledPlayer.videoController : null,
        player: isAlive ? pooledPlayer.player : null,
      );
    }
  }

  void _initialize() {
    if (_videos.isEmpty) return;
    _updatePreloadWindow(_currentIndex);
  }

  /// Called when the visible page changes.
  void onPageChanged(int index) {
    if (_isDisposed || index == _currentIndex) return;

    final oldIndex = _currentIndex;
    _currentIndex = index;

    // Pause old video
    _pauseVideo(oldIndex);

    // Play new video if ready
    if (_isActive && !_isPaused && isVideoReady(index)) {
      _playVideo(index);
    }

    // Update preload window
    _updatePreloadWindow(index);

    notifyListeners();
  }

  /// Set whether this feed is active.
  ///
  /// When `active: false`, pauses and releases ALL loaded players to free
  /// memory (e.g., when navigating to a detail page).
  ///
  /// When `active: true`, reloads the preload window and resumes playback.
  void setActive({required bool active}) {
    if (_isActive == active) return;
    _isActive = active;

    if (!active) {
      // Pause and release all players to free memory
      _pauseVideo(_currentIndex);
      _releaseAllPlayers();
    } else {
      // Reload preload window and play current video
      _updatePreloadWindow(_currentIndex);
    }

    notifyListeners();
  }

  void _releaseAllPlayers() {
    _loadedPlayers.keys.toList().forEach(_releasePlayer);
  }

  /// Play the current video (user-initiated resume).
  ///
  /// Resumes from current position without seeking. Distinct from
  /// [_playVideo] which seeks to start for swipe transitions.
  void play() {
    if (!_isActive || !isVideoReady(_currentIndex)) return;
    _isPaused = false;
    final player = _loadedPlayers[_currentIndex]?.player;
    if (player != null) {
      unawaited(player.setVolume(100));
      if (!player.state.playing) {
        unawaited(player.play());
      }
      _startPositionTimer(_currentIndex);
    }
    notifyListeners();
  }

  /// Pause the current video (user-initiated).
  ///
  /// Actually pauses the player (not just mute). Distinct from [_pauseVideo]
  /// which only mutes for smooth swipe transitions.
  void pause() {
    _isPaused = true;
    final player = _loadedPlayers[_currentIndex]?.player;
    if (player != null) {
      unawaited(player.pause());
    }
    _stopPositionTimer(_currentIndex);
    notifyListeners();
  }

  /// Toggle play/pause.
  void togglePlayPause() {
    if (_isPaused) {
      play();
    } else {
      pause();
    }
  }

  /// Seek to position in current video.
  Future<void> seek(Duration position) async {
    final player = _loadedPlayers[_currentIndex]?.player;
    if (player != null) {
      await player.seek(position);
    }
  }

  /// Set volume (0.0 to 1.0) for current video.
  void setVolume(double volume) {
    final player = _loadedPlayers[_currentIndex]?.player;
    if (player != null) {
      unawaited(player.setVolume((volume * 100).clamp(0, 100)));
    }
  }

  /// Set playback speed for current video.
  void setPlaybackSpeed(double speed) {
    final player = _loadedPlayers[_currentIndex]?.player;
    if (player != null) {
      unawaited(player.setRate(speed));
    }
  }

  /// Add videos to the end of the list.
  ///
  /// If any of the new videos fall within the preload window (based on the
  /// current index), they will be preloaded automatically.
  void addVideos(List<VideoItem> newVideos) {
    if (newVideos.isEmpty || _isDisposed) return;
    _videos.addAll(newVideos);

    if (_isActive) {
      _updatePreloadWindow(_currentIndex);
    }

    notifyListeners();
  }

  void _updatePreloadWindow(int index) {
    final toKeep = <int>{};

    // Calculate window to keep
    for (var i = index - preloadBehind; i <= index + preloadAhead; i++) {
      if (i >= 0 && i < _videos.length) {
        toKeep.add(i);
      }
    }

    // Release players outside window
    for (final idx in _loadedPlayers.keys.toList()) {
      if (!toKeep.contains(idx)) {
        _releasePlayer(idx);
      }
    }

    // Load missing players in window (current first, then others)
    final loadOrder = [index, ...toKeep.where((i) => i != index)];
    for (final idx in loadOrder) {
      if (!_loadedPlayers.containsKey(idx) && !_loadingIndices.contains(idx)) {
        unawaited(_loadPlayer(idx));
      }
    }
  }

  Future<void> _loadPlayer(int index) async {
    if (_isDisposed || _loadingIndices.contains(index)) return;
    if (index < 0 || index >= _videos.length) return;

    _loadingIndices.add(index);
    _loadStates[index] = LoadState.loading;
    _notifyIndex(index);

    try {
      final video = _videos[index];
      final pooledPlayer = await pool.getPlayer(video.url);

      // Guard: index may have been released during the await (e.g., the
      // preload window shifted while we were waiting for the pool).
      if (_isDisposed || !_loadingIndices.contains(index)) return;

      _loadedPlayers[index] = pooledPlayer;

      // Register a callback so we learn when the pool evicts this player.
      // The identity check in _onPlayerEvicted ensures stale callbacks
      // (from previously-released indices that loaded the same player)
      // are ignored.
      pooledPlayer.addOnDisposedCallback(
        () => _onPlayerEvicted(index, pooledPlayer),
      );

      // The pool may have already evicted (and disposed) this player during
      // a concurrent _loadPlayer call. For example, with maxPlayers=2 and
      // three concurrent loads, _loadPlayer(2) can evict url0 before
      // _loadPlayer(0) resumes to store its result. The eviction callback
      // fires as a no-op (identity check fails because _loadedPlayers[0]
      // was still null), so we must catch it here.
      if (pooledPlayer.isDisposed) {
        _loadedPlayers.remove(index);
        _loadStates.remove(index);
        _notifyIndex(index);
        return;
      }

      // Resolve media source via hook (for caching)
      final resolvedSource = mediaSourceResolver?.call(video) ?? video.url;

      // Open media with resolved source
      await pooledPlayer.player.open(Media(resolvedSource), play: false);
      await pooledPlayer.player.setPlaylistMode(PlaylistMode.single);

      // Guard: index may have been released during open/setPlaylistMode.
      if (_isDisposed || !_loadingIndices.contains(index)) return;

      // Set up buffer subscription
      unawaited(_bufferSubscriptions[index]?.cancel());
      _bufferSubscriptions[index] = pooledPlayer.player.stream.buffering.listen(
        (isBuffering) {
          if (!isBuffering && _loadStates[index] == LoadState.loading) {
            _onBufferReady(index);
          }
        },
      );

      // Start buffering (muted)
      await pooledPlayer.player.setVolume(0);
      await pooledPlayer.player.play();

      // Check if already buffered
      if (!pooledPlayer.player.state.buffering) {
        _onBufferReady(index);
      }
    } on Exception catch (e, stack) {
      debugPrint(
        'VideoFeedController: Failed to load index $index '
        '(videoCount=${_videos.length}): $e\n$stack',
      );
      if (!_isDisposed) {
        _loadStates[index] = LoadState.error;
        _notifyIndex(index);
      }
    } finally {
      _loadingIndices.remove(index);
    }
  }

  /// Called when a [PooledPlayer] is disposed externally (e.g., by pool
  /// eviction while loading a different video).
  ///
  /// Updates the widget state so the UI shows a placeholder instead of
  /// trying to render with a disposed [VideoController], which would crash
  /// with "A `ValueNotifier<int?>` was used after being disposed."
  void _onPlayerEvicted(int index, PooledPlayer evictedPlayer) {
    if (_isDisposed) return;
    // Only act if the evicted player is still the one tracked at this index.
    // After _releasePlayer or a subsequent _loadPlayer, _loadedPlayers[index]
    // will either be null or a different player, making this callback stale.
    if (_loadedPlayers[index] != evictedPlayer) return;

    _stopPositionTimer(index);
    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);
    _loadedPlayers.remove(index);
    _loadStates.remove(index);
    _loadingIndices.remove(index);
    _notifyIndex(index);
  }

  void _onBufferReady(int index) {
    if (_isDisposed) return;
    if (_loadStates[index] == LoadState.ready) return;

    final player = _loadedPlayers[index]?.player;
    if (player == null) return;

    _loadStates[index] = LoadState.ready;

    // Call onVideoReady hook
    onVideoReady?.call(index, player);

    if (index == _currentIndex && _isActive && !_isPaused) {
      // This is the current video - play it with audio
      unawaited(player.setVolume(100));

      // Start position callback timer for current video
      _startPositionTimer(index);
    } else {
      // Keep playing muted — avoids expensive pause→resume rebuffer stall
      // in mpv. Volume is already 0 from _loadPlayer, so no audio leak.
      // When this video becomes current, _playVideo will unmute and seek.
    }

    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);

    _notifyIndex(index);
  }

  void _playVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player == null) return;

    // Seek to start — also serves as a frame refresh trigger for media_kit's
    // Video widget. Without it, the widget may not receive a fresh frame
    // when first mounted, causing the video to appear frozen.
    unawaited(player.seek(Duration.zero));
    // Unmute — video may already be playing (muted preload) or paused.
    unawaited(player.setVolume(100));
    // Ensure playing regardless of current state.
    if (!player.state.playing) {
      unawaited(player.play());
    }
    _startPositionTimer(index);
  }

  void _pauseVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player != null) {
      // Mute instead of pausing — keeps the video playing silently so
      // resuming (via _playVideo) avoids the expensive mpv rebuffer stall.
      unawaited(player.setVolume(0));
    }
    _stopPositionTimer(index);
  }

  void _startPositionTimer(int index) {
    if (positionCallback == null) return;

    _positionTimers[index]?.cancel();
    _positionTimers[index] = Timer.periodic(
      positionCallbackInterval,
      (_) {
        final player = _loadedPlayers[index]?.player;
        if (player != null && player.state.playing) {
          positionCallback?.call(index, player.state.position);
        }
      },
    );
  }

  void _stopPositionTimer(int index) {
    _positionTimers[index]?.cancel();
    _positionTimers.remove(index);
  }

  void _releasePlayer(int index) {
    // Stop audio before removing from tracking to prevent audio leaks.
    // The player stays in the pool for reuse, but must be silent.
    final player = _loadedPlayers[index]?.player;
    if (player != null) {
      unawaited(player.setVolume(0));
      unawaited(player.pause());
    }

    _stopPositionTimer(index);
    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);
    _loadedPlayers.remove(index);
    _loadStates.remove(index);
    _loadingIndices.remove(index);
    _notifyIndex(index);
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    // Cancel all position timers first (they reference players).
    for (final timer in _positionTimers.values) {
      timer.cancel();
    }
    _positionTimers.clear();

    // Cancel all buffer subscriptions.
    for (final subscription in _bufferSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _bufferSubscriptions.clear();

    // Stop audio on ALL loaded players immediately to prevent audio leaks
    // during the async disposal that follows.
    for (final pooledPlayer in _loadedPlayers.values) {
      unawaited(pooledPlayer.player.setVolume(0));
      unawaited(pooledPlayer.player.pause());
    }

    // Collect player URLs to release BEFORE clearing state, but release
    // AFTER notifiers are disposed so no widget can rebuild with a stale
    // VideoController.
    final urlsToRelease = <String>[];
    for (var i = 0; i < _videos.length; i++) {
      if (_loadedPlayers.containsKey(i)) {
        urlsToRelease.add(_videos[i].url);
      }
    }

    // Clear loaded players so _notifyIndex reports null controllers.
    _loadedPlayers.clear();
    _loadStates.clear();
    _loadingIndices.clear();

    // Notify all index listeners that their video is gone.  This causes
    // ValueListenableBuilder to rebuild with videoController == null,
    // removing media_kit Video widgets from the tree BEFORE we dispose
    // the underlying native players (which would otherwise dispose the
    // internal ValueNotifier<int?> out from under a mounted widget).
    for (final entry in _indexNotifiers.entries) {
      entry.value.value = const VideoIndexState();
    }

    // Mark as disposed so no further _notifyIndex calls can fire.
    _isDisposed = true;

    // Dispose index notifiers (no widget should be listening now).
    for (final notifier in _indexNotifiers.values) {
      notifier.dispose();
    }
    _indexNotifiers.clear();

    // Now release players from pool (disposes native resources safely).
    for (final url in urlsToRelease) {
      unawaited(pool.release(url));
    }

    super.dispose();
  }
}
