// ABOUTME: Comment action button for video feed overlay.
// ABOUTME: Displays comment icon with count, navigates to comments screen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Comment action button with count display for video overlay.
///
/// Shows a comment icon that navigates to the comments screen.
/// Uses [VideoInteractionsBloc] for live comment count.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class CommentActionButton extends StatelessWidget {
  const CommentActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final totalComments = state.commentCount ?? video.originalComments ?? 0;

        return VideoActionButton(
          iconAsset: 'assets/icon/content-controls/comment.svg',
          semanticIdentifier: 'comments_button',
          semanticLabel: 'View comments',
          count: totalComments,
          onPressed: () {
            CommentsScreen.show(
              context,
              video,
              initialCommentCount: totalComments,
            );
          },
        );
      },
    );
  }
}
