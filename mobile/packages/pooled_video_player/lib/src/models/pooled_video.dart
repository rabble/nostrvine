/// Interface for videos compatible with the controller pool.
abstract interface class PooledVideo {
  /// Unique identifier for pool key management.
  String get id;

  /// Playable video URL.
  String get videoUrl;

  /// Optional thumbnail URL for loading states.
  String? get thumbnailUrl;
}
