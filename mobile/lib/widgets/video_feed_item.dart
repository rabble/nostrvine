// ABOUTME: Individual video feed item widget for displaying NIP-71 video events
// ABOUTME: Renders video content with user info, interactions, and metadata

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../services/video_cache_service.dart';

/// Widget for displaying a single video event in the feed
class VideoFeedItem extends StatefulWidget {
  final VideoEvent videoEvent;
  final bool isActive;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMoreOptions;
  final VoidCallback? onUserTap;
  final VideoCacheService? videoCacheService;
  
  const VideoFeedItem({
    super.key,
    required this.videoEvent,
    this.isActive = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMoreOptions,
    this.onUserTap,
    this.videoCacheService,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
  }

  @override
  void dispose() {
    // Only dispose controller if it's not managed by the cache service
    if (_controller != null && widget.videoCacheService?.getController(widget.videoEvent) == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  void _initializeVideo() {
    if (widget.videoEvent.videoUrl != null && 
        widget.videoEvent.videoUrl!.isNotEmpty && 
        !widget.videoEvent.isGif) {
      
      // First check if we have a cached controller
      final cachedController = widget.videoCacheService?.getController(widget.videoEvent);
      if (cachedController != null) {
        debugPrint('🎥 Using cached controller for video: ${widget.videoEvent.id.substring(0, 8)}...');
        _controller = cachedController;
        
        if (_controller!.value.isInitialized) {
          if (mounted) {
            setState(() {});
            if (widget.isActive) {
              _playVideo();
            }
          }
        } else {
          // Wait for cached controller to initialize
          _controller!.addListener(_onControllerUpdate);
        }
        return;
      }
      
      // Create new controller if not cached
      debugPrint('🎥 Creating new controller for video: ${widget.videoEvent.id.substring(0, 8)}...');
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoEvent.videoUrl!),
      );
      
      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          if (widget.isActive) {
            _playVideo();
          }
        }
      }).catchError((error) {
        debugPrint('Video initialization error: $error');
      });

      _controller!.setLooping(true);
      
      // Add to cache service if available
      if (widget.videoCacheService != null) {
        widget.videoCacheService!.addController(widget.videoEvent, _controller!);
      }
    }
  }
  
  void _onControllerUpdate() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.removeListener(_onControllerUpdate);
      if (mounted) {
        setState(() {});
        if (widget.isActive) {
          _playVideo();
        }
      }
    }
  }

  void _playVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isInitialized) {
      if (_isPlaying) {
        _pauseVideo();
      } else {
        _playVideo();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Stack(
        children: [
          // Video/GIF content
          Positioned.fill(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: _buildVideoContent(),
            ),
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
                  widget.onLike,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  Icons.chat_bubble_outline,
                  '', // TODO: Get actual comment count
                  widget.onComment,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  Icons.share_outlined,
                  'Share',
                  widget.onShare,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  Icons.more_horiz,
                  '',
                  widget.onMoreOptions,
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
                        onTap: widget.onUserTap,
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onUserTap,
                      child: Text(
                        '@${widget.videoEvent.displayPubkey}',
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
                        color: Colors.purple.withValues(alpha: 0.3),
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
                if (widget.videoEvent.title?.isNotEmpty == true) ...[
                  Text(
                    widget.videoEvent.title!,
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
                if (widget.videoEvent.content.isNotEmpty) ...[
                  Text(
                    _buildCaptionWithHashtags(widget.videoEvent.content, widget.videoEvent.hashtags),
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
                      widget.videoEvent.relativeTime,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    if (widget.videoEvent.duration != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.timer, color: Colors.grey, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        widget.videoEvent.formattedDuration,
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
    if (widget.videoEvent.videoUrl == null || widget.videoEvent.videoUrl!.isEmpty) {
      return _buildPlaceholder();
    }
    
    if (widget.videoEvent.isGif) {
      return _buildGifContent();
    } else {
      return _buildVideoPlayer();
    }
  }
  
  Widget _buildGifContent() {
    return CachedNetworkImage(
      imageUrl: widget.videoEvent.videoUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );
  }
  
  Widget _buildVideoPlayer() {
    if (_controller != null && _controller!.value.isInitialized) {
      return Stack(
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          // Show play/pause overlay when not playing or when showing controls
          if (!_isPlaying || _showControls)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    }
    
    // Show loading or thumbnail while video initializes
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[900],
      ),
      child: Stack(
        children: [
          if (widget.videoEvent.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.videoEvent.thumbnailUrl!,
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
            child: CircularProgressIndicator(
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
              color: Colors.black.withValues(alpha: 0.4),
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