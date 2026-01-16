// ABOUTME: Comment action button for video feed overlay.
// ABOUTME: Displays comment icon with count, navigates to comments screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';

/// Comment action button with count display for video overlay.
///
/// Shows a comment icon that navigates to the comments screen.
/// Pauses the video before navigation and displays the original comment count.
class CommentActionButton extends ConsumerWidget {
  const CommentActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'comments_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'View comments',
          child: CircularIconButton(
            onPressed: () => _onPressed(context, ref),
            icon: const Icon(
              Icons.comment_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        // Show original comment count if available
        if (video.originalComments != null && video.originalComments! > 0) ...[
          const SizedBox(height: 0),
          Text(
            StringUtils.formatCompactNumber(video.originalComments!),
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

  void _onPressed(BuildContext context, WidgetRef ref) {
    Log.info(
      '💬 Comment button tapped for ${video.id}',
      name: 'CommentActionButton',
      category: LogCategory.ui,
    );

    // Pause video before navigating to comments
    if (video.videoUrl != null) {
      try {
        final controllerParams = VideoControllerParams(
          videoId: video.id,
          videoUrl: video.videoUrl!,
          videoEvent: video,
        );
        final controller = ref.read(
          individualVideoControllerProvider(controllerParams),
        );
        if (controller.value.isInitialized && controller.value.isPlaying) {
          // Use safePause to handle disposed controller
          safePause(controller, video.id);
        }
      } catch (e) {
        // Ignore disposal errors, log others
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('no active player') &&
            !errorStr.contains('disposed')) {
          Log.error(
            'Failed to pause video before comments: $e',
            name: 'CommentActionButton',
            category: LogCategory.video,
          );
        }
      }
    }

    context.pushComments(video);
  }
}
