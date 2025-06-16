// ABOUTME: Individual video feed item widget for displaying NIP-71 video events
// ABOUTME: Renders video content with user info, interactions, and metadata

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_event.dart';

/// Widget for displaying a single video event in the feed
class VideoFeedItem extends StatelessWidget {
  final VideoEvent videoEvent;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMoreOptions;
  final VoidCallback? onUserTap;
  
  const VideoFeedItem({
    super.key,
    required this.videoEvent,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMoreOptions,
    this.onUserTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Video/GIF content
          Positioned.fill(
            child: _buildVideoContent(),
          ),
          
          // Right side interaction panel
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _buildInteractionButton(
                  Icons.favorite_border,
                  '', // TODO: Get actual like count
                  onLike,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  Icons.chat_bubble_outline,
                  '', // TODO: Get actual comment count
                  onComment,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  Icons.share_outlined,
                  'Share',
                  onShare,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  Icons.more_horiz,
                  '',
                  onMoreOptions,
                ),
              ],
            ),
          ),
          
          // Bottom user info and caption
          Positioned(
            left: 12,
            bottom: 20,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey,
                      child: GestureDetector(
                        onTap: onUserTap,
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onUserTap,
                      child: Text(
                        '@${videoEvent.displayPubkey}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (videoEvent.title?.isNotEmpty == true) ...[
                  Text(
                    videoEvent.title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                if (videoEvent.content.isNotEmpty) ...[
                  Text(
                    _buildCaptionWithHashtags(videoEvent.content, videoEvent.hashtags),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    Text(
                      videoEvent.relativeTime,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    if (videoEvent.duration != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.timer, color: Colors.grey, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        videoEvent.formattedDuration,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoContent() {
    if (videoEvent.videoUrl == null || videoEvent.videoUrl!.isEmpty) {
      return _buildPlaceholder();
    }
    
    if (videoEvent.isGif) {
      return _buildGifContent();
    } else {
      return _buildVideoPlayer();
    }
  }
  
  Widget _buildGifContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: videoEvent.videoUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    // For now, show a placeholder with play button
    // TODO: Implement actual video player (video_player package)
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[900],
      ),
      child: Stack(
        children: [
          if (videoEvent.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: videoEvent.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              ),
            )
          else
            _buildPlaceholder(),
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 80,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 60,
              color: Colors.white54,
            ),
            SizedBox(height: 8),
            Text(
              'Video Content',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.red[900],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.white54,
            ),
            SizedBox(height: 8),
            Text(
              'Failed to load content',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInteractionButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _buildCaptionWithHashtags(String content, List<String> hashtags) {
    String caption = content;
    
    // Add hashtags if they're not already in the content
    if (hashtags.isNotEmpty) {
      final hashtagsText = hashtags.map((tag) => '#$tag').join(' ');
      if (!content.contains('#')) {
        caption = '$content $hashtagsText';
      }
    }
    
    return caption;
  }
}