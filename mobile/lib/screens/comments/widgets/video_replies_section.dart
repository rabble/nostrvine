// ABOUTME: Horizontal scrollable row of video reply thumbnails.
// ABOUTME: Shown at top of comments list when video comments exist.
// ABOUTME: NOT gated by feature flag — always shows existing video comments.

import 'package:comments_repository/comments_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';

/// Horizontal scrollable row of video reply thumbnails.
///
/// Displayed at the top of the comments list when video comments
/// exist. Tap a thumbnail to expand/play. NOT gated by feature
/// flag — always renders if video comments are present.
class VideoRepliesSection extends StatelessWidget {
  const VideoRepliesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CommentsBloc, CommentsState, List<Comment>>(
      selector: (state) => state.comments.where((c) => c.hasVideo).toList(),
      builder: (context, videoComments) {
        if (videoComments.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text(
                'Video Replies',
                style: VineTheme.bodyFont(
                  fontSize: 14,
                  color: VineTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: videoComments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final comment = videoComments[index];
                  return SizedBox(
                    width: 90,
                    child: VideoCommentPlayer(
                      videoUrl: comment.videoUrl!,
                      thumbnailUrl: comment.thumbnailUrl,
                      blurhash: comment.videoBlurhash,
                    ),
                  );
                },
              ),
            ),
            const Divider(color: VineTheme.containerLow, height: 1),
          ],
        );
      },
    );
  }
}
