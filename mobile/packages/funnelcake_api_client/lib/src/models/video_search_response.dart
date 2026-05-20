import 'package:models/models.dart';

/// Response model for the video search endpoint (`/api/v2/search`).
class VideoSearchResponse {
  /// Creates a parsed response for a video search page.
  const VideoSearchResponse({
    required this.videos,
    required this.totalCount,
    this.hasMore = false,
  });

  /// The videos returned for this page.
  final List<VideoStats> videos;

  /// Total number of videos matching the query when the API reports it.
  final int totalCount;

  /// Whether another server page is available.
  final bool hasMore;
}
