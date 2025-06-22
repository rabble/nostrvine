// ABOUTME: TDD-driven video feed item widget with all loading states and error handling
// ABOUTME: Supports GIF and video playback with memory-efficient lifecycle management

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:nostr_sdk/event.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../services/video_manager_interface.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../widgets/share_video_menu.dart';
import '../services/user_profile_service.dart';
import '../screens/hashtag_feed_screen.dart';
import '../screens/comments_screen.dart';

/// Individual video item widget implementing TDD specifications
/// 
/// Key features:
/// - All loading states (loading, ready, error, disposed)
/// - GIF vs video handling
/// - Controller lifecycle management
/// - Error display and retry functionality
/// - Accessibility features
/// - Performance optimizations
class VideoFeedItem extends StatefulWidget {
  final VideoEvent video;
  final bool isActive;
  final Function(String)? onVideoError;

  const VideoFeedItem({
    super.key,
    required this.video,
    required this.isActive,
    this.onVideoError,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> with TickerProviderStateMixin {
  late IVideoManager _videoManager;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showPlayPauseIcon = false;
  late AnimationController _iconAnimationController;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeVideoManager();
    _loadUserProfile();
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle activation state changes
    if (widget.isActive != oldWidget.isActive) {
      _handleActivationChange();
    }
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    // Don't dispose controller here - VideoManager handles lifecycle
    super.dispose();
  }

  void _initializeVideoManager() {
    try {
      _videoManager = Provider.of<IVideoManager>(context, listen: false);
      _isInitialized = true;
      
      // Trigger preload if video is active
      if (widget.isActive) {
        _videoManager.preloadVideo(widget.video.id);
        
        // Check if controller is already available and auto-play
        _updateController();
      }
    } catch (e) {
      debugPrint('VideoFeedItem: VideoManager not found: $e');
    }
  }

  void _loadUserProfile() {
    try {
      final profileService = Provider.of<UserProfileService>(context, listen: false);
      // Request profile if not already cached
      if (!profileService.hasProfile(widget.video.pubkey)) {
        profileService.fetchProfile(widget.video.pubkey);
      }
    } catch (e) {
      debugPrint('VideoFeedItem: UserProfileService not found: $e');
    }
  }

  void _handleActivationChange() {
    if (!_isInitialized) return;
    
    if (widget.isActive) {
      // Preload and potentially play video
      _videoManager.preloadVideo(widget.video.id);
      _updateController();
      
      // Auto-play if controller is ready
      if (_controller != null) {
        _playVideo();
      }
    } else {
      // Video became inactive - pause and disable looping
      _pauseVideo();
      if (_controller != null) {
        _controller!.setLooping(false);
      }
      _controller = null;
    }
  }

  void _updateController() {
    if (!_isInitialized) return;
    
    final videoState = _videoManager.getVideoState(widget.video.id);
    final newController = _videoManager.getController(widget.video.id);
    
    debugPrint('🎬 Controller state for ${widget.video.id.substring(0, 8)}: ${_controller?.value.isInitialized}');
    debugPrint('🎬 Video state: ${videoState?.loadingState}');
    debugPrint('🎬 VideoManager has controller: ${newController != null}');
    
    if (newController != _controller) {
      setState(() {
        _controller = newController;
      });
      
      // Auto-play video when controller becomes available and video is active
      if (newController != null && widget.isActive) {
        _playVideo();
      }
    }
  }

  void _handleRetry() {
    if (!_isInitialized) return;
    
    setState(() {
    });
    
    _videoManager.preloadVideo(widget.video.id);
  }

  void _playVideo() {
    if (_controller != null && _controller!.value.isInitialized && !_controller!.value.isPlaying) {
      debugPrint('▶️ Playing video: ${widget.video.id.substring(0, 8)}...');
      _controller!.play();
      // Only loop when the video is active (not in background/comments)
      _controller!.setLooping(widget.isActive);
    }
  }

  void _pauseVideo() {
    if (_controller != null && _controller!.value.isPlaying) {
      debugPrint('⏸️ Pausing video: ${widget.video.id.substring(0, 8)}...');
      _controller!.pause();
    }
  }

  void _togglePlayPause() {
    debugPrint('🎬 _togglePlayPause called for ${widget.video.id.substring(0, 8)}...');
    if (_controller != null && _controller!.value.isInitialized) {
      final wasPlaying = _controller!.value.isPlaying;
      debugPrint('🎬 Current playing state: $wasPlaying');
      
      if (wasPlaying) {
        debugPrint('⏸️ Calling _pauseVideo()');
        _pauseVideo();
      } else {
        debugPrint('▶️ Calling _playVideo()');
        _playVideo();
      }
      debugPrint('🎭 Showing play/pause icon');
      _showPlayPauseIconBriefly();
    } else {
      debugPrint('❌ _togglePlayPause failed - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}');
    }
  }

  void _showPlayPauseIconBriefly() {
    // Only show if video is properly initialized and ready
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.hasError) {
      return;
    }
    
    setState(() {
      _showPlayPauseIcon = true;
    });
    
    _iconAnimationController.forward().then((_) {
      _iconAnimationController.reverse();
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  void _navigateToHashtagFeed(String hashtag) {
    debugPrint('🔗 Navigating to hashtag feed: #$hashtag');
    
    // Get the root navigator to ensure we have access to all providers
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => HashtagFeedScreen(hashtag: hashtag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildErrorState('Video system not available');
    }

    return Consumer<IVideoManager>(
      builder: (context, videoManager, child) {
        final videoState = videoManager.getVideoState(widget.video.id);
        
        if (videoState == null) {
          return _buildErrorState('Video not found');
        }

        // Schedule controller update after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateController();
        });

        return _buildVideoContent(videoState);
      },
    );
  }

  Widget _buildVideoContent(VideoState videoState) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Main video content
          _buildMainContent(videoState),
          
          // Video overlay information
          _buildVideoOverlay(),
          
          // Loading indicator (when loading but not showing loading state)
          if (videoState.isLoading && videoState.loadingState != VideoLoadingState.loading) _buildLoadingOverlay(),
          
          // Play/Pause icon overlay (when tapped and video is ready)
          if (_showPlayPauseIcon && !videoState.isLoading && videoState.loadingState == VideoLoadingState.ready) _buildPlayPauseIconOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainContent(VideoState videoState) {
    switch (videoState.loadingState) {
      case VideoLoadingState.notLoaded:
        return _buildNotLoadedState();
        
      case VideoLoadingState.loading:
        return _buildLoadingState();
        
      case VideoLoadingState.ready:
        if (widget.video.isGif) {
          return _buildGifContent();
        } else {
          return _buildVideoPlayerContent();
        }
        
      case VideoLoadingState.failed:
        return _buildFailedState(videoState, canRetry: true);
        
      case VideoLoadingState.permanentlyFailed:
        return _buildFailedState(videoState, canRetry: false);
        
      case VideoLoadingState.disposed:
        // Auto-retry disposed videos when they come into view
        if (widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _videoManager.preloadVideo(widget.video.id);
          });
        }
        return _buildDisposedState();
    }
  }

  Widget _buildNotLoadedState() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          size: 64,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGifContent() {
    // For GIFs, we would typically use Image.network with caching
    // For TDD phase, show placeholder
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.gif,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              widget.video.title ?? 'GIF Video',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerContent() {
    if (_controller == null) {
      return _buildNotLoadedState();
    }

    // Web platform needs special handling for video tap events
    if (kIsWeb) {
      return Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                debugPrint('🎯 Web video tap detected for ${widget.video.id.substring(0, 8)}...');
                if (_controller != null && _controller!.value.isInitialized && !_controller!.value.hasError) {
                  debugPrint('✅ Web video tap conditions met, toggling play/pause');
                  _togglePlayPause();
                } else {
                  debugPrint('❌ Web video tap ignored - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}, hasError: ${_controller?.value.hasError}');
                }
              },
              child: Stack(
                children: [
                  VideoPlayer(_controller!),
                  // Extra transparent layer for web gesture capture
                  Positioned.fill(
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Native platform (mobile) - original implementation
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: GestureDetector(
          onTap: () {
            debugPrint('🎯 Native video tap detected for ${widget.video.id.substring(0, 8)}...');
            if (_controller != null && _controller!.value.isInitialized && !_controller!.value.hasError) {
              debugPrint('✅ Native video tap conditions met, toggling play/pause');
              _togglePlayPause();
            } else {
              debugPrint('❌ Native video tap ignored - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}, hasError: ${_controller?.value.hasError}');
            }
          },
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }

  Widget _buildFailedState(VideoState videoState, {required bool canRetry}) {
    return Container(
      color: Colors.red[900]?.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              size: 64,
              color: canRetry ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              canRetry ? 'Failed to load' : 'Permanently failed',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (videoState.errorMessage != null) ...[
              Text(
                videoState.errorMessage!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (canRetry) ...[
              ElevatedButton(
                onPressed: _handleRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisposedState() {
    return Container(
      color: Colors.grey[700],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              size: 64,
              color: Colors.white54,
            ),
            SizedBox(height: 16),
            Text(
              'Video disposed',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      color: Colors.red[900]?.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoOverlay() {
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
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Username/Creator info
            _buildCreatorInfo(),
            const SizedBox(height: 8),
            
            // Repost attribution (if this is a repost)
            if (widget.video.isRepost) ...[
              _buildRepostAttribution(),
              const SizedBox(height: 8),
            ],
            
            // Video title
            if (widget.video.title?.isNotEmpty == true) ...[
              Text(
                widget.video.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            
            // Video content/description
            if (widget.video.content.isNotEmpty) ...[
              Text(
                widget.video.content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            
            // Hashtags
            if (widget.video.hashtags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: widget.video.hashtags.take(3).map((hashtag) {
                  return GestureDetector(
                    onTap: () => _navigateToHashtagFeed(hashtag),
                    child: Text(
                      '#$hashtag',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            
            // Social action buttons
            _buildSocialActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildPlayPauseIconOverlay() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    
    return AnimatedBuilder(
      animation: _iconAnimationController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Transform.scale(
              scale: 0.8 + (_iconAnimationController.value * 0.2),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
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
            const Icon(
              Icons.person,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• ${_formatTimestamp(widget.video.timestamp)}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRepostAttribution() {
    final reposterName = widget.video.reposterPubkey != null 
        ? '${widget.video.reposterPubkey!.substring(0, 8)}...'
        : 'Someone';
        
    return Row(
      children: [
        const Icon(
          Icons.repeat,
          color: Colors.green,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          'Reposted by $reposterName',
          style: const TextStyle(
            color: Colors.green,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Like button with functionality
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
          
          // Comment button with count
          FutureBuilder<int>(
            future: _getCommentCount(),
            builder: (context, snapshot) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    onPressed: () => _openComments(context),
                  ),
                  if (snapshot.hasData && snapshot.data! > 0)
                    Positioned(
                      top: 32,
                      child: Text(
                        snapshot.data!.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
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
    return IconButton(
      icon: Icon(
        icon,
        color: color ?? Colors.white,
        size: 24,
      ),
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(
        minWidth: 40,
        minHeight: 40,
      ),
    );
  }

  void _handleRepost(BuildContext context, SocialService socialService) async {
    // Store context reference to avoid async gap warnings
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Check if user is authenticated
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Please log in to repost videos'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show loading indicator
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Reposting video...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      // Create a simple Event object for reposting
      // Since the nostr library might expect positional arguments, we use a different approach
      await _performRepost(socialService);
      
      // Show success message
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Video reposted successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      // Show error message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Failed to repost: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
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
    
    // Add title tag if title exists
    if (widget.video.title != null) {
      tags.add(['title', widget.video.title!]);
    }
    
    // Add duration tag if duration exists
    if (widget.video.duration != null) {
      tags.add(['duration', widget.video.duration!.toString()]);
    }
    
    // Add thumbnail tag if thumbnail URL exists
    if (widget.video.thumbnailUrl != null) {
      tags.add(['thumb', widget.video.thumbnailUrl!]);
    }
    
    // Add dimensions tag if dimensions exist
    if (widget.video.dimensions != null) {
      tags.add(['dim', widget.video.dimensions!]);
    }
    
    // Add mime type tag if it exists
    if (widget.video.mimeType != null) {
      tags.add(['m', widget.video.mimeType!]);
    }
    
    // Add hashtag tags
    for (final hashtag in widget.video.hashtags) {
      tags.add(['t', hashtag]);
    }
    
    // Add any additional raw tags that were stored
    widget.video.rawTags.forEach((key, value) {
      if (!tags.any((tag) => tag.isNotEmpty && tag[0] == key)) {
        tags.add([key, value]);
      }
    });
    
    return tags;
  }

  void _openComments(BuildContext context) {
    // Pause the video when opening comments
    _pauseVideo();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(videoEvent: widget.video),
      ),
    ).then((_) {
      // Resume video when returning from comments (only if still active)
      if (widget.isActive && _controller != null) {
        _playVideo();
      }
    });
  }

  Future<int> _getCommentCount() async {
    try {
      final socialService = Provider.of<SocialService>(context, listen: false);
      int count = 0;
      
      await for (final _ in socialService.fetchCommentsForEvent(widget.video.id).take(100)) {
        count++;
      }
      
      return count;
    } catch (e) {
      debugPrint('Error getting comment count: $e');
      return 0;
    }
  }

  void _handleLike(BuildContext context, SocialService socialService) async {
    // Store context reference to avoid async gap warnings
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      await socialService.toggleLike(widget.video.id, widget.video.pubkey);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to like video: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  void _handleShare(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(
        video: widget.video,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

}

/// Accessibility helper for video content
class VideoAccessibilityInfo extends StatelessWidget {
  final VideoEvent video;
  final VideoState? videoState;

  const VideoAccessibilityInfo({
    super.key,
    required this.video,
    this.videoState,
  });

  @override
  Widget build(BuildContext context) {
    String semanticLabel = 'Video';
    
    if (video.title?.isNotEmpty == true) {
      semanticLabel += ': ${video.title}';
    }
    
    if (videoState != null) {
      switch (videoState!.loadingState) {
        case VideoLoadingState.loading:
          semanticLabel += ', loading';
          break;
        case VideoLoadingState.ready:
          semanticLabel += ', ready to play';
          break;
        case VideoLoadingState.failed:
          semanticLabel += ', failed to load';
          break;
        case VideoLoadingState.permanentlyFailed:
          semanticLabel += ', permanently failed';
          break;
        default:
          break;
      }
    }

    return Semantics(
      label: semanticLabel,
      child: const SizedBox.shrink(),
    );
  }
}