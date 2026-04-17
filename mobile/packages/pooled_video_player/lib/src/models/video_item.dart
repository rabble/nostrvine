import 'package:equatable/equatable.dart';

/// Sentinel used by [VideoItem.copyWith] to distinguish "argument omitted"
/// from "argument explicitly set to `null`".
const Object _sentinel = Object();

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
  ///
  /// Passing `requestHeaders: null` explicitly clears the headers on the
  /// returned item. Omitting [requestHeaders] preserves the current value.
  /// This distinction matters when auth state changes (logout, expired
  /// session) and the caller needs to drop previously attached headers.
  VideoItem copyWith({
    String? id,
    String? url,
    Object? originalUrl = _sentinel,
    Object? requestHeaders = _sentinel,
  }) {
    return VideoItem(
      id: id ?? this.id,
      url: url ?? this.url,
      originalUrl: identical(originalUrl, _sentinel)
          ? this.originalUrl
          : originalUrl as String?,
      requestHeaders: identical(requestHeaders, _sentinel)
          ? this.requestHeaders
          : requestHeaders as Map<String, String>?,
    );
  }

  @override
  List<Object?> get props => [id];
}
