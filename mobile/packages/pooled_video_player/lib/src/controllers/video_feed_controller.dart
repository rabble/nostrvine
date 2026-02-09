import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/player_pool.dart';
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
  VideoFeedController({
    required List<VideoItem> videos,
    PlayerPool? pool,
    this.preloadAhead = 2,
    this.preloadBehind = 1,
    this.mediaSourceResolver,
    this.onVideoReady,
    this.positionCallback,
    this.positionCallbackInterval = const Duration(milliseconds: 200),
  }) : pool = pool ?? PlayerPool.instance,
       _videos = List.from(videos) {
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
  int _currentIndex = 0;
  bool _isActive = true;
  bool _isPaused = false;
  bool _isDisposed = false;

  // Loaded players by index
  final Map<int, PooledPlayer> _loadedPlayers = {};
  final Map<int, LoadState> _loadStates = {};
  final Map<int, StreamSubscription<bool>> _bufferSubscriptions = {};
  final Set<int> _loadingIndices = {};
  final Map<int, Timer> _positionTimers = {};

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

  /// Play the current video.
  void play() {
    if (!_isActive || !isVideoReady(_currentIndex)) return;
    _isPaused = false;
    _playVideo(_currentIndex);
    notifyListeners();
  }

  /// Pause the current video.
  void pause() {
    _isPaused = true;
    _pauseVideo(_currentIndex);
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
    notifyListeners();

    try {
      final video = _videos[index];
      final pooledPlayer = await pool.getPlayer(video.url);

      if (_isDisposed) return;

      _loadedPlayers[index] = pooledPlayer;

      // Resolve media source via hook (for caching)
      final resolvedSource = mediaSourceResolver?.call(video) ?? video.url;

      // Open media with resolved source
      await pooledPlayer.player.open(Media(resolvedSource), play: false);
      await pooledPlayer.player.setPlaylistMode(PlaylistMode.single);

      if (_isDisposed) return;

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
    } on Exception catch (e) {
      debugPrint('PooledVideoPlayer: Failed to load video at index $index: $e');
      if (!_isDisposed) {
        _loadStates[index] = LoadState.error;
        notifyListeners();
      }
    } finally {
      _loadingIndices.remove(index);
    }
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
      // This is the current video - play it
      unawaited(player.setVolume(100));

      // Start position callback timer for current video
      _startPositionTimer(index);
    } else {
      // Preloaded video - pause it
      unawaited(player.pause());
      unawaited(player.setVolume(100));
    }

    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);

    notifyListeners();
  }

  void _playVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player != null && !player.state.playing) {
      unawaited(player.setVolume(100));
      unawaited(player.play());
      _startPositionTimer(index);
    }
  }

  void _pauseVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player != null && player.state.playing) {
      unawaited(player.pause());
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
    _stopPositionTimer(index);
    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);
    _loadedPlayers.remove(index);
    _loadStates.remove(index);
    _loadingIndices.remove(index);
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Cancel all position timers
    for (final timer in _positionTimers.values) {
      timer.cancel();
    }
    _positionTimers.clear();

    // Cancel all subscriptions
    for (final subscription in _bufferSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _bufferSubscriptions.clear();

    // Clear state (players are managed by pool)
    _loadedPlayers.clear();
    _loadStates.clear();
    _loadingIndices.clear();

    super.dispose();
  }
}
