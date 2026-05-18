import 'package:models/models.dart';

/// Response model for the v2 popular videos endpoint.
class V2PopularVideosResponse {
  /// Creates a parsed response for a v2 popular videos page.
  const V2PopularVideosResponse({
    required this.videos,
    this.nextCursor,
    this.hasMore,
  });

  /// Videos returned for this page.
  final List<VideoStats> videos;

  /// Opaque server cursor for the next page.
  final String? nextCursor;

  /// Server-provided "has more" flag from the v2 envelope.
  final bool? hasMore;
}
