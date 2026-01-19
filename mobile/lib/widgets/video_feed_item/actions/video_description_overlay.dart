// ABOUTME: Video description overlay for video feed.
// ABOUTME: Shows video title/content with clickable hashtags and loop count.

import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';

/// Video description overlay showing title/content and loop count.
///
/// Displays the video content or title with clickable hashtags.
/// Also shows the original loop count if available.
class VideoDescriptionOverlay extends StatelessWidget {
  const VideoDescriptionOverlay({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video title with clickable hashtags
          Semantics(
            identifier: 'video_description',
            container: true,
            explicitChildNodes: true,
            label: 'Video description',
            child: ClickableHashtagText(
              text: video.content.isNotEmpty ? video.content : video.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.3,
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 8,
                    color: Colors.black,
                  ),
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black,
                  ),
                ],
              ),
              hashtagStyle: TextStyle(
                color: VineTheme.vineGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.3,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 8,
                    color: Colors.black,
                  ),
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black,
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          // Show original loop count if available
          if (video.originalLoops != null && video.originalLoops! > 0) ...[
            Semantics(
              identifier: 'loop_count',
              container: true,
              explicitChildNodes: true,
              label: 'Video loop count',
              child: Text(
                '🔁 ${StringUtils.formatCompactNumber(video.originalLoops!)} loops',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}
