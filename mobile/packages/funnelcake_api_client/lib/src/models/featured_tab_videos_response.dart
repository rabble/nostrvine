// ABOUTME: Response model for a page of featured tab videos.
// ABOUTME: Server order is authoritative — callers must not re-sort.

import 'package:models/models.dart';

/// A cursor-paginated page of videos for one featured tab.
///
/// The server returns curated videos first, then approved videos
/// newest-first. Callers render [videos] in the order received.
class FeaturedTabVideosResponse {
  /// Creates a parsed page of featured tab videos.
  const FeaturedTabVideosResponse({
    required this.videos,
    this.nextCursor,
    this.hasMore,
  });

  /// Videos for this page, in server-defined order.
  final List<VideoStats> videos;

  /// Opaque cursor for the next page, when one exists.
  final String? nextCursor;

  /// Server-provided "has more" flag from the pagination envelope.
  final bool? hasMore;
}
