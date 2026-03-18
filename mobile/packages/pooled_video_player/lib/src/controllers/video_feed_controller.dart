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

String? _extractCanonicalDivineBlobHash(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.host.toLowerCase() != 'media.divine.video') return null;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    final hash = segments.first;
    final isHexHash =
        hash.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash);
    return isHexHash ? hash : null;
  } on FormatException {
    return null;
  }
}

bool _isCanonicalDivineBlobRawUrl(String url) {
  final hash = _extractCanonicalDivineBlobHash(url);
  if (hash == null) return false;

  final uri = Uri.parse(url);
  return uri.pathSegments.length == 1;
}

String _canonicalDivineBlobHlsUrl(String hash) =>
    'https://media.divine.video/$hash/hls/master.m3u8';

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
  final Map<int, StreamSubscription<bool>> _playingSubscriptions = {};
  final Set<int> _loadingIndices = {};
  final Map<int, Timer> _positionTimers = {};
  final Map<int, Timer> _loadWatchdogTimers = {};
  final Map<int, Stopwatch> _loadStopwatches = {};
  final Map<int, String> _openedSources = {};

  /// Stale-position recovery: tracks the last observed position and how many
  /// consecutive heartbeats it has remained unchanged while the player reports
  /// `playing=true` and `buffering=false`.
  int? _lastHeartbeatPositionMs;
  int _staleHeartbeatCount = 0;

  /// Number of consecutive stale heartbeats before triggering recovery.
  /// With a 100ms heartbeat interval, this means ~300ms of confirmed
  /// frozen video before recovery kicks in. False positives cause only
  /// a brief ~200ms micro-stutter (pause+seek+play at same position),
  /// which is far less disruptive than a multi-second visible freeze.
  static const _staleHeartbeatThreshold = 3;

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

  String _videoDebugDetails(int index) {
    if (index < 0 || index >= _videos.length) {
      return 'index=$index video=out_of_bounds videoCount=${_videos.length}';
    }
    final video = _videos[index];
    return 'index=$index videoId=${video.id} url=${video.url}';
  }

  void _logDebug(String message) {
    debugPrint('[POOLED] $message');
  }

  void _logLoadingSnapshot(int index, {required String reason}) {
    final player = _loadedPlayers[index]?.player;
    final elapsedMs = _loadStopwatches[index]?.elapsedMilliseconds;
    final positionMs = player?.state.position.inMilliseconds;
    final buffering = player?.state.buffering;
    final playing = player?.state.playing;
    final openedSource = _openedSources[index];
    _logDebug(
      'loading_wait ${_videoDebugDetails(index)} '
      'reason=$reason '
      'elapsedMs=$elapsedMs '
      'stateBuffering=$buffering statePlaying=$playing '
      'positionMs=$positionMs current=${index == _currentIndex} '
      'active=$_isActive paused=$_isPaused '
      'openedSource=$openedSource',
    );
  }

  void _startLoadWatchdog(int index) {
    _loadWatchdogTimers[index]?.cancel();
    _loadWatchdogTimers[index] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (_isDisposed || _loadStates[index] != LoadState.loading) {
        timer.cancel();
        _loadWatchdogTimers.remove(index);
        return;
      }

      final elapsedMs = _loadStopwatches[index]?.elapsedMilliseconds ?? 0;
      final shouldLog =
          index == _currentIndex ||
          elapsedMs == 1000 ||
          elapsedMs == 2000 ||
          elapsedMs == 5000 ||
          elapsedMs == 10000 ||
          (elapsedMs > 10000 && elapsedMs % 5000 == 0);
      if (shouldLog) {
        _logLoadingSnapshot(index, reason: 'watchdog');
      }
    });
  }

  void _stopLoadWatchdog(int index) {
    _loadWatchdogTimers[index]?.cancel();
    _loadWatchdogTimers.remove(index);
  }

  ({String primary, String? fallback}) _resolvePlaybackSources(
    VideoItem video,
  ) {
    final resolvedSource = mediaSourceResolver?.call(video) ?? video.url;

    if (_isCanonicalDivineBlobRawUrl(resolvedSource)) {
      final hash = _extractCanonicalDivineBlobHash(resolvedSource);
      if (hash != null) {
        return (
          primary: resolvedSource,
          fallback: _canonicalDivineBlobHlsUrl(hash),
        );
      }
    }

    return (primary: resolvedSource, fallback: null);
  }

  /// Called when the visible page changes.
  void onPageChanged(int index) {
    if (_isDisposed || index == _currentIndex) return;

    final oldIndex = _currentIndex;
    _currentIndex = index;

    _logDebug(
      'swipe old=${_videoDebugDetails(oldIndex)} '
      'new=${_videoDebugDetails(index)}',
    );

    if (_loadStates[index] == LoadState.loading) {
      _logLoadingSnapshot(index, reason: 'became_current');
    }

    // Pause old video
    _pauseVideo(oldIndex);

    // Mark the current video as most-recently-used in the pool so it is
    // never evicted when preloading neighbors below.
    _touchCurrentPlayerInPool(index);

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
  /// When `active: false`, pauses playback and optionally releases players:
  /// - If [retainCurrentPlayer] is `false` (default), ALL players are released
  ///   to free memory (e.g., when navigating to a detail page).
  /// - If [retainCurrentPlayer] is `true`, only the current player is paused
  ///   but retained for instant resume (e.g., when opening a bottom sheet).
  ///
  /// When `active: true`, resumes playback. If players were retained, playback
  /// resumes instantly. Otherwise, the preload window is reloaded.
  void setActive({required bool active, bool retainCurrentPlayer = false}) {
    if (_isActive == active) return;
    _isActive = active;

    if (!active) {
      _pauseVideo(_currentIndex);
      if (retainCurrentPlayer) {
        // Only pause current, release other players outside current index
        _loadedPlayers.keys
            .where((idx) => idx != _currentIndex)
            .toList()
            .forEach(_releasePlayer);
      } else {
        // Release all players to free memory
        _releaseAllPlayers();
      }
    } else {
      // Clear any manual pause so playback resumes with audio
      _isPaused = false;
      // If the current player is still loaded, play it immediately.
      if (isVideoReady(_currentIndex)) {
        _playVideo(_currentIndex);
      }
      // Always reload preload window to restore neighbor videos that may
      // have been released during deactivation.
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
  /// which mutes and pauses for swipe transitions.
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
      final hadExistingPlayer = pool.hasPlayer(video.url);
      final loadStopwatch = _loadStopwatches.putIfAbsent(
        index,
        () => Stopwatch()..start(),
      );
      _logDebug(
        'load_start ${_videoDebugDetails(index)} '
        'reused=$hadExistingPlayer poolPlayers=${pool.playerCount}',
      );
      final pooledPlayer = await pool.getPlayer(video.url);

      // Guard: index may have been released during the await (e.g., the
      // preload window shifted while we were waiting for the pool).
      if (_isDisposed || !_loadingIndices.contains(index)) return;

      _logDebug(
        'player_acquired ${_videoDebugDetails(index)} '
        'reused=$hadExistingPlayer '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds} '
        'poolPlayers=${pool.playerCount}',
      );

      _loadedPlayers[index] = pooledPlayer;
      _notifyIndex(index);

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
        _logDebug('player_disposed_before_open ${_videoDebugDetails(index)}');
        _loadedPlayers.remove(index);
        _loadStates.remove(index);
        _notifyIndex(index);
        return;
      }

      // Expose the allocated player/controller immediately so overlays can
      // render while the media is still buffering.
      _notifyIndex(index);

      // Fast path: reuse player that already has media loaded.
      // When a player was released from the controller but stayed in the
      // pool, it retains its loaded media. Skip the expensive open() call
      // that would reset and rebuffer, causing a visible freeze.
      if (hadExistingPlayer &&
          pooledPlayer.player.state.duration > Duration.zero) {
        _logDebug(
          'reuse_fast_path ${_videoDebugDetails(index)} '
          'positionMs='
          '${pooledPlayer.player.state.position.inMilliseconds} '
          'durationMs='
          '${pooledPlayer.player.state.duration.inMilliseconds} '
          'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
        );

        _setupStreamSubscriptions(index, pooledPlayer);

        _loadStates[index] = LoadState.ready;
        _loadStopwatches[index]?.stop();
        onVideoReady?.call(index, pooledPlayer.player);

        if (index == _currentIndex && _isActive && !_isPaused) {
          _playVideo(index);
        } else {
          unawaited(pooledPlayer.player.pause());
          unawaited(pooledPlayer.player.seek(Duration.zero));
        }

        _notifyIndex(index);
        return;
      }

      final playbackSources = _resolvePlaybackSources(video);
      var openedSource = playbackSources.primary;
      _logDebug(
        'open_start ${_videoDebugDetails(index)} '
        'resolvedSource=${playbackSources.primary} '
        'fallbackSource=${playbackSources.fallback} '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
      );

      try {
        await pooledPlayer.player.open(
          Media(playbackSources.primary),
          play: false,
        );
      } on Exception catch (error) {
        final fallbackSource = playbackSources.fallback;
        if (fallbackSource == null) rethrow;

        openedSource = fallbackSource;
        _logDebug(
          'open_retry ${_videoDebugDetails(index)} '
          'failedSource=${playbackSources.primary} '
          'retrySource=$fallbackSource '
          'elapsedMs=${loadStopwatch.elapsedMilliseconds} '
          'error=$error',
        );
        await pooledPlayer.player.open(Media(fallbackSource), play: false);
      }
      await pooledPlayer.player.setPlaylistMode(PlaylistMode.single);
      _openedSources[index] = openedSource;

      _logDebug(
        'open_complete ${_videoDebugDetails(index)} '
        'openedSource=$openedSource '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
      );

      // Guard: index may have been released during open/setPlaylistMode.
      if (_isDisposed || !_loadingIndices.contains(index)) return;

      _setupStreamSubscriptions(index, pooledPlayer);

      // Start buffering (muted)
      await pooledPlayer.player.setVolume(0);
      await pooledPlayer.player.play();
      _startLoadWatchdog(index);
      _logDebug(
        'buffering_start ${_videoDebugDetails(index)} '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
      );

      // Check if already buffered
      if (!pooledPlayer.player.state.buffering) {
        _onBufferReady(index);
      }
    } on Exception catch (e, stack) {
      debugPrint(
        '[POOLED] load_failed ${_videoDebugDetails(index)} '
        'videoCount=${_videos.length} '
        'elapsedMs=${_loadStopwatches[index]?.elapsedMilliseconds} '
        'error=$e\n$stack',
      );
      _stopLoadWatchdog(index);
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
    // Ignore stale callbacks: after release or reload, this index may
    // hold a different player (or none at all).
    if (_loadedPlayers[index] != evictedPlayer) return;

    _logDebug('player_evicted ${_videoDebugDetails(index)}');

    _stopPositionTimer(index);
    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);
    unawaited(_playingSubscriptions[index]?.cancel());
    _playingSubscriptions.remove(index);
    _stopLoadWatchdog(index);
    _loadStopwatches.remove(index)?.stop();
    _openedSources.remove(index);
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

    _stopLoadWatchdog(index);
    _loadStates[index] = LoadState.ready;
    final elapsedMs = _loadStopwatches[index]?.elapsedMilliseconds;
    _logDebug(
      'ready ${_videoDebugDetails(index)} '
      'current=${index == _currentIndex} active=$_isActive paused=$_isPaused '
      'elapsedMs=$elapsedMs',
    );

    // Call onVideoReady hook
    onVideoReady?.call(index, player);

    if (index == _currentIndex && _isActive && !_isPaused) {
      // This is the current video - play it with audio
      unawaited(player.setVolume(100));

      // Start position callback timer for current video
      _startPositionTimer(index);
    } else {
      // Preloaded video — pause and rewind to the beginning.
      // The video played muted just long enough to fill the buffer.
      // Pausing prevents it from advancing to a random position.
      // Seeking to zero while paused ensures frame 0 is displayed
      // when the user scrolls to this video.
      //
      // IMPORTANT: pause must complete before seeking. Seeking a
      // still-playing HLS stream in mpv can stall the decoder,
      // causing a frozen frame when the video is later resumed.
      unawaited(_pauseAndRewindPreloaded(index, player));
    }

    // Keep buffer subscription alive to handle post-seek rebuffering.
    // Subscriptions are cleaned up in _releasePlayer, _onPlayerEvicted,
    // and dispose.
  }

  /// Pauses a preloaded player and then seeks to zero, awaiting each step
  /// sequentially. Seeking a still-playing HLS stream in mpv can stall the
  /// decoder, so the pause must complete first.
  Future<void> _pauseAndRewindPreloaded(int index, Player player) async {
    try {
      await player.pause();
      // Guard: player may have been released while awaiting pause.
      if (_isDisposed || _loadedPlayers[index]?.player != player) return;
      await player.seek(Duration.zero);
    } on Exception catch (e) {
      _logDebug(
        'preload_rewind_failed ${_videoDebugDetails(index)} error=$e',
      );
    }

    _notifyIndex(index);
  }

  /// Sets up buffer and playing stream subscriptions for [index].
  ///
  /// Shared by the full-load path and the fast-path reuse shortcut so
  /// both flows get identical rebuffer-recovery and logging behaviour.
  void _setupStreamSubscriptions(int index, PooledPlayer pooledPlayer) {
    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions[index] = pooledPlayer.player.stream.buffering.listen((
      isBuffering,
    ) {
      _logDebug(
        'buffering_event ${_videoDebugDetails(index)} '
        'value=$isBuffering '
        'elapsedMs=${_loadStopwatches[index]?.elapsedMilliseconds} '
        'positionMs='
        '${pooledPlayer.player.state.position.inMilliseconds}',
      );
      if (!isBuffering) {
        if (_loadStates[index] == LoadState.loading) {
          _onBufferReady(index);
        } else if (_loadStates[index] == LoadState.ready &&
            index == _currentIndex &&
            _isActive &&
            !_isPaused) {
          final player = _loadedPlayers[index]?.player;
          if (player != null) {
            unawaited(player.play());
          }
        }
      }
    });

    unawaited(_playingSubscriptions[index]?.cancel());
    _playingSubscriptions[index] = pooledPlayer.player.stream.playing.listen((
      isPlaying,
    ) {
      _logDebug(
        'playing_event ${_videoDebugDetails(index)} '
        'value=$isPlaying '
        'elapsedMs=${_loadStopwatches[index]?.elapsedMilliseconds} '
        'positionMs='
        '${pooledPlayer.player.state.position.inMilliseconds} '
        'current=${index == _currentIndex}',
      );
    });
  }

  void _playVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player == null) return;

    // The player is paused (from _onBufferReady or _pauseVideo).
    // Unmute and play, seeking to zero only if the video reached the end
    // (loop behavior) or was preloaded (already at zero from _onBufferReady).
    unawaited(_resume(index, player));
    _startPositionTimer(index);
  }

  /// Unmute and play, seeking to the beginning only when at the end of the
  /// video (loop behavior).
  ///
  /// The player is expected to be paused (from [_onBufferReady] for preloaded
  /// videos, or from [_pauseVideo] for swiped-away videos). Seeking while
  /// paused avoids the mpv renderer stall that occurs when seeking a playing
  /// HLS stream.
  Future<void> _resume(int index, Player player) async {
    try {
      // Seek to zero only when the video has reached the end so it loops.
      // Mid-playback position is preserved for swiped-away videos.
      // Preloaded videos are already at position zero from _onBufferReady.
      final duration = player.state.duration;
      if (duration > Duration.zero && player.state.position >= duration) {
        await player.seek(Duration.zero);
      }

      // Guard: user may have scrolled away during the seek.
      if (_isDisposed || _currentIndex != index || !_isActive || _isPaused) {
        _logDebug(
          'play_aborted ${_videoDebugDetails(index)} '
          'current=$_currentIndex active=$_isActive '
          'paused=$_isPaused disposed=$_isDisposed',
        );
        return;
      }
      if (_loadedPlayers[index]?.player != player) return;

      await player.setVolume(100);
      await player.play();
      _logDebug(
        'play_started ${_videoDebugDetails(index)} '
        'playing=${player.state.playing} '
        'elapsedMs=${_loadStopwatches[index]?.elapsedMilliseconds}',
      );
    } on Exception catch (e, stack) {
      debugPrint(
        '[POOLED] play_failed ${_videoDebugDetails(index)} error=$e\n$stack',
      );
    }
  }

  void _pauseVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player != null) {
      // Mute and pause. The player stays in the pool for reuse.
      // _resume will unmute and play when this video becomes current again,
      // preserving the current playback position.
      unawaited(player.setVolume(0));
      unawaited(player.pause());
    }
    _stopPositionTimer(index);
  }

  void _startPositionTimer(int index) {
    _positionTimers[index]?.cancel();
    // Reset stale-position tracking when starting a new timer.
    _lastHeartbeatPositionMs = null;
    _staleHeartbeatCount = 0;

    // Use the shorter of the caller's interval and the stale-detection
    // interval so both position callbacks and recovery work correctly.
    final interval =
        positionCallback != null &&
            positionCallbackInterval < const Duration(milliseconds: 100)
        ? positionCallbackInterval
        : const Duration(milliseconds: 100);

    _positionTimers[index] = Timer.periodic(interval, (_) {
      final player = _loadedPlayers[index]?.player;
      if (player == null) return;

      // Stale-position watchdog: detect and recover from mpv decoder
      // stalls caused by B-frame encoded videos.
      if (index == _currentIndex) {
        _checkStalePosition(
          index,
          player,
          player.state.position.inMilliseconds,
        );
      }

      if (positionCallback != null && player.state.playing) {
        positionCallback?.call(index, player.state.position);
      }
    });
  }

  /// Checks whether the current video's position has stalled. If the position
  /// hasn't changed for [_staleHeartbeatThreshold] consecutive heartbeats while
  /// the player reports `playing=true` and `buffering=false`, we assume
  /// media_kit's decoder is stuck and attempt recovery.
  void _checkStalePosition(int index, Player player, int positionMs) {
    if (!player.state.playing || player.state.buffering) {
      // Not in a state where we'd expect position to advance.
      _staleHeartbeatCount = 0;
      _lastHeartbeatPositionMs = null;
      return;
    }

    if (_lastHeartbeatPositionMs != null &&
        positionMs == _lastHeartbeatPositionMs) {
      _staleHeartbeatCount++;
    } else {
      _staleHeartbeatCount = 0;
    }
    _lastHeartbeatPositionMs = positionMs;

    if (_staleHeartbeatCount >= _staleHeartbeatThreshold) {
      _logDebug(
        'stale_position_detected index=$index '
        'positionMs=$positionMs '
        'staleCount=$_staleHeartbeatCount '
        '${_videoDebugDetails(index)}',
      );
      _staleHeartbeatCount = 0;
      _lastHeartbeatPositionMs = null;
      _recoverStalePlayer(index, player, positionMs);
    }
  }

  /// Attempts to recover a player whose position is frozen.
  ///
  /// Strategy: pause, seek to the stuck position (nudges mpv's decoder),
  /// then play again.
  void _recoverStalePlayer(int index, Player player, int positionMs) {
    _logDebug(
      'stale_recovery_start index=$index positionMs=$positionMs '
      '${_videoDebugDetails(index)}',
    );

    unawaited(() async {
      try {
        await player.pause();
        await player.seek(Duration(milliseconds: positionMs));

        // Guard: user may have swiped away during the seek.
        if (_isDisposed || _currentIndex != index || !_isActive || _isPaused) {
          _logDebug(
            'stale_recovery_aborted index=$index '
            'current=$_currentIndex active=$_isActive '
            'paused=$_isPaused disposed=$_isDisposed',
          );
          return;
        }

        await player.setVolume(100);
        await player.play();
        _logDebug(
          'stale_recovery_complete index=$index '
          'playing=${player.state.playing} '
          'positionMs=${player.state.position.inMilliseconds} '
          '${_videoDebugDetails(index)}',
        );
      } on Exception catch (e) {
        _logDebug(
          'stale_recovery_failed index=$index error=$e '
          '${_videoDebugDetails(index)}',
        );
      }
    }());
  }

  /// Marks the current video's URL as most-recently-used in the player pool.
  ///
  /// Called before [_updatePreloadWindow] to ensure the pool's LRU eviction
  /// never targets the video the user is watching. Without this, preloading
  /// neighbor videos can evict the current player, freezing playback with
  /// no recovery possible (the heartbeat timer is cancelled on eviction).
  void _touchCurrentPlayerInPool(int index) {
    if (index < 0 || index >= _videos.length) return;
    final url = _videos[index].url;
    // getExistingPlayer touches (marks MRU) without creating a new player.
    pool.getExistingPlayer(url);
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
    unawaited(_playingSubscriptions[index]?.cancel());
    _playingSubscriptions.remove(index);
    _stopLoadWatchdog(index);
    _loadStopwatches.remove(index)?.stop();
    _openedSources.remove(index);
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

    for (final timer in _loadWatchdogTimers.values) {
      timer.cancel();
    }
    _loadWatchdogTimers.clear();

    // Cancel all buffer subscriptions.
    for (final subscription in _bufferSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _bufferSubscriptions.clear();

    for (final subscription in _playingSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _playingSubscriptions.clear();

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
    for (final stopwatch in _loadStopwatches.values) {
      stopwatch.stop();
    }
    _loadStopwatches.clear();
    _openedSources.clear();

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
