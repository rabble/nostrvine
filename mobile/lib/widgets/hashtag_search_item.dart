// ABOUTME: Hashtag search result list item widget with usage stats and preview
// ABOUTME: Displays hashtag info with tap-to-feed and trending indicators

import 'package:flutter/material.dart';
import '../models/search_result.dart';

class HashtagSearchItem extends StatelessWidget {
  final HashtagSearchResult hashtag;
  final VoidCallback? onTap;
  final bool showUsageStats;
  final bool showThumbnails;

  const HashtagSearchItem({
    super.key,
    required this.hashtag,
    this.onTap,
    this.showUsageStats = true,
    this.showThumbnails = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Hashtag icon
            _buildHashtagIcon(),
            
            const SizedBox(width: 12),
            
            // Hashtag info
            Expanded(
              child: _buildHashtagInfo(),
            ),
            
            // Recent thumbnails
            if (showThumbnails && hashtag.recentVideoThumbnails.isNotEmpty)
              _buildThumbnailPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.tag,
        color: Colors.purple,
        size: 24,
      ),
    );
  }

  Widget _buildHashtagInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hashtag name
        Text(
          hashtag.hashtag,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 2),
        
        // Usage stats
        if (showUsageStats && hashtag.usageCount > 0) ...[
          Text(
            '${_formatCount(hashtag.usageCount)} posts',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          
          // Last used
          if (hashtag.lastUsed != null) ...[
            const SizedBox(height: 2),
            Text(
              'Last used ${_formatTimestamp(hashtag.lastUsed!)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ],
        
        // Trending indicator
        if (_isTrending())
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.orange,
                  size: 12,
                ),
                const SizedBox(width: 2),
                const Text(
                  'Trending',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailPreview() {
    final thumbnails = hashtag.recentVideoThumbnails.take(3).toList();
    
    return SizedBox(
      width: 80,
      height: 48,
      child: Stack(
        children: [
          // Background thumbnails
          for (int i = thumbnails.length - 1; i >= 0; i--)
            Positioned(
              right: i * 16.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.black,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    thumbnails[i],
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.videocam,
                          color: Colors.grey[500],
                          size: 16,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isTrending() {
    // Consider trending if usage count is high and recently used
    return hashtag.usageCount > 100 && 
           hashtag.lastUsed != null &&
           DateTime.now().difference(hashtag.lastUsed!).inHours < 24;
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
      return 'just now';
    }
  }
}

/// Compact hashtag search item for smaller lists or suggestions
class CompactHashtagSearchItem extends StatelessWidget {
  final HashtagSearchResult hashtag;
  final VoidCallback? onTap;

  const CompactHashtagSearchItem({
    super.key,
    required this.hashtag,
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
            // Small hashtag icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.tag,
                color: Colors.purple,
                size: 16,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Hashtag info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hashtag.hashtag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hashtag.usageCount > 0)
                    Text(
                      '${_formatCount(hashtag.usageCount)} posts',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}