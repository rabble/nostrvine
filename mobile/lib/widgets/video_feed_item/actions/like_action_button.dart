// ABOUTME: Like action button for video feed overlay.
// ABOUTME: Displays heart icon with like count, handles toggle like action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Like action button with count display for video overlay.
///
/// Shows a heart icon that toggles between filled (liked) and outline (not liked).
/// Displays the like count from the [VideoInteractionsBloc] once loaded.
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

    return BlocSelector<
      VideoInteractionsBloc,
      VideoInteractionsState,
      ({bool isLiked, bool isInProgress, int count})
    >(
      selector: (state) => (
        isLiked: state.isLiked,
        isInProgress: state.isLikeInProgress,
        count: state.likeCount ?? 0,
      ),
      builder: (context, data) {
        return _ActionButton(
          isLiked: data.isLiked,
          isLikeInProgress: data.isInProgress,
          totalLikes: data.count,
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
      icon: .heartDuo,
      semanticIdentifier: 'like_button',
      semanticLabel: isLiked
          ? context.l10n.videoActionUnlike
          : context.l10n.videoActionLike,
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
