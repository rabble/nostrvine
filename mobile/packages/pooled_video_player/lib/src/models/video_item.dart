import 'package:equatable/equatable.dart';

/// Represents a video item with metadata for playback.
///
/// Each video item has a unique [id] and a [url] pointing to the video source.
///
/// Two [VideoItem]s are considered equal if they have the same [id].
class VideoItem extends Equatable {
  /// Creates a video item with the given properties.
  const VideoItem({
    required this.id,
    required this.url,
  });

  /// Unique identifier for this video.
  final String id;

  /// URL of the video source.
  final String url;

  @override
  List<Object?> get props => [id];
}
