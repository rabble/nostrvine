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
    this.rawBody,
  });

  /// The videos in this page of the feed.
  final List<VideoStats> videos;

  /// Unix-timestamp cursor for fetching the next page.
  ///
  /// This is the `created_at` (Unix seconds) of the last video in the page,
  /// echoed back as the numeric `before` query parameter to fetch the next
  /// page. `null` when there are no more pages.
  ///
  /// The legacy `/api/users/{pubkey}/feed` endpoint is the only feed route
  /// (there is no v2 feed envelope), and its cursor is numeric — not the
  /// opaque `o:`/`t:`-prefixed cursor used by the v2 list endpoints. If
  /// divine-funnelcake#320 ever unifies all endpoints onto an opaque cursor,
  /// this field becomes `null` (an opaque string fails `int.tryParse`).
  /// `VideosRepository` then derives the next page from the oldest video's
  /// `created_at` and keeps paginating via the numeric `before` param, so the
  /// feed continues to work as long as the backend still accepts `before`.
  /// Update this field and the `int.tryParse` parse site in
  /// `FunnelcakeApiClient.getHomeFeed` together if that param is ever dropped.
  /// See divine-mobile#3545.
  final int? nextCursor;

  /// Whether there are more videos to load.
  final bool hasMore;

  /// The raw JSON response body, if available.
  ///
  /// Populated by the API client so callers can cache the response
  /// for instant display on next cold start. Not included in equality
  /// checks.
  final String? rawBody;
}
