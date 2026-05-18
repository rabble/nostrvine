import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;
import 'package:unified_logger/unified_logger.dart';

/// Creates a Linux video backend implementation.
typedef LinuxVideoPlayerBackendFactory = LinuxVideoPlayerBackend Function();

/// Linux-specific playback backend used by the public controller.
abstract interface class LinuxVideoPlayerBackend {
  /// Initializes the backend and starts emitting state changes.
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  });

  /// Loads one or more clips into the backend player.
  Future<void> setClips(List<VideoClip> clips, {Duration? startPosition});

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback and unloads media.
  Future<void> stop();

  /// Seeks to a position on the global timeline.
  Future<void> seekTo(Duration position);

  /// Sets the player volume.
  Future<void> setVolume(double volume);

  /// Sets the playback speed multiplier.
  Future<void> setPlaybackSpeed(double speed);

  /// Enables or disables looping.
  Future<void> setLooping({required bool looping});

  /// Jumps to a clip index within the current timeline.
  Future<void> jumpToClip(int index);

  /// Replaces the active overlay audio tracks.
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks);

  /// Removes all overlay audio tracks.
  Future<void> removeAllAudioTracks();

  /// Sets the volume of a single overlay audio track.
  Future<void> setAudioTrackVolume(int index, double volume);

  /// Builds the platform-specific render widget.
  Widget buildView();

  /// Disposes the backend and releases native resources.
  Future<void> dispose();
}

/// Linux backend powered by `media_kit` and mpv.
class MediaKitLinuxVideoPlayerBackend implements LinuxVideoPlayerBackend {
  /// Creates a Linux backend instance.
  MediaKitLinuxVideoPlayerBackend({
    void Function()? mediaKitInitializer,
    Player Function()? playerFactory,
    Object Function(Player player)? videoControllerFactory,
    Future<void> Function(Object controller)? videoControllerReady,
    Widget Function(Object controller)? videoViewBuilder,
    Future<Duration> Function(String uri)? durationProbe,
  }) : _mediaKitInitializer = mediaKitInitializer ?? MediaKit.ensureInitialized,
       _playerFactory = playerFactory ?? Player.new,
       _videoControllerFactory =
           videoControllerFactory ?? _defaultVideoControllerFactory,
       _videoControllerReady =
           videoControllerReady ?? _defaultVideoControllerReady,
       _videoViewBuilder = videoViewBuilder ?? _defaultVideoViewBuilder,
       _durationProbe = durationProbe;

  // media_kit native initialization is process-global, so this latch must
  // survive hot restart. Tests reset it explicitly via the visible hook.
  static bool _mediaKitInitialized = false;

  final void Function() _mediaKitInitializer;
  final Player Function() _playerFactory;
  final Object Function(Player player) _videoControllerFactory;
  final Future<void> Function(Object controller) _videoControllerReady;
  final Widget Function(Object controller) _videoViewBuilder;
  final Future<Duration> Function(String uri)? _durationProbe;

  /// Resets the one-time media_kit initialization latch for tests.
  @visibleForTesting
  static void resetInitializationForTesting() {
    _mediaKitInitialized = false;
  }

  late final Player _player;
  late final Object _videoController;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _clips = <VideoClip>[];
  final _clipDurations = <Duration>[];
  final _clipOffsets = <Duration>[];

  void Function(DivineVideoPlayerState state)? _onStateChanged;
  void Function(Object error)? _onError;

  DivineVideoPlayerState _state = const DivineVideoPlayerState();
  bool _initialized = false;
  bool _disposed = false;
  bool _isLooping = false;
  bool _hasLoadedMedia = false;
  bool _didLogUnsupportedAudioTrackWarning = false;
  int _currentClipIndex = 0;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    _ensureMediaKitInitialized();
    _onStateChanged = onStateChanged;
    _onError = onError;
    _player = _playerFactory();
    _videoController = _videoControllerFactory(_player);
    _listenToPlayer();
    _initialized = true;

    unawaited(
      _videoControllerReady(_videoController).then((_) {
        _emitState(_state.copyWith(isFirstFrameRendered: true));
      }, onError: onError),
    );
  }

  @override
  Future<void> setClips(
    List<VideoClip> clips, {
    Duration? startPosition,
  }) async {
    _ensureReady();
    _clips
      ..clear()
      ..addAll(clips);

    final boundedDurations = await _resolveClipDurations(clips);
    _clipDurations
      ..clear()
      ..addAll(boundedDurations);
    _rebuildClipOffsets();

    final playlist = Playlist([
      for (final clip in clips)
        Media(clip.uri, start: clip.start, end: clip.end),
    ]);

    _hasLoadedMedia = true;
    _currentClipIndex = 0;
    _emitState(
      _state.copyWith(
        status: PlaybackStatus.buffering,
        clipCount: clips.length,
        currentClipIndex: 0,
        duration: _totalDuration,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        isFirstFrameRendered: false,
        clearError: true,
      ),
    );

    await _player.open(playlist, play: false);
    await _player.setPlaylistMode(
      _isLooping ? PlaylistMode.loop : PlaylistMode.none,
    );

    final seekPosition = startPosition ?? Duration.zero;
    if (seekPosition > Duration.zero) {
      await seekTo(seekPosition);
    } else {
      _refreshState();
    }
  }

  @override
  Future<void> play() async {
    _ensureReady();
    await _player.play();
    _refreshState();
  }

  @override
  Future<void> pause() async {
    _ensureReady();
    await _player.pause();
    _refreshState();
  }

  @override
  Future<void> stop() async {
    _ensureReady();
    await _player.stop();
    _hasLoadedMedia = false;
    _clips.clear();
    _clipDurations.clear();
    _clipOffsets.clear();
    _currentClipIndex = 0;
    _emitState(const DivineVideoPlayerState());
  }

  @override
  Future<void> seekTo(Duration position) async {
    _ensureReady();
    if (_clips.isEmpty) return;

    final clamped = _clampGlobalPosition(position);
    final targetIndex = _clipIndexForPosition(clamped);
    final clipOffset = _clipOffsets[targetIndex];
    final clip = _clips[targetIndex];
    final localOffset = clamped - clipOffset;
    final sourcePosition = clip.start + localOffset;

    if (_currentClipIndex != targetIndex) {
      await _player.jump(targetIndex);
    }
    await _player.seek(sourcePosition);
    _refreshState();
  }

  @override
  Future<void> setVolume(double volume) async {
    _ensureReady();
    await _player.setVolume(volume * 100);
    _emitState(_state.copyWith(volume: volume));
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureReady();
    await _player.setRate(speed);
    _emitState(_state.copyWith(playbackSpeed: speed));
  }

  @override
  Future<void> setLooping({required bool looping}) async {
    _ensureReady();
    _isLooping = looping;
    await _player.setPlaylistMode(
      looping ? PlaylistMode.loop : PlaylistMode.none,
    );
    _emitState(_state.copyWith(isLooping: looping));
  }

  @override
  Future<void> jumpToClip(int index) async {
    _ensureReady();
    if (index < 0 || index >= _clips.length) return;
    await _player.jump(index);
    await _player.seek(_clips[index].start);
    _refreshState();
  }

  @override
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks) async {
    if (tracks.isEmpty) return;
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Future<void> removeAllAudioTracks() async {
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Future<void> setAudioTrackVolume(int index, double volume) async {
    _logUnsupportedAudioTrackOperation();
  }

  @override
  Widget buildView() {
    _ensureReady();
    return _videoViewBuilder(_videoController);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }

  void _listenToPlayer() {
    _subscriptions.addAll([
      _player.stream.playing.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.position.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.duration.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.buffer.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.buffering.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.playlist.listen((playlist) {
        _currentClipIndex = playlist.index.clamp(
          0,
          math.max(_clips.length - 1, 0),
        );
        _refreshState();
      }, onError: _handleError),
      _player.stream.completed.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.volume.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.rate.listen((_) => _refreshState(), onError: _handleError),
      _player.stream.width.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
      _player.stream.height.listen(
        (_) => _refreshState(),
        onError: _handleError,
      ),
    ]);
  }

  Future<List<Duration>> _resolveClipDurations(List<VideoClip> clips) async {
    final durations = <Duration>[];
    for (final clip in clips) {
      if (clip.end != null) {
        if (clip.end! < clip.start) {
          throw ArgumentError.value(
            clip.end,
            'clip.end',
            'must be greater than or equal to clip.start',
          );
        }
        durations.add(clip.end! - clip.start);
        continue;
      }

      final sourceDuration = await (_durationProbe ?? _probeDuration)(clip.uri);
      if (clip.start > sourceDuration) {
        throw ArgumentError.value(
          clip.start,
          'clip.start',
          'must be less than or equal to the source duration',
        );
      }
      durations.add(sourceDuration - clip.start);
    }
    return durations;
  }

  Future<Duration> _probeDuration(String uri) async {
    final probe = _playerFactory();
    try {
      await probe.open(Media(uri), play: false);
      final duration = await probe.stream.duration
          .firstWhere(
            (value) => value > Duration.zero,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Could not probe duration for $uri'),
          );
      return duration;
    } finally {
      await probe.dispose();
    }
  }

  // coverage:ignore-start
  // Default seams that bind to real media_kit native objects. They cannot
  // run in a headless unit test (no native media_kit backend), which is why
  // they are injectable — tests substitute fakes via the constructor.
  //
  // Environment escape hatch: setting `DIVINE_LINUX_NO_VIDEO_OUTPUT=1` skips
  // VideoController construction entirely. mpv's GL render-context setup
  // segfaults natively on virtual GPUs (QEMU virtio-gpu, some headless CI
  // runners) the moment it touches Flutter's EGL config — a native crash that
  // cannot be caught from Dart. With the flag set, audio still plays via the
  // mpv `Player`, and `buildView()` returns an empty placeholder so the
  // thumbnail behind it stays visible.
  static const _disableVideoOutputEnvVar = 'DIVINE_LINUX_NO_VIDEO_OUTPUT';

  static bool get _videoOutputDisabled {
    final value = Platform.environment[_disableVideoOutputEnvVar];
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static Object _defaultVideoControllerFactory(Player player) {
    if (_videoOutputDisabled) {
      Log.warning(
        'DIVINE_LINUX_NO_VIDEO_OUTPUT is set — skipping VideoController. '
        'Audio will play but video frames will not render.',
        name: 'divine_video_player',
        category: LogCategory.video,
      );
      return const _DisabledVideoController();
    }
    // Hardware-accelerated EGL rendering crashes on virtual GPUs (QEMU,
    // VirtualBox). Software rendering is reliable across all Linux setups.
    return media_kit.VideoController(
      player,
      configuration: const media_kit.VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );
  }

  static Future<void> _defaultVideoControllerReady(Object controller) {
    if (controller is _DisabledVideoController) return Future.value();
    return (controller as media_kit.VideoController)
        .waitUntilFirstFrameRendered;
  }

  static Widget _defaultVideoViewBuilder(Object controller) {
    if (controller is _DisabledVideoController) {
      return const SizedBox.expand();
    }
    return media_kit.Video(
      controller: controller as media_kit.VideoController,
      controls: null,
    );
  }
  // coverage:ignore-end

  void _rebuildClipOffsets() {
    _clipOffsets.clear();
    var offset = Duration.zero;
    for (final duration in _clipDurations) {
      _clipOffsets.add(offset);
      offset += duration;
    }
  }

  Duration get _totalDuration =>
      _clipDurations.fold(Duration.zero, (a, b) => a + b);

  Duration _clampGlobalPosition(Duration position) {
    if (_clipDurations.isEmpty) return Duration.zero;
    if (position <= Duration.zero) return Duration.zero;
    if (position >= _totalDuration) return _totalDuration;
    return position;
  }

  int _clipIndexForPosition(Duration position) {
    for (var i = 0; i < _clipOffsets.length; i++) {
      final start = _clipOffsets[i];
      final end = start + _clipDurations[i];
      if (position < end || i == _clipOffsets.length - 1) {
        return i;
      }
    }
    return 0;
  }

  void _refreshState() {
    if (!_initialized || _disposed) return;

    final playerState = _player.state;
    final hasClips = _clips.isNotEmpty;
    final currentIndex = hasClips
        ? _currentClipIndex.clamp(0, _clips.length - 1)
        : 0;
    final currentClip = hasClips ? _clips[currentIndex] : null;
    final currentOffset = hasClips ? _clipOffsets[currentIndex] : Duration.zero;
    final currentDuration = hasClips
        ? _clipDurations[currentIndex]
        : Duration.zero;

    final localPosition = currentClip == null
        ? Duration.zero
        : _clampDuration(
            playerState.position - currentClip.start,
            max: currentDuration,
          );
    final localBuffer = currentClip == null
        ? Duration.zero
        : _clampDuration(
            playerState.buffer - currentClip.start,
            max: currentDuration,
          );

    final status = switch ((
      hasClips,
      playerState.completed,
      playerState.buffering,
      playerState.playing,
    )) {
      (false, _, _, _) => PlaybackStatus.idle,
      (_, true, _, _) when !_isLooping => PlaybackStatus.completed,
      (_, _, true, _) => PlaybackStatus.buffering,
      (_, _, _, true) => PlaybackStatus.playing,
      _ when _hasLoadedMedia => PlaybackStatus.ready,
      _ => PlaybackStatus.idle,
    };

    _emitState(
      _state.copyWith(
        status: status,
        position: currentOffset + localPosition,
        duration: _totalDuration,
        bufferedPosition: currentOffset + localBuffer,
        currentClipIndex: currentIndex,
        clipCount: _clips.length,
        isLooping: _isLooping,
        volume: playerState.volume / 100,
        playbackSpeed: playerState.rate,
        videoWidth: playerState.width ?? 0,
        videoHeight: playerState.height ?? 0,
        clearError: status != PlaybackStatus.error,
      ),
    );
  }

  Duration _clampDuration(Duration value, {required Duration max}) {
    if (value <= Duration.zero) return Duration.zero;
    if (value >= max) return max;
    return value;
  }

  void _emitState(DivineVideoPlayerState newState) {
    if (_disposed) return;
    _state = newState;
    _onStateChanged?.call(newState);
  }

  void _handleError(Object error) {
    if (_disposed) return;
    _emitState(
      _state.copyWith(status: PlaybackStatus.error, errorMessage: '$error'),
    );
    _onError?.call(error);
  }

  void _logUnsupportedAudioTrackOperation() {
    if (_didLogUnsupportedAudioTrackWarning) return;
    _didLogUnsupportedAudioTrackWarning = true;
    Log.warning(
      'Overlay audio tracks are not supported on the Linux backend yet.',
      name: 'divine_video_player',
      category: LogCategory.video,
    );
  }

  void _ensureMediaKitInitialized() {
    if (_mediaKitInitialized) return;
    _mediaKitInitializer();
    _mediaKitInitialized = true;
  }

  void _ensureReady() {
    if (!_initialized) {
      throw StateError('Linux backend is not initialized.');
    }
    if (_disposed) {
      throw StateError('Linux backend has been disposed.');
    }
  }
}

/// Sentinel marker used in place of a real `VideoController` when video
/// output is disabled via `DIVINE_LINUX_NO_VIDEO_OUTPUT`. Lets the rest of
/// the backend stay non-nullable while skipping native GL setup.
class _DisabledVideoController {
  const _DisabledVideoController();
}
