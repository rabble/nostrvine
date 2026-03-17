// ABOUTME: Comment action button for video feed overlay.
// ABOUTME: Displays comment icon with count, navigates to comments screen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/screens/comments/comments.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Comment action button with count display for video overlay.
///
/// Shows a comment icon that navigates to the comments screen.
/// Uses [VideoInteractionsBloc] for live comment count.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class CommentActionButton extends ConsumerWidget {
  const CommentActionButton({
    required this.video,
    this.isPreviewMode = false,
    super.key,
  });

  final VideoEvent video;
  final bool isPreviewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isPreviewMode) return const _ActionButton();

    return BlocSelector<
      VideoInteractionsBloc,
      VideoInteractionsState,
      ({bool isInProgress, int count})
    >(
      selector: (state) => (
        isInProgress: state.isCommentsInProgress,
        count: state.commentCount ?? video.originalComments ?? 0,
      ),
      builder: (context, data) {
        return _ActionButton(
          isCommentsInProgress: data.isInProgress,
          totalComments: data.count,
          onPressed: () {
            Log.info(
              '💬 Comment button tapped for ${video.id}',
              name: 'VideoFeedItem',
              category: LogCategory.ui,
            );
            // Pause video before navigating to comments
            if (video.videoUrl != null) {
              try {
                final controllerParams = videoControllerParamsFor(
                  ref,
                  video,
                );
                final controller = ref.read(
                  individualVideoControllerProvider(controllerParams),
                );
                if (controller.value.isInitialized &&
                    controller.value.isPlaying) {
                  safePause(controller, video.id);
                }
              } catch (e) {
                final errorStr = e.toString().toLowerCase();
                if (!errorStr.contains('no active player') &&
                    !errorStr.contains('disposed')) {
                  Log.error(
                    'Failed to pause video before comments: $e',
                    name: 'VideoFeedItem',
                    category: LogCategory.video,
                  );
                }
              }
            }
            final interactionsBloc = context.read<VideoInteractionsBloc?>();
            CommentsScreen.show(
              context,
              video,
              initialCommentCount: data.count,
              onCommentCountChanged: interactionsBloc == null
                  ? null
                  : (count) {
                      if (!interactionsBloc.isClosed) {
                        interactionsBloc.add(
                          VideoInteractionsCommentCountUpdated(
                            count,
                          ),
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.onPressed,
    this.isCommentsInProgress = false,
    this.totalComments = 1,
  });

  final Function()? onPressed;
  final bool isCommentsInProgress;
  final int totalComments;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .chatDuo,
      semanticIdentifier: 'comments_button',
      semanticLabel: 'View comments',
      isLoading: isCommentsInProgress,
      count: totalComments,
      onPressed: onPressed,
    );
  }
}
