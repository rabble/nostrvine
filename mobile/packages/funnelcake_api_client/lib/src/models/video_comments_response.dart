import 'package:funnelcake_api_client/src/models/video_comment.dart';

/// The REST bootstrap payload returned for a video's comment list.
class VideoCommentsResponse {
  /// Creates a parsed response model for video comments.
  const VideoCommentsResponse({
    required this.comments,
    required this.total,
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

    return VideoCommentsResponse(
      comments: comments,
      total: rawTotal is num
          ? rawTotal.toInt()
          : offset + comments.length + (hasMore ? 1 : 0),
    );
  }

  /// The current page of comments returned by the API.
  final List<VideoComment> comments;

  /// The total number of comments known by the API.
  final int total;
}
