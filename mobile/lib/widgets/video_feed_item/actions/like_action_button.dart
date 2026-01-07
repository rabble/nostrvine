// ABOUTME: Like action button for video feed overlay.
// ABOUTME: Displays heart icon with like count, handles toggle like action.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/likes/likes_bloc.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';

/// Like action button with count display for video overlay.
///
/// Shows a heart icon that toggles between filled (liked) and outline (not liked).
/// Displays the total like count combining Nostr likes and original Vine likes.
///
/// Requires a [LikesBloc] to be provided in the widget tree.
class LikeActionButton extends StatefulWidget {
  const LikeActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  State<LikeActionButton> createState() => _LikeActionButtonState();
}

class _LikeActionButtonState extends State<LikeActionButton> {
  @override
  void initState() {
    super.initState();
    // Fetch like count when widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LikesBloc>().add(
          LikesCountFetchRequested(eventId: widget.video.id),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      LikesBloc,
      LikesState,
      ({bool isLiked, bool inProgress, int likeCount})
    >(
      selector: (state) => (
        isLiked: state.isLiked(widget.video.id),
        inProgress: state.isOperationInProgress(widget.video.id),
        likeCount: state.getLikeCount(widget.video.id),
      ),
      builder: (context, data) {
        final isLiked = data.isLiked;
        final isLikeInProgress = data.inProgress;
        final likeCount = data.likeCount;
        final totalLikes = likeCount + (widget.video.originalLikes ?? 0);

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
                onPressed: isLikeInProgress
                    ? () {}
                    : () {
                        Log.info(
                          '❤️ Like button tapped for ${widget.video.id}',
                          name: 'LikeActionButton',
                          category: LogCategory.ui,
                        );
                        context.read<LikesBloc>().add(
                          LikesToggleRequested(
                            eventId: widget.video.id,
                            authorPubkey: widget.video.pubkey,
                          ),
                        );
                      },
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
      },
    );
  }
}
