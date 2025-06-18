// ABOUTME: Individual video feed item widget for displaying NIP-71 video events
// ABOUTME: Renders video content with user info, interactions, and metadata

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../services/video_cache_service.dart';
import '../services/user_profile_service.dart';

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
  final UserProfileService? userProfileService;
  
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
    this.userProfileService,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  final bool _showControls = false;
  bool _hasError = false;
  String? _errorMessage;

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
      
      // Implement timeout for video initialization to prevent indefinite hanging
      _initializeVideoWithTimeout();
      
      _controller!.setLooping(true);
      
      // Add to cache service if available
      if (widget.videoCacheService != null) {
        widget.videoCacheService!.addController(widget.videoEvent, _controller!);
      }
    }
  }
  
  void _initializeVideoWithTimeout() async {
    const timeoutDuration = Duration(seconds: 15); // Increased to 15 second timeout
    
    try {
      debugPrint('🎥 Initializing video with ${timeoutDuration.inSeconds}s timeout: ${widget.videoEvent.id.substring(0, 8)}...');
      debugPrint('📹 Video URL: ${widget.videoEvent.videoUrl}');
      
      // Race between initialization and timeout
      await Future.any([
        _controller!.initialize(),
        Future.delayed(timeoutDuration).then((_) => throw TimeoutException('Video initialization timeout after ${timeoutDuration.inSeconds} seconds', timeoutDuration)),
      ]);
      
      debugPrint('✅ Video initialized successfully: ${widget.videoEvent.id.substring(0, 8)}');
      if (mounted) {
        setState(() {});
        if (widget.isActive) {
          _playVideo();
        }
      }
    } catch (error) {
      debugPrint('❌ Video initialization failed: ${widget.videoEvent.id.substring(0, 8)} - $error');
      debugPrint('📱 Failed video URL: ${widget.videoEvent.videoUrl}');
      
      if (mounted) {
        setState(() {
          // Set controller to null to show error state
          _controller?.dispose();
          _controller = null;
          _hasError = true;
          _errorMessage = error.toString();
        });
      }
      
      // Remove from cache if it was added
      if (widget.videoCacheService != null) {
        debugPrint('🗑️ Removing failed video from cache: ${widget.videoEvent.id.substring(0, 8)}');
        widget.videoCacheService!.removeController(widget.videoEvent);
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
      debugPrint('▶️ Playing video ${widget.videoEvent.id.substring(0, 8)}... (isActive: ${widget.isActive})');
      
      // Use cache service to coordinate playback if available
      if (widget.videoCacheService != null) {
        widget.videoCacheService!.playVideo(widget.videoEvent);
      } else {
        _controller!.play();
      }
      
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      debugPrint('⏸️ Pausing video ${widget.videoEvent.id.substring(0, 8)}... (isActive: ${widget.isActive})');
      
      // Use cache service to coordinate playback if available
      if (widget.videoCacheService != null) {
        widget.videoCacheService!.pauseVideo(widget.videoEvent);
      } else {
        _controller!.pause();
      }
      
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
                    _buildUserAvatar(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onUserTap,
                        child: Text(
                          _getUserDisplayName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    return Center(
      child: CachedNetworkImage(
        imageUrl: widget.videoEvent.videoUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    // Show error state if video failed to load
    if (_hasError) {
      return _buildErrorWidget();
    }
    
    if (_controller != null && _controller!.value.isInitialized) {
      return Stack(
        children: [
          // Center the video and fit it to screen while maintaining aspect ratio
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.white54,
              ),
              const SizedBox(height: 8),
              const Text(
                'Failed to load video',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!.contains('timeout') ? 'Connection timeout' : 'Loading error',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                  });
                  _initializeVideo();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
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
  
  /// Build user avatar with profile picture or fallback
  Widget _buildUserAvatar() {
    final profile = widget.userProfileService?.getCachedProfile(widget.videoEvent.pubkey);
    final avatarUrl = profile?.picture;
    
    return GestureDetector(
      onTap: widget.onUserTap,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[700],
        backgroundImage: (avatarUrl?.isNotEmpty == true) 
            ? CachedNetworkImageProvider(avatarUrl!) 
            : null,
        child: (avatarUrl?.isEmpty != false) 
            ? const Icon(Icons.person, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
  
  /// Get user display name from profile or fallback
  String _getUserDisplayName() {
    final profile = widget.userProfileService?.getCachedProfile(widget.videoEvent.pubkey);
    
    if (profile != null) {
      return '@${profile.bestDisplayName}';
    }
    
    // Fallback to shortened pubkey
    return '@${widget.videoEvent.displayPubkey}';
  }
}