import 'package:funnelcake_api_client/src/models/video_comment.dart';

/// The REST bootstrap payload returned for a video's comment list.
class VideoCommentsResponse {
  /// Creates a parsed response model for video comments.
  const VideoCommentsResponse({
    required this.comments,
    required this.total,
    this.hasMore,
    this.hasExactTotal = true,
  });

  /// Parses the REST response body into a typed comments payload.
  factory VideoCommentsResponse.fromJson(
    Map<String, dynamic> json, {
    int offset = 0,
  }) {
    final rawComments =
        (json['comments'] ?? json['data']) as List<dynamic>? ?? const [];
    final comments = rawComments
        .whereType<Map<String, dynamic>>()
        .map(VideoComment.fromJson)
        .toList();
    final rawTotal = json['total'];
    final pagination = json['pagination'];
    final hasMore =
        pagination is Map<String, dynamic> && pagination['has_more'] == true;
    final hasExactTotal = rawTotal is num;

    return VideoCommentsResponse(
      comments: comments,
      total: hasExactTotal ? rawTotal.toInt() : offset + comments.length,
      hasMore: pagination is Map<String, dynamic> ? hasMore : null,
      hasExactTotal: hasExactTotal,
    );
  }

  /// The current page of comments returned by the API.
  final List<VideoComment> comments;

  /// Exact comment count for legacy responses, or the lower bound implied by a
  /// v2 page response.
  final int total;

  /// Whether the API says another page is available.
  final bool? hasMore;

  /// Whether [total] is an exact server count rather than a pagination lower
  /// bound.
  final bool hasExactTotal;
}
