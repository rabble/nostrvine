import 'package:models/models.dart';

/// Response model for the video search endpoint (`/api/search`).
///
/// Pairs the paginated video results with the total count reported by the
/// `X-Total-Count` response header so callers can drive infinite-scroll UI.
class VideoSearchResponse {
  /// Creates a parsed response for a video search page.
  const VideoSearchResponse({
    required this.videos,
    required this.totalCount,
  });

  /// The videos returned for this page.
  final List<VideoStats> videos;

  /// Total number of videos matching the query (from `X-Total-Count` header).
  final int totalCount;
}
