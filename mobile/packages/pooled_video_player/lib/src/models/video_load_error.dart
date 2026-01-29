import 'package:pooled_video_player/src/models/video_player_exceptions.dart';

/// Represents an error that occurred during video loading.
///
/// This model captures detailed information about preload failures,
/// including retry tracking for automatic recovery attempts.
class VideoLoadError {
  /// Creates a video load error with the given details.
  const VideoLoadError({
    required this.index,
    required this.videoId,
    required this.error,
    required this.timestamp,
    this.stackTrace,
    this.retryCount = 0,
  });

  /// The index of the video in the feed.
  final int index;

  /// The ID of the video that failed to load.
  final String videoId;

  /// The underlying error or exception.
  final Object error;

  /// Stack trace if available.
  final StackTrace? stackTrace;

  /// When the error occurred.
  final DateTime timestamp;

  /// Number of retry attempts made.
  final int retryCount;

  /// Creates a copy with incremented retry count and updated timestamp.
  VideoLoadError copyWithIncrementedRetry() {
    return VideoLoadError(
      index: index,
      videoId: videoId,
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      retryCount: retryCount + 1,
    );
  }

  /// Human-readable error message.
  String get message {
    if (error is VideoPlayerException) {
      return (error as VideoPlayerException).message;
    }
    return error.toString();
  }

  /// Whether this error is potentially recoverable.
  ///
  /// Returns true for transient errors like network issues or pool exhaustion,
  /// which may succeed on retry.
  bool get isRecoverable {
    if (error is PlayerPoolExhaustedException) return true;
    if (error is PreloadCancelledException) return true;

    // Network errors are typically recoverable
    final msg = error.toString().toLowerCase();
    return msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection') ||
        msg.contains('socket');
  }

  @override
  String toString() =>
      'VideoLoadError(index: $index, videoId: $videoId, '
      'retryCount: $retryCount, message: $message)';
}
