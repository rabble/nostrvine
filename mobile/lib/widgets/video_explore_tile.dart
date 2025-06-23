// ABOUTME: Simple video thumbnail tile for explore screen
// ABOUTME: Shows thumbnail with play button - full screen handled by parent

import 'package:flutter/material.dart';
import '../models/video_event.dart';

/// Video thumbnail tile for explore screen
/// - Shows thumbnail with play button
/// - Parent screen handles full-screen overlay when tapped
class VideoExploreTile extends StatelessWidget {
  final VideoEvent video;
  final bool isActive; // Not used anymore but kept for API compatibility
  final VoidCallback? onTap;
  final VoidCallback? onClose; // Not used anymore but kept for API compatibility

  const VideoExploreTile({
    super.key,
    required this.video,
    required this.isActive,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail image
              if (video.effectiveThumbnailUrl != null)
                Image.network(
                  video.effectiveThumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              // Play button overlay
              const Center(
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white70,
                  size: 48,
                ),
              ),

              // Video info overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (video.title != null)
                        Text(
                          video.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (video.hashtags.isNotEmpty)
                        Text(
                          video.hashtags.map((tag) => '#$tag').join(' '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}