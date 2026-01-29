// ABOUTME: Immutable state model for video publish screen
// ABOUTME: Tracks playback state and video metadata

import 'package:openvine/models/video_publish/video_publish_state.dart';

/// Immutable state for video publish screen.
class VideoPublishProviderState {
  /// Creates a video publish state.
  const VideoPublishProviderState({
    this.publishState = .idle,
    this.uploadProgress = 0,
    this.errorMessage,
  });

  /// Current publish state.
  final VideoPublishState publishState;

  /// Upload progress as a value between 0.0 and 1.0.
  final double uploadProgress;

  /// User-friendly error message to display.
  final String? errorMessage;

  /// Creates a copy with updated fields.
  VideoPublishProviderState copyWith({
    VideoPublishState? publishState,
    double? uploadProgress,
    String? errorMessage,
  }) {
    return VideoPublishProviderState(
      publishState: publishState ?? this.publishState,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage == null
          ? this.errorMessage
          : errorMessage.isEmpty
          ? null
          : errorMessage,
    );
  }
}
