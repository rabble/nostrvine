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
    this.originalUrl,
    this.requestHeaders,
  });

  /// Unique identifier for this video.
  final String id;

  /// URL of the video source (may be a platform-optimized derivative).
  final String url;

  /// Original source URL from the event, used as a last-resort fallback
  /// when all derived URLs fail.
  final String? originalUrl;

  /// Request headers applied when opening this media source.
  ///
  /// These headers are forwarded to `media_kit` for the current source and
  /// any derived fallback sources loaded for this item.
  final Map<String, String>? requestHeaders;

  /// Creates a copy with updated properties.
  VideoItem copyWith({
    String? id,
    String? url,
    String? originalUrl,
    Map<String, String>? requestHeaders,
  }) {
    return VideoItem(
      id: id ?? this.id,
      url: url ?? this.url,
      originalUrl: originalUrl ?? this.originalUrl,
      requestHeaders: requestHeaders ?? this.requestHeaders,
    );
  }

  @override
  List<Object?> get props => [id];
}
