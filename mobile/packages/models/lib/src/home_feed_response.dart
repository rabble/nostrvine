import 'package:models/src/video_stats.dart';

/// Response from the home feed endpoint.
///
/// Contains a list of [VideoStats] and pagination metadata
/// for cursor-based pagination via the `before` parameter.
class HomeFeedResponse {
  /// Creates a new [HomeFeedResponse].
  const HomeFeedResponse({
    required this.videos,
    this.nextCursor,
    this.hasMore = false,
  });

  /// The videos in this page of the feed.
  final List<VideoStats> videos;

  /// Unix timestamp cursor for fetching the next page.
  ///
  /// Pass this as the `before` parameter to get the next page.
  /// `null` if there are no more pages.
  final int? nextCursor;

  /// Whether there are more videos to load.
  final bool hasMore;
}
