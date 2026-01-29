import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:pooled_video_player/src/controllers/player_pool_manager.dart';
import 'package:pooled_video_player/src/models/player_lease.dart';
import 'package:pooled_video_player/src/models/video_item.dart';
import 'package:pooled_video_player/src/models/video_load_error.dart';
import 'package:pooled_video_player/src/models/video_player_exceptions.dart';
import 'package:pooled_video_player/src/models/video_pool_config.dart';

/// State of video preloading for a specific index.
enum PreloadState {
  /// No preload has been initiated.
  none,

  /// Media is being opened.
  opening,

  /// Media is buffering.
  buffering,

  /// Media is ready for playback.
  ready,

  /// Media is currently playing.
  playing,

  /// An error occurred during preloading.
  error,
}

/// Direction the user is scrolling through the video feed.
enum ScrollDirection {
  /// No scroll direction detected.
  none,

  /// Scrolling forward (next video).
  forward,

  /// Scrolling backward (previous video).
  backward,
}

/// Callback for preload errors.
typedef OnPreloadError = void Function(int index, VideoLoadError error);

/// Controller for a single video feed/timeline.
///
/// Multiple instances can coexist, each managing its own state while sharing
/// the underlying [PlayerPoolManager] for efficient resource usage.
///
/// Example usage:
/// ```dart
/// final controller = VideoFeedController(
///   feedId: 'main-feed',
///   videos: myVideos,
/// );
///
/// // Later, dispose when no longer needed
/// controller.dispose();
/// ```
class VideoFeedController extends ChangeNotifier {
  /// Creates a controller for a video feed.
  ///
  /// The [feedId] must be unique across all feeds in the app.
  /// If [preloadAhead] or [preloadBehind] are not provided, values from
  /// [PlayerPoolManager.config] will be used.
  ///
  /// The optional [onPreloadError] callback is invoked when a preload fails.
  VideoFeedController({
    required this.feedId,
    required List<VideoItem> videos,
    int? preloadAhead,
    int? preloadBehind,
    this.onPreloadError,
  }) : _videos = List.from(videos),
       _preloadAhead =
           preloadAhead ?? PlayerPoolManager.instance.config.preloadAhead,
       _preloadBehind =
           preloadBehind ?? PlayerPoolManager.instance.config.preloadBehind,
       _preloadDebounceDelay =
           PlayerPoolManager.instance.config.preloadDebounceDelay {
    PlayerPoolManager.instance.registerFeed(this);
    _initializePreloading();
  }

  /// Callback invoked when a preload error occurs.
  final OnPreloadError? onPreloadError;

  /// Unique identifier for this feed.
  final String feedId;

  /// Videos in this timeline.
  final List<VideoItem> _videos;

  /// Unmodifiable list of all videos in this feed.
  List<VideoItem> get videos => List.unmodifiable(_videos);

  /// Number of videos in this feed.
  int get videoCount => _videos.length;

  // Preload configuration
  final int _preloadAhead;
  final int _preloadBehind;
  final Duration _preloadDebounceDelay;

  // Per-feed state
  int _currentIndex = 0;
  bool _isPaused = false;
  ScrollDirection _scrollDirection = ScrollDirection.none;
  Timer? _preloadDebounceTimer;
  bool _isDisposed = false;

  // Player leases owned by this feed (index -> lease)
  final Map<int, PlayerLease> _leases = {};
  final Map<int, PreloadState> _preloadStates = {};
  final Map<int, StreamSubscription<bool>> _bufferSubscriptions = {};
  final Map<int, bool> _shouldRestartOnPlay = {};
  final Set<int> _releasingIndices = {};

  /// Indices currently being preloaded.
  ///
  /// This prevents duplicate concurrent preloads for the same index.
  final Set<int> _preloadingIndices = {};

  // Error tracking
  final Map<int, VideoLoadError> _errors = {};
  final Map<int, Timer> _retryTimers = {};
  final Map<int, int> _lastRetryCount = {};

  // Index-level operation locks to prevent race conditions between
  // preload and release operations on the same video index
  final Map<int, Completer<void>> _indexLocks = {};

  // ============================================
  // Index Locking (Race Condition Prevention)
  // ============================================

  /// Executes an operation with exclusive access to the given index.
  ///
  /// This prevents race conditions between concurrent preload and release
  /// operations on the same video index, which could cause FFI crashes.
  Future<T?> _withIndexLock<T>(
    int index,
    Future<T?> Function() operation,
  ) async {
    // Wait for any pending operation on this index
    while (_indexLocks.containsKey(index)) {
      await _indexLocks[index]!.future;
    }

    // Acquire the lock
    final completer = Completer<void>();
    _indexLocks[index] = completer;

    try {
      return await operation();
    } finally {
      completer.complete();
      _indexLocks.remove(index);
    }
  }

  // ============================================
  // State Getters
  // ============================================

  /// The currently active video index.
  int get currentIndex => _currentIndex;

  /// Whether playback is currently paused.
  bool get isPaused => _isPaused;

  /// Current scroll direction.
  ScrollDirection get scrollDirection => _scrollDirection;

  /// Get the [VideoController] for rendering a video at the given index.
  ///
  /// Returns null if the video is not yet preloaded.
  VideoController? getVideoController(int index) =>
      _leases[index]?.videoController;

  /// Get the underlying [Player] for a video at the given index.
  ///
  /// Returns null if the video is not yet preloaded.
  Player? getPlayer(int index) => _leases[index]?.player;

  /// Get the preload state for a video at the given index.
  PreloadState getPreloadState(int index) =>
      _preloadStates[index] ?? PreloadState.none;

  /// Returns true if the video at the given index is ready for playback.
  bool isVideoReady(int index) {
    final state = _preloadStates[index];
    return state == PreloadState.ready || state == PreloadState.playing;
  }

  /// Whether the system has reported memory pressure.
  bool get isMemoryConstrained =>
      PlayerPoolManager.instance.isMemoryConstrained;

  // ============================================
  // Error Handling
  // ============================================

  /// Get the error for a video at the given index, if any.
  VideoLoadError? getError(int index) => _errors[index];

  /// Get all current errors as an unmodifiable map.
  Map<int, VideoLoadError> get errors => Map.unmodifiable(_errors);

  /// Whether the video at the given index has an error.
  bool hasError(int index) => _errors.containsKey(index);

  /// Retry loading a failed video.
  ///
  /// Clears the error state and attempts to preload the video again.
  /// The retry count is tracked for exponential backoff purposes.
  Future<void> retryPreload(int index) async {
    if (!_errors.containsKey(index)) return;
    if (_isDisposed) return;

    final existingError = _errors[index]!;
    _errors.remove(index);
    _preloadStates[index] = PreloadState.none;

    // Track retry count for this index
    _lastRetryCount[index] = existingError.retryCount + 1;

    notifyListeners();
    await _preloadVideo(index);
  }

  /// Clear error for a specific index.
  void clearError(int index) {
    _errors.remove(index);
    _retryTimers[index]?.cancel();
    _retryTimers.remove(index);
    _lastRetryCount.remove(index);
    notifyListeners();
  }

  /// Clear all errors and cancel pending retries.
  void clearAllErrors() {
    _errors.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _lastRetryCount.clear();
    notifyListeners();
  }

  // ============================================
  // Playback Control - Current Video
  // ============================================

  /// Play the current video.
  void play() {
    final lease = _leases[_currentIndex];
    if (lease == null || !lease.isValid) return;

    unawaited(lease.player.play());
    _isPaused = false;
    _preloadStates[_currentIndex] = PreloadState.playing;
    notifyListeners();
  }

  /// Pause the current video.
  void pause() {
    final lease = _leases[_currentIndex];
    if (lease == null || !lease.isValid) return;

    unawaited(lease.player.pause());
    _isPaused = true;
    notifyListeners();
  }

  /// Toggle play/pause state.
  void togglePlayPause() {
    if (_isPaused) {
      play();
    } else {
      pause();
    }
  }

  /// Seek to a specific position in the current video.
  Future<void> seek(Duration position) async {
    final lease = _leases[_currentIndex];
    if (lease == null || !lease.isValid) return;

    await lease.player.seek(position);
  }

  /// Set the volume (0.0 to 1.0) for the current video.
  void setVolume(double volume) {
    final lease = _leases[_currentIndex];
    if (lease == null || !lease.isValid) return;

    unawaited(lease.player.setVolume((volume * 100).clamp(0, 100)));
  }

  /// Set mute state for the current video.
  void setMute({required bool muted}) {
    final lease = _leases[_currentIndex];
    if (lease == null || !lease.isValid) return;

    unawaited(lease.player.setVolume(muted ? 0 : 100));
  }

  /// Set playback speed (0.5 to 2.0 typical) for the current video.
  void setPlaybackSpeed(double speed) {
    final lease = _leases[_currentIndex];
    if (lease == null || !lease.isValid) return;

    unawaited(lease.player.setRate(speed));
  }

  /// Get current playback position of the current video.
  Duration? get currentPosition =>
      _leases[_currentIndex]?.player.state.position;

  /// Get total duration of the current video.
  Duration? get duration => _leases[_currentIndex]?.player.state.duration;

  /// Get buffered duration of the current video.
  Duration? get buffered => _leases[_currentIndex]?.player.state.buffer;

  /// Stream of position updates for the current video.
  Stream<Duration>? get positionStream =>
      _leases[_currentIndex]?.player.stream.position;

  /// Stream of playing state updates for the current video.
  Stream<bool>? get playingStream =>
      _leases[_currentIndex]?.player.stream.playing;

  /// Stream of buffering state updates for the current video.
  Stream<bool>? get bufferingStream =>
      _leases[_currentIndex]?.player.stream.buffering;

  // ============================================
  // Navigation
  // ============================================

  /// Notify the controller that the user has navigated to a new page/video.
  ///
  /// Call this from your UI's page change callback
  /// (e.g., `PageView.onPageChanged`).
  void onPageChanged(int newIndex) {
    if (_isDisposed) return;

    final oldIndex = _currentIndex;

    // Detect scroll direction
    if (newIndex > oldIndex) {
      _scrollDirection = ScrollDirection.forward;
    } else if (newIndex < oldIndex) {
      _scrollDirection = ScrollDirection.backward;
    }

    _currentIndex = newIndex;

    // Immediately handle video transition
    _handleImmediateTransition(oldIndex, newIndex);

    // Debounce preloading for fast scrolling
    _preloadDebounceTimer?.cancel();
    _preloadDebounceTimer = Timer(_preloadDebounceDelay, () {
      if (!_isDisposed) {
        _performPreloading(newIndex);
      }
    });

    notifyListeners();
  }

  // ============================================
  // Video Management
  // ============================================

  /// Add videos to the end of the list (for lazy loading / infinite scroll).
  void addVideos(List<VideoItem> newVideos) {
    if (newVideos.isEmpty || _isDisposed) return;

    _videos.addAll(newVideos);

    // Trigger preload if user is near the end
    if (_currentIndex >= _videos.length - _preloadAhead - newVideos.length) {
      _performPreloading(_currentIndex);
    }
    notifyListeners();
  }

  /// Add a single video to the end of the list.
  void addVideo(VideoItem video) => addVideos([video]);

  /// Remove a video at the given index.
  void removeVideo(int index) {
    if (index < 0 || index >= _videos.length || _isDisposed) return;

    // Release player if loaded
    unawaited(_releasePlayer(index));

    _videos.removeAt(index);

    // Adjust current index if needed
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex && _currentIndex >= _videos.length) {
      _currentIndex = _videos.length - 1;
    }

    notifyListeners();
  }

  // ============================================
  // Handoff API
  // ============================================

  /// Extract a player for handoff to another context (e.g., detail page).
  ///
  /// The feed releases ownership but the player keeps playing.
  /// Returns the [PlayerLease] or null if no player is loaded for that index.
  PlayerLease? extractPlayerForHandoff(int index) {
    final lease = _leases.remove(index);
    if (lease != null) {
      _preloadStates[index] = PreloadState.none;
      _shouldRestartOnPlay.remove(index);
      unawaited(_bufferSubscriptions[index]?.cancel());
      _bufferSubscriptions.remove(index);
      notifyListeners();
    }
    return lease;
  }

  /// Accept a player being returned from handoff.
  ///
  /// The player is reintegrated into the feed at the given index.
  Future<void> acceptPlayerFromHandoff(int index, PlayerLease lease) async {
    if (_isDisposed) {
      // If we're disposed, release the lease back to the pool
      await PlayerPoolManager.instance.releaseLease(lease);
      return;
    }

    // Transfer ownership back to this feed
    PlayerPoolManager.instance.transferLease(
      lease: lease,
      newOwnerId: feedId,
    );

    _leases[index] = lease;

    // Determine state based on player's current state
    if (lease.player.state.playing) {
      _preloadStates[index] = PreloadState.playing;
    } else {
      _preloadStates[index] = PreloadState.ready;
    }

    notifyListeners();
  }

  // ============================================
  // Memory Pressure
  // ============================================

  /// Called by [PlayerPoolManager] when system reports memory pressure.
  void onMemoryPressure() {
    if (_isDisposed) return;

    // Keep only current +/- 1
    final criticalIndices = <int>{_currentIndex};
    if (_currentIndex > 0) criticalIndices.add(_currentIndex - 1);
    if (_currentIndex < _videos.length - 1) {
      criticalIndices.add(_currentIndex + 1);
    }

    unawaited(_releasePlayersOutsideWindow(criticalIndices));
  }

  // ============================================
  // Private Methods - Preloading
  // ============================================

  void _initializePreloading() {
    if (_videos.isEmpty) return;

    // Preload initial videos
    unawaited(_preloadVideo(0));
    for (var i = 1; i <= _preloadAhead && i < _videos.length; i++) {
      unawaited(_preloadVideo(i));
    }
  }

  Future<void> _preloadVideo(int index) async {
    // Quick bounds check outside lock
    if (index < 0 || index >= _videos.length) return;
    if (_isDisposed) return;

    // Use index lock to prevent race conditions with _releasePlayer
    await _withIndexLock(index, () async {
      // Recheck conditions inside lock to handle race conditions
      if (_isDisposed || _releasingIndices.contains(index)) return null;

      // Prevent concurrent preloads for the same index
      if (_preloadingIndices.contains(index)) return null;

      final currentState = _preloadStates[index];
      if (currentState == PreloadState.ready ||
          currentState == PreloadState.playing ||
          currentState == PreloadState.buffering ||
          currentState == PreloadState.opening) {
        return null;
      }

      // Mark as preloading BEFORE any async operations
      _preloadingIndices.add(index);
      _preloadStates[index] = PreloadState.opening;
      notifyListeners();

      try {
        final video = _videos[index];

        // Determine priority based on distance from current
        final distance = (index - _currentIndex).abs();
        final priority = index == _currentIndex
            ? PlayerPriority.current
            : distance == 1
            ? PlayerPriority.adjacentFocused
            : PlayerPriority.distant;

        // Acquire lease from pool manager if not already active
        if (!_leases.containsKey(index)) {
          final lease = await PlayerPoolManager.instance.acquirePlayer(
            videoId: video.id,
            ownerId: feedId,
            priority: priority,
          );

          // Check if released while acquiring
          if (_isDisposed || _releasingIndices.contains(index)) {
            await PlayerPoolManager.instance.releaseLease(lease);
            return null;
          }

          _leases[index] = lease;
        }

        final lease = _leases[index];
        if (lease == null || !lease.isValid) return null;

        final player = lease.player;

        // Open media
        await player.open(Media(video.url), play: false);
        if (_isDisposed || !lease.isValid) return null;

        await player.setPlaylistMode(PlaylistMode.single);
        if (_isDisposed || !lease.isValid) return null;

        _preloadStates[index] = PreloadState.buffering;
        notifyListeners();

        // Set volume to 0 for silent buffering
        await player.setVolume(0);
        if (_isDisposed || !lease.isValid) return null;

        // Set up subscription BEFORE playing to catch all buffering events
        unawaited(_bufferSubscriptions[index]?.cancel());
        _bufferSubscriptions[index] = player.stream.buffering.listen((
          isBuffering,
        ) {
          if (!isBuffering && _preloadStates[index] == PreloadState.buffering) {
            unawaited(_onBufferReady(index));
          }
        });

        // Start playing to trigger actual buffering
        await player.play();
        if (_isDisposed || !lease.isValid) return null;

        // Check if already buffered (event may have fired before subscription)
        if (!player.state.buffering &&
            _preloadStates[index] == PreloadState.buffering) {
          unawaited(_onBufferReady(index));
        }
      } on PlayerPoolExhaustedException catch (e, stackTrace) {
        _handlePreloadError(index, e, stackTrace);
      } on VideoLoadFailedException catch (e, stackTrace) {
        _handlePreloadError(index, e, stackTrace);
      } on Exception catch (e, stackTrace) {
        // Wrap unknown exceptions
        final wrappedError = VideoLoadFailedException(
          videoId: _videos[index].id,
          url: _videos[index].url,
          reason: e.toString(),
          cause: e,
        );
        _handlePreloadError(index, wrappedError, stackTrace);
      } finally {
        _preloadingIndices.remove(index);
      }

      return null;
    });
  }

  void _handlePreloadError(int index, Object error, StackTrace? stackTrace) {
    if (_isDisposed) return;

    final video = _videos[index];
    final retryCount = _lastRetryCount[index] ?? 0;

    final videoError = VideoLoadError(
      index: index,
      videoId: video.id,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      retryCount: retryCount,
    );

    _errors[index] = videoError;
    _preloadStates[index] = PreloadState.error;

    // Invoke callback
    onPreloadError?.call(index, videoError);

    // Schedule auto-retry if enabled and within limits
    _scheduleAutoRetry(index, videoError);

    notifyListeners();
  }

  void _scheduleAutoRetry(int index, VideoLoadError error) {
    final config = PlayerPoolManager.instance.config;

    if (!config.enableAutoRetry) return;
    if (error.retryCount >= config.maxRetryAttempts) return;
    if (!error.isRecoverable) return;

    // Cancel any existing retry timer
    _retryTimers[index]?.cancel();

    // Calculate exponential backoff delay
    final delay = _calculateRetryDelay(error.retryCount, config);

    _retryTimers[index] = Timer(delay, () {
      if (!_isDisposed && _errors.containsKey(index)) {
        unawaited(retryPreload(index));
      }
    });
  }

  Duration _calculateRetryDelay(int attemptNumber, VideoPoolConfig config) {
    final delayMs =
        config.initialRetryDelay.inMilliseconds *
        pow(config.retryBackoffMultiplier, attemptNumber);
    return Duration(
      milliseconds: min(delayMs.toInt(), config.maxRetryDelay.inMilliseconds),
    );
  }

  Future<void> _onBufferReady(int index) async {
    if (_isDisposed) return;

    if (_preloadStates[index] == PreloadState.ready ||
        _preloadStates[index] == PreloadState.playing) {
      return;
    }

    final lease = _leases[index];
    if (lease == null || !lease.isValid) return;

    final player = lease.player;

    // Only pause if this isn't the current playing video
    if (index != _currentIndex) {
      if (!lease.isValid) return;
      await player.pause();

      if (_isDisposed || !lease.isValid) return;
      await player.setVolume(100);

      if (_isDisposed) return;
      _preloadStates[index] = PreloadState.ready;
      // Update lease priority
      lease.priority = PlayerPriority.adjacentFocused;
      _shouldRestartOnPlay[index] = false;
    } else {
      // This is the current video - restore volume and mark as playing
      if (!lease.isValid) return;
      await player.setVolume(100);

      if (_isDisposed) return;
      _preloadStates[index] = PreloadState.playing;
      lease.priority = PlayerPriority.current;
    }

    unawaited(_bufferSubscriptions[index]?.cancel());
    _bufferSubscriptions.remove(index);
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Set<int> _calculatePreloadWindow(int currentIndex) {
    final indicesToPreload = <int>{currentIndex};

    // Reduce preload window under memory pressure
    final ahead = isMemoryConstrained ? 1 : _preloadAhead;
    final behind = isMemoryConstrained ? 1 : _preloadBehind;

    if (_scrollDirection == ScrollDirection.forward) {
      // User scrolling forward - prioritize ahead
      for (var i = 1; i <= ahead; i++) {
        indicesToPreload.add(currentIndex + i);
      }
      for (var i = 1; i <= behind; i++) {
        indicesToPreload.add(currentIndex - i);
      }
    } else if (_scrollDirection == ScrollDirection.backward) {
      // User scrolling backward - prioritize behind
      for (var i = 1; i <= ahead; i++) {
        indicesToPreload.add(currentIndex - i);
      }
      for (var i = 1; i <= behind; i++) {
        indicesToPreload.add(currentIndex + i);
      }
    } else {
      // No direction - balanced
      for (var i = 1; i <= ahead; i++) {
        indicesToPreload
          ..add(currentIndex + i)
          ..add(currentIndex - i);
      }
    }

    // Filter valid indices
    return indicesToPreload.where((i) => i >= 0 && i < _videos.length).toSet();
  }

  void _preloadInPriorityOrder(int currentIndex, Set<int> indicesToPreload) {
    final sortedIndices = indicesToPreload.toList()
      ..sort((a, b) {
        if (a == currentIndex) return -1;
        if (b == currentIndex) return 1;

        // Prioritize based on scroll direction
        if (_scrollDirection == ScrollDirection.forward) {
          if (a > currentIndex && b <= currentIndex) return -1;
          if (b > currentIndex && a <= currentIndex) return 1;
        } else if (_scrollDirection == ScrollDirection.backward) {
          if (a < currentIndex && b >= currentIndex) return -1;
          if (b < currentIndex && a >= currentIndex) return 1;
        }

        return (a - currentIndex).abs().compareTo((b - currentIndex).abs());
      });

    for (final index in sortedIndices) {
      unawaited(_preloadVideo(index));
    }
  }

  void _handleImmediateTransition(int oldIndex, int newIndex) {
    // Pause old video - mark for restart but preserve buffer
    final oldLease = _leases[oldIndex];
    if (oldLease != null && oldLease.isValid) {
      unawaited(oldLease.player.pause());
      _shouldRestartOnPlay[oldIndex] = true;
      oldLease.priority = PlayerPriority.adjacentFocused;
      if (_preloadStates[oldIndex] == PreloadState.playing) {
        _preloadStates[oldIndex] = PreloadState.ready;
      }
    }

    // Play new video
    _isPaused = false;
    final newLease = _leases[newIndex];
    if (newLease != null && newLease.isValid) {
      final player = newLease.player;

      // Seek to start only if this video was previously played
      if (_shouldRestartOnPlay[newIndex] ?? false) {
        unawaited(player.seek(Duration.zero));
        _shouldRestartOnPlay[newIndex] = false;
      }

      unawaited(player.setVolume(100));
      unawaited(player.play());
      _preloadStates[newIndex] = PreloadState.playing;
      newLease.priority = PlayerPriority.current;
    } else {
      // Not preloaded - create and load immediately
      unawaited(_preloadVideo(newIndex));
    }
  }

  void _performPreloading(int currentIndex) {
    final indicesToKeep = _calculatePreloadWindow(currentIndex);
    _preloadInPriorityOrder(currentIndex, indicesToKeep);
    unawaited(_releasePlayersOutsideWindow(indicesToKeep));
  }

  Future<void> _releasePlayersOutsideWindow(Set<int> indicesToKeep) async {
    final indicesToRelease = _leases.keys
        .where((i) => !indicesToKeep.contains(i))
        .toList();

    for (final index in indicesToRelease) {
      await _releasePlayer(index);
    }

    // Emergency cleanup if too many players
    final maxPlayers = PlayerPoolManager.instance.config.maxActivePlayers;
    if (_leases.length > maxPlayers) {
      final sortedByDistance = _leases.keys.toList()
        ..sort(
          (a, b) => (a - _currentIndex).abs().compareTo(
            (b - _currentIndex).abs(),
          ),
        );

      final toRelease = sortedByDistance.skip(maxPlayers).toList();
      for (final index in toRelease) {
        if (index != _currentIndex) {
          await _releasePlayer(index);
        }
      }
    }
  }

  Future<void> _releasePlayer(int index) async {
    // Use index lock to prevent race conditions with _preloadVideo
    await _withIndexLock(index, () async {
      // Mark as releasing to prevent new operations on this index
      _releasingIndices.add(index);

      try {
        await _bufferSubscriptions[index]?.cancel();
        _bufferSubscriptions.remove(index);

        final lease = _leases.remove(index);
        if (lease != null && lease.isValid) {
          await PlayerPoolManager.instance.releaseLease(lease);
        }

        _preloadStates.remove(index);
        _shouldRestartOnPlay.remove(index);
      } finally {
        // Always remove from releasing set, even if an exception occurred
        _releasingIndices.remove(index);
      }

      return null;
    });
  }

  // ============================================
  // Lifecycle Helpers
  // ============================================

  /// Clears all internal state maps.
  void _clearStateMaps() {
    _preloadStates.clear();
    _shouldRestartOnPlay.clear();
    _releasingIndices.clear();
    _preloadingIndices.clear();
    _indexLocks.clear();
  }

  /// Cancels all retry timers and clears error-related state.
  void _cancelRetryTimersAndClearErrors() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _errors.clear();
    _lastRetryCount.clear();
  }

  // ============================================
  // Lifecycle
  // ============================================

  /// Dispose the controller and release all resources.
  ///
  /// **Important:** This method triggers async cleanup but returns
  /// synchronously to satisfy Flutter's dispose contract. For guaranteed
  /// cleanup completion, call [disposeAsync] instead when possible.
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    PlayerPoolManager.instance.unregisterFeed(this);

    _preloadDebounceTimer?.cancel();

    // Cancel all subscriptions synchronously
    for (final subscription in _bufferSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _bufferSubscriptions.clear();

    // Stop all players immediately to prevent native callbacks
    // This is synchronous and prevents new callbacks from being dispatched
    for (final lease in _leases.values) {
      if (lease.isValid) {
        // Stop playback immediately - this is critical to prevent
        // native callbacks after Dart objects are collected
        unawaited(lease.player.stop());
      }
    }

    // Schedule async cleanup but don't block dispose
    unawaited(_cleanupLeases());

    _clearStateMaps();
    _cancelRetryTimersAndClearErrors();

    super.dispose();
  }

  /// Async cleanup of leases - called from dispose but awaited separately.
  Future<void> _cleanupLeases() async {
    // Copy leases to avoid modification during iteration
    final leasesToRelease = _leases.values.toList();
    _leases.clear();

    // Release leases sequentially to avoid concurrent disposal issues
    for (final lease in leasesToRelease) {
      if (lease.isValid) {
        try {
          await PlayerPoolManager.instance.releaseLease(lease);
        } on Exception {
          // Ignore errors during cleanup - player may already be disposed
        }
      }
    }
  }

  /// Async dispose that guarantees cleanup completion.
  ///
  /// Use this when you need to ensure all resources are released before
  /// proceeding (e.g., before navigating away or reinitializing).
  Future<void> disposeAsync() async {
    if (_isDisposed) return;
    _isDisposed = true;

    PlayerPoolManager.instance.unregisterFeed(this);

    _preloadDebounceTimer?.cancel();

    // Cancel all subscriptions
    for (final subscription in _bufferSubscriptions.values) {
      await subscription.cancel();
    }
    _bufferSubscriptions.clear();

    // Stop all players first to prevent native callbacks
    for (final lease in _leases.values) {
      if (lease.isValid) {
        await lease.player.stop();
      }
    }

    // Small delay to allow native callbacks to settle
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Release leases sequentially
    final leasesToRelease = _leases.values.toList();
    _leases.clear();

    for (final lease in leasesToRelease) {
      if (lease.isValid) {
        try {
          await PlayerPoolManager.instance.releaseLease(lease);
        } on Exception {
          // Ignore errors during cleanup
        }
      }
    }

    _clearStateMaps();
    _cancelRetryTimersAndClearErrors();

    super.dispose();
  }
}
