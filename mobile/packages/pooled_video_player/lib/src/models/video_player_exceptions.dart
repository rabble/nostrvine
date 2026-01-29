/// Base exception for all video player errors.
abstract class VideoPlayerException implements Exception {
  /// Creates a video player exception with the given message and optional
  /// cause.
  const VideoPlayerException(this.message, [this.cause]);

  /// A human-readable description of the error.
  final String message;

  /// The underlying error that caused this exception, if any.
  final Object? cause;

  @override
  String toString() => 'VideoPlayerException: $message';
}

/// Thrown when the player pool has no available players and eviction failed.
class PlayerPoolExhaustedException extends VideoPlayerException {
  /// Creates a pool exhausted exception with details about the pool state.
  const PlayerPoolExhaustedException({
    required this.totalPlayers,
    required this.maxPlayers,
    required this.inUse,
    required this.available,
    Object? cause,
  }) : super(
         'Player pool exhausted. Total: $totalPlayers, max: $maxPlayers, '
         'in use: $inUse, available: $available',
         cause,
       );

  /// Total number of players currently managed by the pool.
  final int totalPlayers;

  /// Maximum number of players allowed.
  final int maxPlayers;

  /// Number of players currently in use.
  final int inUse;

  /// Number of players available in the pool.
  final int available;

  @override
  String toString() => 'PlayerPoolExhaustedException: $message';
}

/// Thrown when video loading fails (network error, invalid URL, codec issue).
class VideoLoadFailedException extends VideoPlayerException {
  /// Creates a video load failed exception with details about the video.
  const VideoLoadFailedException({
    required this.videoId,
    required this.url,
    required this.reason,
    Object? cause,
  }) : super('Failed to load video "$videoId": $reason', cause);

  /// The ID of the video that failed to load.
  final String videoId;

  /// The URL that was attempted.
  final String url;

  /// Human-readable reason for the failure.
  final String reason;

  @override
  String toString() => 'VideoLoadFailedException: $message';
}

/// Thrown when preload is cancelled (e.g., user scrolled away).
class PreloadCancelledException extends VideoPlayerException {
  /// Creates a preload cancelled exception with details.
  const PreloadCancelledException({
    required this.index,
    required this.videoId,
    String? reason,
  }) : _reason = reason,
       super(
         'Preload cancelled for video at index $index ($videoId)'
         '${reason != null ? ": $reason" : ""}',
       );

  /// The index of the video that was being preloaded.
  final int index;

  /// The ID of the video that was being preloaded.
  final String videoId;

  final String? _reason;

  /// The reason for cancellation, if provided.
  String? get reason => _reason;

  @override
  String toString() => 'PreloadCancelledException: $message';
}

/// Thrown when an operation is attempted on a disposed controller.
class ControllerDisposedException extends VideoPlayerException {
  /// Creates a controller disposed exception.
  const ControllerDisposedException(String controllerName)
    : super('$controllerName has been disposed');

  @override
  String toString() => 'ControllerDisposedException: $message';
}
