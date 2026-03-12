import 'package:funnelcake_api_client/src/models/video_comment.dart';

class VideoCommentsResponse {
  const VideoCommentsResponse({
    required this.comments,
    required this.total,
  });

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

  final List<VideoComment> comments;
  final int total;
}
