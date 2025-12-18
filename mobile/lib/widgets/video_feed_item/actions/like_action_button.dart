// ABOUTME: Like action button for video feed overlay.
// ABOUTME: Displays heart icon with like count, handles toggle like action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';

/// Like action button with count display for video overlay.
///
/// Shows a heart icon that toggles between filled (liked) and outline (not liked).
/// Displays the total like count combining Nostr likes and original Vine likes.
class LikeActionButton extends ConsumerWidget {
  const LikeActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialState = ref.watch(socialProvider);
    final isLiked = socialState.isLiked(video.id);
    final isLikeInProgress = socialState.isLikeInProgress(video.id);
    final likeCount = socialState.likeCounts[video.id] ?? 0;
    final totalLikes = likeCount + (video.originalLikes ?? 0);

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
                : () async {
                    Log.info(
                      '❤️ Like button tapped for ${video.id}',
                      name: 'LikeActionButton',
                      category: LogCategory.ui,
                    );
                    await ref
                        .read(socialProvider.notifier)
                        .toggleLike(video.id, video.pubkey);
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
  }
}
