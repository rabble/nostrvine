import 'package:flutter/widgets.dart';

/// Playback status of the video player.
enum PlaybackStatus {
  /// Player is created but has no media loaded.
  idle,

  /// Media is loaded and ready to play.
  ready,

  /// Actively playing.
  playing,

  /// Paused by user.
  paused,

  /// Temporarily buffering.
  buffering,

  /// Reached the end of all clips.
  completed,

  /// An error occurred.
  error
  ;

  /// Whether the player is in the [idle] state.
  bool get isIdle => this == .idle;

  /// Whether the player is in the [ready] state.
  bool get isReady => this == .ready;

  /// Whether the player is in the [playing] state.
  bool get isPlaying => this == .playing;

  /// Whether the player is in the [paused] state.
  bool get isPaused => this == .paused;

  /// Whether the player is in the [buffering] state.
  bool get isBuffering => this == .buffering;

  /// Whether the player is in the [completed] state.
  bool get isCompleted => this == .completed;

  /// Whether the player is in the [error] state.
  bool get hasError => this == .error;
}

/// Immutable snapshot of the video player's current state.
@immutable
class DivineVideoPlayerState {
  /// Creates a player state.
  const DivineVideoPlayerState({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.currentClipIndex = 0,
    this.clipCount = 0,
    this.isLooping = false,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isFirstFrameRendered = false,
    this.videoWidth = 0,
    this.videoHeight = 0,
    this.rotationDegrees = 0,
  });

  /// Current playback status.
  final PlaybackStatus status;

  /// Current position on the global timeline.
  final Duration position;

  /// Total duration of the combined timeline.
  final Duration duration;

  /// How far ahead the player has buffered on the global timeline.
  ///
  /// Useful for rendering a buffer indicator in a progress bar.
  final Duration bufferedPosition;

  /// Index of the currently playing clip.
  final int currentClipIndex;

  /// Total number of clips.
  final int clipCount;

  /// Whether the player loops back to the start after completion.
  final bool isLooping;

  /// Current volume (0.0 to 1.0).
  final double volume;

  /// Current playback speed multiplier.
  final double playbackSpeed;

  /// Whether the first video frame has been rendered to the surface.
  ///
  /// On Android this is triggered by `onRenderedFirstFrame`, on iOS and
  /// macOS by `AVPlayerLayer.isReadyForDisplay` becoming `true`.
  /// Use this (not [PlaybackStatus.ready]) to decide when to hide a
  /// thumbnail placeholder.
  final bool isFirstFrameRendered;

  /// Width of the video in pixels, or 0 if unknown.
  final int videoWidth;

  /// Height of the video in pixels, or 0 if unknown.
  final int videoHeight;

  /// Rotation in degrees (0, 90, 180, 270) that the Dart layer must apply
  /// to the [Texture] widget to show the video upright.
  ///
  /// Non-zero only when the `SurfaceProducer` backend does not handle crop
  /// and rotation automatically (i.e. when the SurfaceTexture path is used
  /// instead of Impeller/ImageReader). When the backend handles it, the
  /// native side sends 0 and no [RotatedBox] is needed.
  final int rotationDegrees;

  /// The aspect ratio of the video (width / height).
  ///
  /// Returns 0 when dimensions are not yet available.
  double get aspectRatio =>
      videoWidth > 0 && videoHeight > 0 ? videoWidth / videoHeight : 0;

  /// Whether the player is currently playing.
  bool get isPlaying => status.isPlaying;

  /// Creates a copy with the given fields replaced.
  DivineVideoPlayerState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    int? currentClipIndex,
    int? clipCount,
    bool? isLooping,
    double? volume,
    double? playbackSpeed,
    bool? isFirstFrameRendered,
    int? videoWidth,
    int? videoHeight,
    int? rotationDegrees,
  }) {
    return DivineVideoPlayerState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      clipCount: clipCount ?? this.clipCount,
      isLooping: isLooping ?? this.isLooping,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isFirstFrameRendered: isFirstFrameRendered ?? this.isFirstFrameRendered,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }

  /// Deserializes a state from a platform channel map.
  // ignore: prefer_constructors_over_static_methods
  static DivineVideoPlayerState fromMap(Map<Object?, Object?> map) {
    return DivineVideoPlayerState(
      status: _parseStatus(map['status'] as String? ?? 'idle'),
      position: Duration(milliseconds: (map['positionMs'] as int?) ?? 0),
      duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
      bufferedPosition: Duration(
        milliseconds: (map['bufferedPositionMs'] as int?) ?? 0,
      ),
      currentClipIndex: (map['currentClipIndex'] as int?) ?? 0,
      clipCount: (map['clipCount'] as int?) ?? 0,
      isLooping: (map['isLooping'] as bool?) ?? false,
      volume: (map['volume'] as double?) ?? 1.0,
      playbackSpeed: (map['playbackSpeed'] as double?) ?? 1.0,
      isFirstFrameRendered: (map['isFirstFrameRendered'] as bool?) ?? false,
      videoWidth: (map['videoWidth'] as int?) ?? 0,
      videoHeight: (map['videoHeight'] as int?) ?? 0,
      rotationDegrees: (map['rotationDegrees'] as int?) ?? 0,
    );
  }

  static PlaybackStatus _parseStatus(String value) {
    return switch (value) {
      'idle' => PlaybackStatus.idle,
      'ready' => PlaybackStatus.ready,
      'playing' => PlaybackStatus.playing,
      'paused' => PlaybackStatus.paused,
      'buffering' => PlaybackStatus.buffering,
      'completed' => PlaybackStatus.completed,
      'error' => PlaybackStatus.error,
      _ => PlaybackStatus.idle,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DivineVideoPlayerState &&
          status == other.status &&
          position == other.position &&
          duration == other.duration &&
          bufferedPosition == other.bufferedPosition &&
          currentClipIndex == other.currentClipIndex &&
          clipCount == other.clipCount &&
          isLooping == other.isLooping &&
          volume == other.volume &&
          playbackSpeed == other.playbackSpeed &&
          isFirstFrameRendered == other.isFirstFrameRendered &&
          videoWidth == other.videoWidth &&
          videoHeight == other.videoHeight &&
          rotationDegrees == other.rotationDegrees;

  @override
  int get hashCode => Object.hash(
    status,
    position,
    duration,
    bufferedPosition,
    currentClipIndex,
    clipCount,
    isLooping,
    volume,
    playbackSpeed,
    isFirstFrameRendered,
    videoWidth,
    videoHeight,
    rotationDegrees,
  );

  @override
  String toString() =>
      'DivineVideoPlayerState(status: $status, position: $position, '
      'duration: $duration, buffered: $bufferedPosition, '
      'clipIndex: $currentClipIndex/$clipCount, '
      'size: ${videoWidth}x$videoHeight, '
      'rotation: $rotationDegrees, '
      'firstFrame: $isFirstFrameRendered)';
}
