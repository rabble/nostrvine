// ABOUTME: Like action button for video feed overlay.
// ABOUTME: Displays heart icon with like count, handles toggle like action.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';

/// Like action button with count display for video overlay.
///
/// Shows a heart icon that toggles between filled (liked) and outline (not liked).
/// Displays the total like count combining Nostr likes and original Vine likes.
///
/// Requires [VideoInteractionsBloc] to be provided in the widget tree.
/// Shows a disabled state when the bloc is not available.
class LikeActionButton extends StatelessWidget {
  const LikeActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final interactionsBloc = context.read<VideoInteractionsBloc?>();

    if (interactionsBloc == null) {
      // No bloc available - show disabled state with original likes only
      return _buildButton(
        context: context,
        isLiked: false,
        isLikeInProgress: false,
        totalLikes: video.originalLikes ?? 0,
        onPressed: null,
      );
    }

    return BlocBuilder<VideoInteractionsBloc, VideoInteractionsState>(
      builder: (context, state) {
        final isLiked = state.isLiked;
        final isLikeInProgress = state.isLikeInProgress;
        final likeCount = state.likeCount ?? 0;
        final totalLikes = likeCount + (video.originalLikes ?? 0);

        return _buildButton(
          context: context,
          isLiked: isLiked,
          isLikeInProgress: isLikeInProgress,
          totalLikes: totalLikes,
          onPressed: () {
            Log.info(
              '❤️ Like button tapped for ${video.id}',
              name: 'LikeActionButton',
              category: LogCategory.ui,
            );
            context.read<VideoInteractionsBloc>().add(
              const VideoInteractionsLikeToggled(),
            );
          },
        );
      },
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required bool isLiked,
    required bool isLikeInProgress,
    required int totalLikes,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'like_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: isLiked ? 'Unlike video' : 'Like video',
          child: CircularIconButton(
            onPressed: isLikeInProgress || onPressed == null
                ? () {}
                : onPressed,
            icon: isLikeInProgress
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isLiked ? Icons.favorite : Icons.favorite_outline,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 32,
                  ),
          ),
        ),
        // Show total like count: new likes + original Vine likes
        if (totalLikes > 0) ...[
          const SizedBox(height: 0),
          Text(
            StringUtils.formatCompactNumber(totalLikes),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 6,
                  color: Colors.black,
                ),
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
