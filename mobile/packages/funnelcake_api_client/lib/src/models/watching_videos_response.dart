import 'package:models/models.dart';

/// Response model for the watching-sorted videos endpoint.
class WatchingVideosResponse {
  /// Creates a parsed response for a watching videos page.
  const WatchingVideosResponse({
    required this.videos,
    this.nextCursor,
    this.hasMore,
  });

  /// The videos returned for this page.
  final List<VideoStats> videos;

  /// Server-provided cursor for the next page when using v2 envelope
  /// pagination.
  final int? nextCursor;

  /// Server-provided "has more" flag from the v2 envelope.
  final bool? hasMore;
}
