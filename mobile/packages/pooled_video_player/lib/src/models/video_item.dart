/// Represents a video item with metadata for playback.
///
/// Each video item has a unique [id] and a [url] pointing to the video source.
/// Optional [title], [description], and [thumbnailUrl] can be provided for
/// display purposes.
class VideoItem {
  /// Creates a video item with the given properties.
  const VideoItem({
    required this.id,
    required this.url,
    this.title,
    this.description,
    this.thumbnailUrl,
  });

  /// Unique identifier for this video.
  final String id;

  /// URL of the video source.
  final String url;

  /// Optional title for display.
  final String? title;

  /// Optional description for display.
  final String? description;

  /// Optional thumbnail URL to display while video is loading.
  final String? thumbnailUrl;
}
