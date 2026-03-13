import 'package:funnelcake_api_client/src/models/video_comment.dart';

/// The REST bootstrap payload returned for a video's comment list.
class VideoCommentsResponse {
  /// Creates a parsed response model for video comments.
  const VideoCommentsResponse({
    required this.comments,
    required this.total,
  });

  /// Parses the REST response body into a typed comments payload.
  factory VideoCommentsResponse.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'] as List<dynamic>? ?? const [];
    return VideoCommentsResponse(
      comments: rawComments
          .whereType<Map<String, dynamic>>()
          .map(VideoComment.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// The current page of comments returned by the API.
  final List<VideoComment> comments;

  /// The total number of comments known by the API.
  final int total;
}
