import 'dart:async';
import 'dart:math' as math;

import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;

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
  MediaKitLinuxVideoPlayerBackend();

  static bool _mediaKitInitialized = false;

  /// Ensures `media_kit` is initialized exactly once per process.
  static void ensureInitialized() {
    if (_mediaKitInitialized) return;
    MediaKit.ensureInitialized();
    _mediaKitInitialized = true;
  }

  late final Player _player;
  late final media_kit.VideoController _videoController;
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
  int _currentClipIndex = 0;

  @override
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  }) async {
    ensureInitialized();
    _onStateChanged = onStateChanged;
    _onError = onError;
    _player = Player();
    _videoController = media_kit.VideoController(_player);
    _listenToPlayer();
    _initialized = true;

    unawaited(
      _videoController.waitUntilFirstFrameRendered.then((_) {
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
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks) {
    throw UnsupportedError(
      'Linux backend does not support overlay audio tracks yet.',
    );
  }

  @override
  Future<void> removeAllAudioTracks() async {}

  @override
  Future<void> setAudioTrackVolume(int index, double volume) {
    throw UnsupportedError(
      'Linux backend does not support overlay audio tracks yet.',
    );
  }

  @override
  Widget buildView() {
    _ensureReady();
    return media_kit.Video(
      controller: _videoController,
      controls: null,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait<void>([
      for (final subscription in _subscriptions) subscription.cancel(),
      _player.dispose(),
    ]);
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
        durations.add(clip.end! - clip.start);
        continue;
      }

      final sourceDuration = await _probeDuration(clip.uri);
      durations.add(sourceDuration - clip.start);
    }
    return durations;
  }

  Future<Duration> _probeDuration(String uri) async {
    final probe = Player();
    try {
      await probe.open(Media(uri), play: false);
      final duration = await probe.stream.duration.firstWhere(
        (value) => value > Duration.zero,
      );
      return duration;
    } finally {
      await probe.dispose();
    }
  }

  void _rebuildClipOffsets() {
    _clipOffsets
      ..clear()
      ..addAll([
        Duration.zero,
        for (var i = 1; i < _clipDurations.length; i++)
          _clipDurations.take(i).fold(Duration.zero, (a, b) => a + b),
      ]);
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
    _state = newState;
    _onStateChanged?.call(newState);
  }

  void _handleError(Object error) {
    _emitState(
      _state.copyWith(status: PlaybackStatus.error, errorMessage: '$error'),
    );
    _onError?.call(error);
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
