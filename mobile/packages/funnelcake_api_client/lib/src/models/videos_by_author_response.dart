import 'package:models/models.dart';

/// Response model for the author videos endpoint
/// (`/api/users/:pubkey/videos`).
///
/// Pairs the paginated video results with the total count reported by the
/// `X-Total-Count` response header so callers can drive infinite-scroll UI.
class VideosByAuthorResponse {
  /// Creates a parsed response for an author videos page.
  const VideosByAuthorResponse({
    required this.videos,
    this.totalCount,
  });

  /// The videos returned for this page.
  final List<VideoStats> videos;

  /// Total number of videos by this author (from `X-Total-Count` header).
  ///
  /// May be `null` if the server does not include the header.
  final int? totalCount;
}
