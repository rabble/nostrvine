// ABOUTME: Like action button for video feed overlay.
// ABOUTME: Displays heart icon with like count, handles toggle like action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Like action button with count display for video overlay.
///
/// Shows a heart icon that toggles between filled (liked) and outline (not liked).
/// Displays the total like count combining Nostr likes and original Vine likes.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
class LikeActionButton extends StatelessWidget {
  const LikeActionButton({
    required this.video,
    super.key,
    this.isPreviewMode = false,
  });

  final VideoEvent video;
  final bool isPreviewMode;

  @override
  Widget build(BuildContext context) {
    if (isPreviewMode) return const _ActionButton();

    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final isLiked = state.isLiked;
        final likeCount = state.likeCount ?? 0;
        final totalLikes = likeCount + (video.originalLikes ?? 0);

        return _ActionButton(
          isLiked: isLiked,
          isLikeInProgress: state.isLikeInProgress,
          totalLikes: totalLikes,
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.isLiked = false,
    this.isLikeInProgress = false,
    this.totalLikes = 1,
  });

  final bool isLiked;
  final bool isLikeInProgress;
  final int totalLikes;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      iconAsset: 'assets/icon/content-controls/like.svg',
      semanticIdentifier: 'like_button',
      semanticLabel: isLiked ? 'Unlike video' : 'Like video',
      iconColor: isLiked ? VineTheme.likeRed : VineTheme.whiteText,
      isLoading: isLikeInProgress,
      count: totalLikes,
      onPressed: () {
        context.read<VideoInteractionsBloc>().add(
          const VideoInteractionsLikeToggled(),
        );
      },
    );
  }
}
