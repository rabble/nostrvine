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
    // Match any Divine subdomain (media.divine.video, cdn.divine.video, etc.)
    if (!uri.host.toLowerCase().contains('divine.video')) return null;

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

String _canonicalDivineBlobHlsUrl(String hash) =>
    'https://media.divine.video/$hash/hls/master.m3u8';

String _canonicalDivineBlobRawUrl(String hash) =>
    'https://media.divine.video/$hash';

List<String> _orderedUniqueSources(Iterable<String?> sources) {
  final ordered = <String>[];
  final seen = <String>{};

  for (final source in sources) {
    if (source == null || source.isEmpty) continue;
    if (seen.add(source)) ordered.add(source);
  }

  return ordered;
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
    this.onVideoStalled,
    this.positionCallback,
    this.positionCallbackInterval = const Duration(milliseconds: 250),
    this.slowLoadThreshold = const Duration(seconds: 8),
    this.maxLoopDuration,
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

  /// Hook: Called when the current video repeatedly stalls and should be
  /// skipped.
  final VideoStalledCallback? onVideoStalled;

  /// Hook: Called periodically with position updates.
  ///
  /// Used for loop enforcement, progress tracking, etc.
  /// The interval is controlled by [positionCallbackInterval].
  final PositionCallback? positionCallback;

  /// Interval for [positionCallback] invocations.
  ///
  /// Defaults to 250ms.
  final Duration positionCallbackInterval;

  /// Duration after which a loading video is marked as slow.
  ///
  /// When exceeded, the index state's `isSlowLoad` flag is set so the
  /// UI can show a slow-loading indicator or skip action.
  final Duration slowLoadThreshold;

  /// Maximum playback duration before automatically seeking back to zero.
  ///
  /// When set, videos whose position exceeds this duration are
  /// automatically seeked back to [Duration.zero], creating a loop.
  /// This is useful for enforcing a maximum loop length on videos
  /// that are longer than the allowed duration.
  ///
  /// When `null`, no loop enforcement is applied (the player's own
  /// [PlaylistMode] controls looping).
  final Duration? maxLoopDuration;

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
  final Map<int, StreamSubscription<String>> _errorSubscriptions = {};
  final Map<int, VideoErrorType> _errorTypes = {};
  final Set<int> _loadingIndices = {};
  final Map<int, Timer> _positionTimers = {};
  final Map<int, Timer> _loadWatchdogTimers = {};
  final Map<int, Stopwatch> _loadStopwatches = {};
  final Map<int, String> _openedSources = {};
  final Map<int, List<String>> _playbackSources = {};
  final Map<int, int> _playbackSourceIndices = {};
  final Map<int, int> _stallRetryCount = {};
  final Set<int> _readyVideosAwaitingRecovery = {};
  final Set<int> _slowLoadIndices = {};
  int _preloadGeneration = 0;
  Timer? _stuckPlaybackTimer;

  static const _maxStallRetries = 1;

  /// Stale-position recovery: tracks the last observed position and how many
  /// consecutive heartbeats it has remained unchanged while the player reports
  /// `playing=true` and `buffering=false`.
  int? _lastHeartbeatPositionMs;
  int _staleHeartbeatCount = 0;
  int _staleRecoveryAttempts = 0;

  /// Remaining heartbeats to skip after a play/resume before stale-position
  /// detection activates. Gives the decoder time to start producing frames.
  int _staleGraceHeartbeats = 0;

  /// Number of consecutive stale heartbeats before triggering recovery.
  /// With a 100ms heartbeat interval, this means ~300ms of confirmed
  /// frozen video before recovery kicks in. False positives cause only
  /// a brief ~200ms micro-stutter (pause+seek+play at same position),
  /// which is far less disruptive than a multi-second visible freeze.
  static const _staleHeartbeatThreshold = 3;

  /// After this many failed seek-recovery attempts with no position progress,
  /// give up and mark the video as error.
  static const _maxStaleRecoveryAttempts = 2;

  /// Number of heartbeats to skip after play/resume before stale detection
  /// kicks in. With 100ms intervals this is ~500ms grace.
  static const _staleGraceAfterPlay = 5;

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
          errorType: _errorTypes[index],
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
        isSlowLoad: _slowLoadIndices.contains(index),
        errorType: _errorTypes[index],
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

      // Mark as slow load once threshold is exceeded (fires once per index).
      if (elapsedMs >= slowLoadThreshold.inMilliseconds &&
          _slowLoadIndices.add(index)) {
        _logDebug(
          'slow_load ${_videoDebugDetails(index)} '
          'elapsedMs=$elapsedMs threshold=${slowLoadThreshold.inMilliseconds}',
        );
        _notifyIndex(index);

        // Current video stuck in buffering too long — try next source
        // before giving up completely.
        if (index == _currentIndex) {
          _logDebug(
            'load_gave_up ${_videoDebugDetails(index)} '
            'elapsedMs=$elapsedMs',
          );
          timer.cancel();
          _loadWatchdogTimers.remove(index);
          unawaited(_retryCurrentVideoWithNextSource(index));
          return;
        }
      }

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

  List<String> _resolvePlaybackSources(VideoItem video) {
    final resolvedSource = mediaSourceResolver?.call(video) ?? video.url;
    final originalUrl = video.originalUrl;

    // Divine-hosted sources can fail in different ways:
    // - progressive derivatives may still be processing
    // - raw blobs can hit codec issues on some devices
    // - HLS can be missing while a transcode is being created
    //
    // Prefer the resolved source first, then the raw blob, and finally HLS.
    // For bare raw blobs, keep the existing raw -> HLS codec fallback.
    // Always include the original event URL as a last-resort fallback in case
    // all derived Divine URLs fail (e.g. non-Divine Blossom source).
    final hash = _extractCanonicalDivineBlobHash(resolvedSource);
    if (hash != null) {
      final rawUrl = _canonicalDivineBlobRawUrl(hash);
      final hlsUrl = _canonicalDivineBlobHlsUrl(hash);
      final isAlreadyHls = resolvedSource.contains('/hls/');
      if (isAlreadyHls) {
        return _orderedUniqueSources([resolvedSource, rawUrl, originalUrl]);
      }

      final isRawBlob = resolvedSource == rawUrl;
      return isRawBlob
          ? _orderedUniqueSources([resolvedSource, hlsUrl, originalUrl])
          : _orderedUniqueSources(
              [resolvedSource, rawUrl, hlsUrl, originalUrl],
            );
    }

    return _orderedUniqueSources([resolvedSource, originalUrl]);
  }

  Future<({String openedSource, int sourceIndex})> _openWithFallbacks({
    required int index,
    required Player player,
    required List<String> playbackSources,
    required int startIndex,
    required Stopwatch? loadStopwatch,
    required String retryLogLabel,
  }) async {
    var attemptIndex = startIndex;

    while (true) {
      final source = playbackSources[attemptIndex];

      try {
        await player.open(Media(source), play: false);
        return (openedSource: source, sourceIndex: attemptIndex);
      } on Exception catch (error) {
        final nextAttempt = attemptIndex + 1;
        if (nextAttempt >= playbackSources.length) rethrow;

        _logDebug(
          '$retryLogLabel ${_videoDebugDetails(index)} '
          'failedSource=$source '
          'retrySource=${playbackSources[nextAttempt]} '
          'elapsedMs=${loadStopwatch?.elapsedMilliseconds} '
          'error=$error',
        );
        attemptIndex = nextAttempt;
      }
    }
  }

  /// Classifies a raw error string into a [VideoErrorType].
  ///
  /// Checks for HTTP status code patterns (401, 403, 404) in the error
  /// message. For divine-hosted URLs where the error string is unparseable,
  /// falls back to [VideoErrorType.notFound] since missing content is the
  /// most common failure mode.
  VideoErrorType _classifyError(String? errorMessage, int index) {
    if (errorMessage != null) {
      final lower = errorMessage.toLowerCase();
      if (lower.contains('401') || lower.contains('unauthorized')) {
        return VideoErrorType.ageRestricted;
      }
      if (lower.contains('403') || lower.contains('forbidden')) {
        return VideoErrorType.forbidden;
      }
      if (lower.contains('404') || lower.contains('not found')) {
        return VideoErrorType.notFound;
      }
    }
    // For divine-hosted URLs, generic errors most likely mean missing
    // content (hash not on blossom, transcode pending). Non-divine URLs
    // keep the generic classification.
    if (index >= 0 && index < _videos.length) {
      final hash = _extractCanonicalDivineBlobHash(_videos[index].url);
      if (hash != null) return VideoErrorType.notFound;
    }
    return VideoErrorType.generic;
  }

  void _markLoadError({
    required int index,
    String? errorMessage,
    bool notifyStalled = false,
  }) {
    if (_isDisposed) return;
    _stallRetryCount.remove(index);
    _readyVideosAwaitingRecovery.remove(index);
    _loadStates[index] = LoadState.error;
    if (errorMessage != null) {
      _errorTypes[index] = _classifyError(errorMessage, index);
    }
    // If no message, _errorTypes[index] may already be set from the
    // error stream handler. Fall back to generic if nothing was stored.
    _errorTypes[index] ??= VideoErrorType.generic;
    _notifyIndex(index);
    if (notifyStalled) {
      onVideoStalled?.call(index);
    }
  }

  Future<void> _retryCurrentVideoWithNextSource(int index) async {
    final pooledPlayer = _loadedPlayers[index];
    final player = pooledPlayer?.player;
    if (player == null) {
      _logDebug('stuck_playback ${_videoDebugDetails(index)} giving up');
      _markLoadError(index: index, notifyStalled: true);
      return;
    }

    final playbackSources = _playbackSources[index];
    final currentSourceIndex = _playbackSourceIndices[index] ?? 0;
    final nextSourceIndex = currentSourceIndex + 1;

    if (playbackSources == null || nextSourceIndex >= playbackSources.length) {
      _logDebug('stuck_playback ${_videoDebugDetails(index)} giving up');
      _markLoadError(index: index, notifyStalled: true);
      return;
    }

    _logDebug(
      'stuck_failover ${_videoDebugDetails(index)} '
      'failedSource=${_openedSources[index]} '
      'retrySource=${playbackSources[nextSourceIndex]}',
    );

    _stopLoadWatchdog(index);
    _stopPositionTimer(index);
    _slowLoadIndices.remove(index);
    _loadStates[index] = LoadState.loading;
    _notifyIndex(index);

    try {
      await player.pause();
      final reopened = await _openWithFallbacks(
        index: index,
        player: player,
        playbackSources: playbackSources,
        startIndex: nextSourceIndex,
        loadStopwatch: _loadStopwatches[index],
        retryLogLabel: 'stuck_retry',
      );
      _playbackSourceIndices[index] = reopened.sourceIndex;
      _openedSources[index] = reopened.openedSource;
      await player.setPlaylistMode(PlaylistMode.single);
      await player.setVolume(0);
      await player.play();
      _startLoadWatchdog(index);
      _startStuckPlaybackWatchdog(index);

      if (!player.state.buffering) {
        _onBufferReady(index);
      }
    } on Exception catch (error, stack) {
      debugPrint(
        '[POOLED] stuck_retry_failed ${_videoDebugDetails(index)} '
        'error=$error\n$stack',
      );
      _markLoadError(
        index: index,
        errorMessage: error.toString(),
        notifyStalled: true,
      );
    }
  }

  /// Retries loading the video at [index] by releasing its player state
  /// and re-triggering the preload window.
  void retryLoad(int index) {
    if (_isDisposed) return;
    _logDebug('retry_load ${_videoDebugDetails(index)}');
    _releasePlayer(index);
    _updatePreloadWindow(_currentIndex);
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

    // Increment generation so stale preload callbacks are discarded.
    _preloadGeneration++;

    // Load current video first, then preloads after it completes.
    // This ensures the visible video gets full network priority.
    final preloadIndices = toKeep.where((i) => i != index).toList();
    unawaited(
      _loadCurrentThenPreloads(index, preloadIndices, _preloadGeneration),
    );
  }

  /// Loads the current video, then fires preloads concurrently.
  ///
  /// The [generation] parameter is compared against [_preloadGeneration]
  /// after the current video loads. If the user scrolled again in the
  /// meantime, the preloads are skipped (a newer window superseded them).
  Future<void> _loadCurrentThenPreloads(
    int index,
    List<int> preloadIndices,
    int generation,
  ) async {
    // Load the current (visible) video first.
    if (_shouldLoad(index)) {
      await _loadPlayer(index);
    }

    // Bail if a newer preload window was requested while loading.
    if (_isDisposed || _preloadGeneration != generation) return;

    // Now fire preloads concurrently — they share remaining bandwidth.
    for (final idx in preloadIndices) {
      if (_shouldLoad(idx)) {
        unawaited(_loadPlayer(idx));
      }
    }
  }

  bool _shouldLoad(int index) =>
      !_loadedPlayers.containsKey(index) && !_loadingIndices.contains(index);

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

      // Recycled players must NOT be published to _loadedPlayers or exposed
      // to the UI via _notifyIndex until after open() completes. Even though
      // stop() was awaited in _recycleLru(), the VideoController is still
      // bound to the previous URL's surface. Publishing it at LoadState.loading
      // would hand a stale controller to the UI before the new media is opened.
      // Non-recycled players are exposed immediately so the UI can show a
      // loading spinner while buffering.
      final isRecycled = pooledPlayer.wasRecycled;
      if (!isRecycled) {
        _loadedPlayers[index] = pooledPlayer;
        _notifyIndex(index);
      }

      // Register a callback so we learn when the pool evicts this player.
      // The identity check in _onPlayerEvicted ensures stale callbacks
      // (from previously-released indices that loaded the same player)
      // are ignored.
      pooledPlayer.addOnEvictedCallback(
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

      if (!isRecycled) {
        // Expose the allocated player/controller immediately so overlays can
        // render while the media is still buffering.
        _notifyIndex(index);
      }

      // Fast path: reuse player that already has media loaded.
      // When a player was released from the controller but stayed in the
      // pool, it retains its loaded media. Skip the expensive open() call
      // that would reset and rebuffer, causing a visible freeze.
      // This path is never taken for recycled players: hadExistingPlayer is
      // false (the new URL was not in the pool before getPlayer() was called).
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
      _playbackSources[index] = playbackSources;
      var sourceIndex = _playbackSourceIndices[index] ?? 0;
      if (sourceIndex < 0 || sourceIndex >= playbackSources.length) {
        sourceIndex = 0;
      }
      _logDebug(
        'open_start ${_videoDebugDetails(index)} '
        'resolvedSource=${playbackSources[sourceIndex]} '
        'fallbackSources=${playbackSources.skip(sourceIndex + 1).join(',')} '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
      );

      final opened = await _openWithFallbacks(
        index: index,
        player: pooledPlayer.player,
        playbackSources: playbackSources,
        startIndex: sourceIndex,
        loadStopwatch: loadStopwatch,
        retryLogLabel: 'open_retry',
      );
      await pooledPlayer.player.setPlaylistMode(PlaylistMode.single);
      _playbackSourceIndices[index] = opened.sourceIndex;
      _openedSources[index] = opened.openedSource;

      _logDebug(
        'open_complete ${_videoDebugDetails(index)} '
        'openedSource=${opened.openedSource} '
        'elapsedMs=${loadStopwatch.elapsedMilliseconds}',
      );

      // Guard: index may have been released during open/setPlaylistMode.
      if (_isDisposed || !_loadingIndices.contains(index)) return;

      // For recycled players, open() has now replaced the media surface.
      // It is safe to publish the controller to the UI for the first time.
      if (isRecycled) {
        pooledPlayer.clearRecycled();
        _loadedPlayers[index] = pooledPlayer;
        _notifyIndex(index);
      }

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
      _markLoadError(
        index: index,
        errorMessage: e.toString(),
        notifyStalled: index == _currentIndex,
      );
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
    unawaited(_errorSubscriptions[index]?.cancel());
    _errorSubscriptions.remove(index);
    _stopLoadWatchdog(index);
    _loadStopwatches.remove(index)?.stop();
    _openedSources.remove(index);
    _slowLoadIndices.remove(index);
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
    _slowLoadIndices.remove(index);
    _loadStates[index] = LoadState.ready;
    _notifyIndex(index);
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
      if (isBuffering) {
        if (_loadStates[index] == LoadState.ready) {
          _readyVideosAwaitingRecovery.add(index);
        }
        return;
      }

      if (_loadStates[index] == LoadState.loading) {
        _onBufferReady(index);
      } else if (_loadStates[index] == LoadState.ready &&
          index == _currentIndex &&
          _isActive &&
          !_isPaused) {
        final player = _loadedPlayers[index]?.player;
        if (player != null) {
          final wasRecovering = _readyVideosAwaitingRecovery.remove(index);
          if (wasRecovering) {
            final positionMs =
                pooledPlayer.player.state.position.inMilliseconds;
            final durationMs =
                pooledPlayer.player.state.duration.inMilliseconds;

            if (positionMs == 0 && durationMs == 0) {
              final retries = _stallRetryCount[index] =
                  (_stallRetryCount[index] ?? 0) + 1;
              if (retries > _maxStallRetries) {
                _logDebug(
                  'stall_circuit_breaker ${_videoDebugDetails(index)} '
                  'retries=$retries — giving up',
                );
                _markLoadError(index: index, notifyStalled: true);
                return;
              }
            } else {
              _stallRetryCount.remove(index);
            }
          }

          unawaited(player.play());
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

    unawaited(_errorSubscriptions[index]?.cancel());
    _errorSubscriptions[index] = pooledPlayer.player.stream.error.listen((
      error,
    ) {
      _logDebug(
        'player_error ${_videoDebugDetails(index)} '
        'error=$error '
        'source=${_openedSources[index]} '
        'loadState=${_loadStates[index]}',
      );
      // Classify the error immediately so the type is available if retry
      // exhausts all sources and _markLoadError is called without a message.
      _errorTypes[index] = _classifyError(error, index);
      // Only act on errors during initial load. Once the video is playing
      // successfully (LoadState.ready), mpv may emit non-critical errors
      // (e.g. on loop seeks, transient network hiccups) that should not
      // trigger a source failover.
      if (_loadStates[index] == LoadState.loading) {
        unawaited(_retryCurrentVideoWithNextSource(index));
      }
    });
  }

  void _playVideo(int index) {
    final player = _loadedPlayers[index]?.player;
    if (player == null) return;

    _stallRetryCount.remove(index);
    _readyVideosAwaitingRecovery.remove(index);

    // The player is paused (from _onBufferReady or _pauseVideo).
    // Unmute and play, seeking to zero only if the video reached the end
    // (loop behavior) or was preloaded (already at zero from _onBufferReady).
    unawaited(_resume(index, player));
    _startPositionTimer(index);
    _startStuckPlaybackWatchdog(index);
  }

  /// Detects stuck playback where the variant opens and reports "playing"
  /// but position never advances (broken transcode). If position stays at
  /// 0 for 5 seconds after playback starts, marks as error.
  void _startStuckPlaybackWatchdog(int index) {
    _stuckPlaybackTimer?.cancel();

    if (index != _currentIndex) return;
    if (index < 0 || index >= _videos.length) return;

    var checksRemaining = 5;
    _stuckPlaybackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || _currentIndex != index || !_isActive || _isPaused) {
        timer.cancel();
        return;
      }

      final player = _loadedPlayers[index]?.player;
      if (player == null) {
        timer.cancel();
        return;
      }

      // If position has advanced, playback is working — cancel watchdog.
      if (player.state.position.inMilliseconds > 100) {
        timer.cancel();
        return;
      }

      checksRemaining--;
      if (checksRemaining <= 0) {
        timer.cancel();
        unawaited(_retryCurrentVideoWithNextSource(index));
      }
    });
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
    _stuckPlaybackTimer?.cancel();
    _stopPositionTimer(index);
  }

  void _startPositionTimer(int index) {
    _positionTimers[index]?.cancel();
    // Reset stale-position tracking when starting a new timer.
    _lastHeartbeatPositionMs = null;
    _staleHeartbeatCount = 0;
    _staleRecoveryAttempts = 0;
    _staleGraceHeartbeats = _staleGraceAfterPlay;

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

      // Loop enforcement: seek back to zero when position exceeds
      // maxLoopDuration.
      if (maxLoopDuration != null &&
          index == _currentIndex &&
          player.state.playing &&
          player.state.position >= maxLoopDuration!) {
        _logDebug(
          'loop_enforcement ${_videoDebugDetails(index)} '
          'positionMs=${player.state.position.inMilliseconds} '
          'maxMs=${maxLoopDuration!.inMilliseconds}',
        );
        unawaited(player.seek(Duration.zero));
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
    // Grace period after play/resume — decoder needs time to start.
    if (_staleGraceHeartbeats > 0) {
      _staleGraceHeartbeats--;
      _lastHeartbeatPositionMs = null;
      _staleHeartbeatCount = 0;
      return;
    }

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
      _staleHeartbeatCount = 0;
      _lastHeartbeatPositionMs = null;
      _staleRecoveryAttempts++;

      // After repeated failed recoveries, the stream is likely corrupt
      // (e.g. missing h264 PPS headers). Give up so the user can swipe past.
      if (_staleRecoveryAttempts > _maxStaleRecoveryAttempts) {
        _logDebug(
          'stale_gave_up index=$index '
          'attempts=$_staleRecoveryAttempts '
          '${_videoDebugDetails(index)}',
        );
        _staleRecoveryAttempts = 0;
        _markLoadError(
          index: index,
          errorMessage: 'stale_playback',
          notifyStalled: true,
        );
        return;
      }

      _logDebug(
        'stale_position_detected index=$index '
        'positionMs=$positionMs '
        'attempt=$_staleRecoveryAttempts '
        '${_videoDebugDetails(index)}',
      );
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
    unawaited(_errorSubscriptions[index]?.cancel());
    _errorSubscriptions.remove(index);
    _stopLoadWatchdog(index);
    _loadStopwatches.remove(index)?.stop();
    _openedSources.remove(index);
    _stallRetryCount.remove(index);
    _readyVideosAwaitingRecovery.remove(index);
    _slowLoadIndices.remove(index);
    _loadedPlayers.remove(index);
    _loadStates.remove(index);
    _errorTypes.remove(index);
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

    _stuckPlaybackTimer?.cancel();

    // Cancel all buffer subscriptions.
    for (final subscription in _bufferSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _bufferSubscriptions.clear();

    for (final subscription in _playingSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _playingSubscriptions.clear();

    for (final subscription in _errorSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _errorSubscriptions.clear();

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
    _stallRetryCount.clear();
    _readyVideosAwaitingRecovery.clear();
    _playbackSources.clear();
    _playbackSourceIndices.clear();

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
