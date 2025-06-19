// ABOUTME: Video search result list item widget with thumbnail and metadata
// ABOUTME: Displays video info with tap-to-play and creator profile access

import 'package:flutter/material.dart';
import '../models/search_result.dart';

class VideoSearchItem extends StatelessWidget {
  final VideoSearchResult video;
  final VoidCallback? onTap;
  final Function(String)? onCreatorTap;
  final bool showCreator;

  const VideoSearchItem({
    super.key,
    required this.video,
    this.onTap,
    this.onCreatorTap,
    this.showCreator = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video thumbnail
            _buildThumbnail(),
            
            const SizedBox(width: 12),
            
            // Video info
            Expanded(
              child: _buildVideoInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Thumbnail image
          if (video.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                video.thumbnailUrl!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultThumbnail();
                },
              ),
            )
          else
            _buildDefaultThumbnail(),
          
          // Play button overlay
          Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          
          // Duration badge
          if (video.duration != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(video.duration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.videocam,
        color: Colors.grey[500],
        size: 32,
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video title
        Text(
          video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 4),
        
        // Creator info
        if (showCreator)
          GestureDetector(
            onTap: () => onCreatorTap?.call(video.creatorPubkey),
            child: Text(
              video.creatorName,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        
        const SizedBox(height: 4),
        
        // Description preview
        if (video.description.isNotEmpty)
          Text(
            video.description,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        
        const SizedBox(height: 6),
        
        // Hashtags
        if (video.hashtags.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: video.hashtags.take(3).map((hashtag) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  hashtag,
                  style: const TextStyle(
                    color: Colors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            ).toList(),
          ),
        
        const SizedBox(height: 4),
        
        // View count and timestamp
        Row(
          children: [
            if (video.viewCount > 0) ...[
              Icon(
                Icons.visibility,
                color: Colors.grey[500],
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(
                _formatCount(video.viewCount),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _formatTimestamp(video.createdAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Compact video search item for smaller lists or suggestions
class CompactVideoSearchItem extends StatelessWidget {
  final VideoSearchResult video;
  final VoidCallback? onTap;

  const CompactVideoSearchItem({
    super.key,
    required this.video,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Small thumbnail
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(6),
              ),
              child: video.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        video.thumbnailUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.videocam,
                            color: Colors.grey[500],
                            size: 20,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.videocam,
                      color: Colors.grey[500],
                      size: 20,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // Video info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    video.creatorName,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}