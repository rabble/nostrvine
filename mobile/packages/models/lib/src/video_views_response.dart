import 'package:meta/meta.dart';

/// Response from the video views endpoint.
///
/// Contains the view count for a single video.
@immutable
class VideoViewsResponse {
  /// Creates a new [VideoViewsResponse].
  const VideoViewsResponse({required this.views});

  /// The number of views for this video.
  final int views;
}
