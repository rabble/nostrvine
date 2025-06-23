// ABOUTME: Full-screen video overlay for explore screen with proper scaling
// ABOUTME: Displays video at full width with interaction buttons and smooth transitions

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:nostr_sdk/event.dart';
import '../models/video_event.dart';
import '../theme/vine_theme.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../screens/comments_screen.dart';
import '../widgets/share_video_menu.dart';

/// Full-screen overlay that displays video with proper scaling and interactions
class VideoFullscreenOverlay extends StatefulWidget {
  final VideoEvent video;
  final VoidCallback onClose;

  const VideoFullscreenOverlay({
    super.key,
    required this.video,
    required this.onClose,
  });

  @override
  State<VideoFullscreenOverlay> createState() => _VideoFullscreenOverlayState();
}

class _VideoFullscreenOverlayState extends State<VideoFullscreenOverlay> with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _hasError = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _fadeController.forward();
    _initializeVideo();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _disposeVideo();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || _controller != null || !widget.video.hasVideo) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
    });

    try {
      debugPrint('🎬 Initializing fullscreen video for ${widget.video.id.substring(0, 8)}...');
      
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl!),
      );
      
      _controller = controller;
      
      await controller.initialize();
      
      if (mounted) {
        await controller.setLooping(true);
        await controller.setVolume(1.0); // Enable audio
        await controller.play();
        
        setState(() {
          _isInitializing = false;
        });
        
        debugPrint('✅ Fullscreen video playing with audio for ${widget.video.id.substring(0, 8)}');
      }
    } catch (e) {
      debugPrint('❌ Fullscreen video initialization failed: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
        });
      }
    }
  }

  void _disposeVideo() {
    debugPrint('🗑️ Disposing fullscreen video');
    _controller?.dispose();
    _controller = null;
  }

  void _togglePlayPause() {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        } else {
          _controller!.play();
        }
      });
    }
  }

  void _handleClose() async {
    await _fadeController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Material(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video player - fills width
                if (_controller != null && _controller!.value.isInitialized)
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.width / _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                else
                  _buildPlaceholder(),
                
                // Gradient overlay for controls
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Top controls (close button)
                _buildTopControls(),
                
                // Bottom overlay with video info and interactions
                _buildBottomOverlay(),
                
                // Loading indicator
                if (_isInitializing) _buildLoadingIndicator(),
                
                // Error indicator
                if (_hasError) _buildErrorIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Empty space for balance
          const SizedBox.shrink(),
          
          // Close button
          IconButton(
            onPressed: _handleClose,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 60,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Creator info
            _buildCreatorInfo(),
            const SizedBox(height: 12),
            
            // Video title
            if (widget.video.title?.isNotEmpty == true) ...[
              SelectableText(
                widget.video.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
            ],
            
            // Video content/description
            if (widget.video.content.isNotEmpty) ...[
              SelectableText(
                widget.video.content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
            ],
            
            // Hashtags
            if (widget.video.hashtags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: widget.video.hashtags.take(3).map((hashtag) {
                  return Text(
                    '#$hashtag',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Social action buttons
            _buildSocialActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorInfo() {
    return Consumer<UserProfileService>(
      builder: (context, profileService, child) {
        final profile = profileService.getCachedProfile(widget.video.pubkey);
        final displayName = profile?.displayName ?? 
                           profile?.name ?? 
                           '@${widget.video.pubkey.substring(0, 8)}...';
        
        return Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTimestamp(widget.video.timestamp),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Like button
          Consumer<SocialService>(
            builder: (context, socialService, child) {
              final isLiked = socialService.isLiked(widget.video.id);
              final likeCount = socialService.getCachedLikeCount(widget.video.id) ?? 0;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    onPressed: () => _handleLike(context, socialService),
                  ),
                  if (likeCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatLikeCount(likeCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          
          // Comment button
          _buildActionButton(
            icon: Icons.comment_outlined,
            onPressed: () => _openComments(context),
          ),
          
          // Repost button
          Consumer<SocialService>(
            builder: (context, socialService, child) {
              return _buildActionButton(
                icon: Icons.repeat,
                color: Colors.green,
                onPressed: () => _handleRepost(context, socialService),
              );
            },
          ),
          
          // Share button
          _buildActionButton(
            icon: Icons.share_outlined,
            onPressed: () => _handleShare(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color ?? Colors.white,
          size: 28,
        ),
        onPressed: onPressed,
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(
          minWidth: 56,
          minHeight: 56,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: const Center(
        child: CircularProgressIndicator(
          color: VineTheme.vineGreen,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitializing = true;
                });
                _initializeVideo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
              ),
              child: const Text('Retry'),
            ),
          ],
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
          size: 64,
        ),
      ),
    );
  }

  // Social action handlers
  void _handleLike(BuildContext context, SocialService socialService) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to like videos'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await socialService.toggleLike(widget.video.id, widget.video.pubkey);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${socialService.isLiked(widget.video.id) ? 'unlike' : 'like'} video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleRepost(BuildContext context, SocialService socialService) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to repost videos'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _performRepost(socialService);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video reposted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to repost video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performRepost(SocialService socialService) async {
    // Create a proper Event using the original video data for reposting
    final eventWithCorrectData = Event(
      widget.video.pubkey,
      22, // kind
      _buildEventTags(),
      widget.video.content,
      createdAt: widget.video.createdAt,
    );
    
    await socialService.repostEvent(eventWithCorrectData);
  }

  List<List<String>> _buildEventTags() {
    final tags = <List<String>>[];
    
    // Add URL tag if video URL exists
    if (widget.video.videoUrl != null) {
      tags.add(['url', widget.video.videoUrl!]);
    }
    
    // Add title tag if exists
    if (widget.video.title != null && widget.video.title!.isNotEmpty) {
      tags.add(['title', widget.video.title!]);
    }
    
    // Add thumbnail tag if exists
    if (widget.video.thumbnailUrl != null && widget.video.thumbnailUrl!.isNotEmpty) {
      tags.add(['thumb', widget.video.thumbnailUrl!]);
    }
    
    // Add duration tag if exists
    if (widget.video.duration != null) {
      tags.add(['duration', widget.video.duration!.toString()]);
    }
    
    // Add hashtags as 't' tags
    for (final hashtag in widget.video.hashtags) {
      tags.add(['t', hashtag]);
    }
    
    return tags;
  }

  void _openComments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(videoEvent: widget.video),
      ),
    );
  }

  void _handleShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(video: widget.video),
    );
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

  String _formatLikeCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}