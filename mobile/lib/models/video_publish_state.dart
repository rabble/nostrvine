// ABOUTME: Immutable state model for video publish screen
// ABOUTME: Tracks playback state and video metadata

import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';

/// Immutable state for video publish screen.
class VideoPublishProviderState {
  /// Creates a video publish state.
  const VideoPublishProviderState({
    this.clip,
    this.isPlaying = true,
    this.isMuted = false,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.publishState = .idle,
    this.uploadProgress = 0,
  });

  /// The edited video to publish.
  final RecordingClip? clip;

  /// Whether video is currently playing.
  final bool isPlaying;

  /// Whether video audio is muted.
  final bool isMuted;

  /// Current playback position.
  final Duration currentPosition;

  /// Total video duration.
  final Duration totalDuration;

  /// Current publish state.
  final VideoPublishState publishState;

  final double uploadProgress;

  /// Creates a copy with updated fields.
  VideoPublishProviderState copyWith({
    RecordingClip? clip,
    bool? isPlaying,
    bool? isMuted,
    Duration? currentPosition,
    Duration? totalDuration,
    VideoPublishState? publishState,
    double? uploadProgress,
  }) {
    return VideoPublishProviderState(
      clip: clip ?? this.clip,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      publishState: publishState ?? this.publishState,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}
