// ABOUTME: Individual video feed item widget for displaying NIP-71 video events
// ABOUTME: Renders video content with user info, interactions, and metadata

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../services/video_cache_service.dart';
import '../services/user_profile_service.dart';
import '../services/seen_videos_service.dart';

/// Widget for displaying a single video event in the feed
class VideoFeedItem extends StatefulWidget {
  final VideoEvent videoEvent;
  final bool isActive;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMoreOptions;
  final VoidCallback? onUserTap;
  final VideoCacheService? videoCacheService; // Legacy - for backward compatibility
  final VideoPlayerController? videoController; // New - direct controller from VideoManager
  final VideoState? videoState; // New - video state from VideoManager
  final UserProfileService? userProfileService;
  final SeenVideosService? seenVideosService;
  
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
    this.videoController,
    this.videoState,
    this.userProfileService,
    this.seenVideosService,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isPlaying = false;
  // ABANDONED: Video controls were intended for user interaction but never implemented in UI
  // final bool _showControls = false;
  bool _hasError = false;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 2; // Allow up to 2 retries before giving up

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    
    // Handle initial autoplay for videos that start as active (fixes first video not autoplaying)
    if (widget.isActive) {
      debugPrint('🎬 Initial active video detected: ${widget.videoEvent.id.substring(0, 8)}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) {
          debugPrint('🎬 Triggering initial autoplay: ${widget.videoEvent.id.substring(0, 8)}');
          // Use a small delay to ensure video initialization has time to complete
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && widget.isActive) {
              _handleVideoActivation();
            }
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        debugPrint('🎬 Video became active: ${widget.videoEvent.id.substring(0, 8)}');
        _handleVideoActivation();
      } else {
        debugPrint('⏸️ Video became inactive: ${widget.videoEvent.id.substring(0, 8)}');
        _pauseVideo();
      }
    }
  }
  
  /// Handle video activation with robust initialization and autoplay
  void _handleVideoActivation() async {
    // Case 1: No controller available
    if (_controller == null) {
      debugPrint('❌ No video controller available for: ${widget.videoEvent.id.substring(0, 8)}');
      return;
    }
    
    // Case 2: Controller exists but not initialized
    if (!_controller!.value.isInitialized) {
      debugPrint('🔄 Video controller not initialized, initializing: ${widget.videoEvent.id.substring(0, 8)}');
      await _initializeLazily();
      return; // _initializeLazily will handle autoplay
    }
    
    // Case 3: Controller initialized but no Chewie controller
    if (_chewieController == null) {
      debugPrint('🔄 Creating Chewie controller for active video: ${widget.videoEvent.id.substring(0, 8)}');
      _createChewieController();
      
      // Wait for Chewie to be ready using proper callback
      if (_chewieController != null) {
        // Listen for when Chewie is ready and start playing
        _chewieController!.addListener(_onChewieStateChange);
      }
    }
    
    // Case 4: Ready to play immediately
    if (_chewieController != null && widget.isActive && mounted) {
      debugPrint('▶️ Starting autoplay for active video: ${widget.videoEvent.id.substring(0, 8)}');
      _playVideo();
    }
  }

  void _onChewieStateChange() {
    if (_chewieController != null && widget.isActive && mounted) {
      // Start playing once Chewie controller is ready
      if (_chewieController!.isPlaying != true && !_isPlaying) {
        debugPrint('🎬 Chewie ready, starting autoplay: ${widget.videoEvent.id.substring(0, 8)}');
        _playVideo();
        _chewieController!.removeListener(_onChewieStateChange);
      }
    }
  }

  @override
  void dispose() {
    // Dispose Chewie controller but NOT the video controller if it's managed by cache service
    try {
      _chewieController?.dispose();
      
      // Only dispose video controller if it's not from the cache service
      final isCachedController = widget.videoCacheService?.getController(widget.videoEvent) == _controller;
      if (!isCachedController && _controller != null) {
        _controller!.dispose();
        debugPrint('🗑️ DISPOSED: Own controller for: ${widget.videoEvent.id.substring(0, 8)}');
      } else {
        debugPrint('🔗 KEPT: Cache-managed controller for: ${widget.videoEvent.id.substring(0, 8)}');
      }
    } catch (e) {
      debugPrint('⚠️ Error disposing controllers: $e');
    }
    super.dispose();
  }


  void _initializeVideo() {
    if (widget.videoEvent.videoUrl != null && 
        widget.videoEvent.videoUrl!.isNotEmpty && 
        !widget.videoEvent.isGif) {
      
      // First check if we have a preloaded controller from the cache service
      final preloadedController = widget.videoCacheService?.getController(widget.videoEvent);
      if (preloadedController != null) {
        debugPrint('⚡ INSTANT: Using preloaded controller for ${widget.videoEvent.id.substring(0, 8)} (${widget.videoEvent.mimeType})');
        _controller = preloadedController;
        
        // Create Chewie controller immediately since video is preloaded
        if (_controller!.value.isInitialized) {
          _createChewieController();
        }
        return;
      }
      
      // Fallback: create our own controller if not preloaded
      debugPrint('🔄 FALLBACK: Creating controller for ${widget.videoEvent.id.substring(0, 8)} (${widget.videoEvent.mimeType})');
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoEvent.videoUrl!),
      );
    }
  }
  
  void _createChewieController() {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        _chewieController = ChewieController(
          videoPlayerController: _controller!,
          autoPlay: false,
          looping: true,
          showControls: false,
          allowFullScreen: false,
          allowMuting: false,
          allowPlaybackSpeedChanging: false,
          showControlsOnInitialize: false,
          aspectRatio: _controller!.value.aspectRatio,
          placeholder: Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          ),
          errorBuilder: (context, errorMessage) {
            debugPrint('❌ Chewie error for ${widget.videoEvent.id.substring(0, 8)}: $errorMessage');
            return Container(
              color: Colors.red[900],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Format not supported\n${widget.videoEvent.mimeType ?? "Unknown format"}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
        
        debugPrint('✅ INSTANT: Chewie controller ready for ${widget.videoEvent.id.substring(0, 8)}');
        
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('❌ Error creating Chewie controller for ${widget.videoEvent.id.substring(0, 8)}: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Player initialization error: $e';
          });
        }
      }
    }
  }

  Future<void> _initializeLazily() async {
    if (_controller == null) {
      debugPrint('⚠️ No controller to initialize: ${widget.videoEvent.id.substring(0, 8)}');
      return;
    }
    
    if (_controller!.value.isInitialized && _chewieController != null) {
      debugPrint('⏩ Controllers already initialized: ${widget.videoEvent.id.substring(0, 8)}');
      if (widget.isActive) {
        _playVideo();
      }
      return;
    }
    
    try {
      debugPrint('🔄 FALLBACK: Initializing non-preloaded video ${widget.videoEvent.id.substring(0, 8)}...');
      
      // Initialize video player (fallback for non-preloaded videos)
      await _controller!.initialize();
      
      // Create Chewie controller
      _createChewieController();
      
      if (widget.isActive) {
        _playVideo();
      }
    } catch (e) {
      debugPrint('❌ FALLBACK: Initialization failed for ${widget.videoEvent.mimeType}: ${widget.videoEvent.id.substring(0, 8)} - $e');
      _retryCount++;
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load ${widget.videoEvent.mimeType ?? "video"}: $e';
        });
      }
      
      // Only remove from ready queue after max retries to prevent premature removal
      if (_retryCount >= _maxRetries) {
        debugPrint('🚫 Max retries reached for ${widget.videoEvent.id.substring(0, 8)}, removing from ready queue');
        widget.videoCacheService?.removeVideoFromReadyQueue(widget.videoEvent.id);
      }
    }
  }
  
  /// ABANDONED: Advanced timeout initialization with macOS-specific event loop handling
  /// This was replaced by simpler initialization in _initializeVideo() method
  void _initializeVideoWithTimeout() async {
    const timeoutDuration = Duration(seconds: 15); // Increased to 15 second timeout
    
    try {
      debugPrint('🎥 Initializing video with ${timeoutDuration.inSeconds}s timeout: ${widget.videoEvent.id.substring(0, 8)}...');
      debugPrint('📹 Video URL: ${widget.videoEvent.videoUrl}');
      
      // Use Completer and Timer to prevent event loop blocking on macOS
      final completer = Completer<void>();
      bool hasCompleted = false;
      
      // Start initialization in microtask to avoid blocking
      scheduleMicrotask(() async {
        try {
          await _controller!.initialize();
          if (!hasCompleted) {
            hasCompleted = true;
            completer.complete();
          }
        } catch (e) {
          if (!hasCompleted) {
            hasCompleted = true;
            completer.completeError(e);
          }
        }
      });
      
      // Set up timeout using Timer
      Timer(timeoutDuration, () {
        if (!hasCompleted) {
          hasCompleted = true;
          completer.completeError(TimeoutException('Video initialization timeout after ${timeoutDuration.inSeconds} seconds', timeoutDuration));
        }
      });
      
      // Wait for either completion or timeout
      await completer.future;
      
      debugPrint('✅ Video initialized successfully: ${widget.videoEvent.id.substring(0, 8)}');
      
      // Brief delay to ensure controller state is updated
      await Future.delayed(const Duration(milliseconds: 50));
      
      if (!_controller!.value.isInitialized) {
        debugPrint('⚠️ Controller not ready after initialization - ${widget.videoEvent.id.substring(0, 8)}');
        return;
      }
      
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
  
  /// ABANDONED: Controller listener for automatic initialization state changes
  /// This callback-based approach was replaced by direct state management
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
    if (_chewieController != null && _controller!.value.isInitialized) {
      debugPrint('▶️ ROBUST: Playing video ${widget.videoEvent.id.substring(0, 8)}... (format: ${widget.videoEvent.mimeType})');
      
      try {
        _chewieController!.play();
        setState(() {
          _isPlaying = true;
        });
        
        // Mark video as seen when it starts playing
        if (widget.seenVideosService != null) {
          widget.seenVideosService!.markVideoAsSeen(widget.videoEvent.id);
          debugPrint('👁️ Marked video as seen: ${widget.videoEvent.id.substring(0, 8)}');
        }
      } catch (e) {
        debugPrint('❌ Error playing video ${widget.videoEvent.id.substring(0, 8)}: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Playback error: $e';
          });
        }
      }
    } else {
      debugPrint('⚠️ Cannot play video - Chewie controller not ready: ${widget.videoEvent.id.substring(0, 8)}');
    }
  }

  void _pauseVideo() {
    if (_chewieController != null && _controller!.value.isInitialized) {
      debugPrint('⏸️ ROBUST: Pausing video ${widget.videoEvent.id.substring(0, 8)}... (format: ${widget.videoEvent.mimeType})');
      
      try {
        _chewieController!.pause();
        setState(() {
          _isPlaying = false;
        });
      } catch (e) {
        debugPrint('❌ Error pausing video: $e');
      }
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
    // Global error boundary to prevent crashes from propagating up
    try {
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
    } catch (e, stackTrace) {
      debugPrint('❌ CRITICAL ERROR in VideoFeedItem build for ${widget.videoEvent.id.substring(0, 8)}: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      // Return a safe fallback widget to prevent app crash
      return Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Video Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${widget.videoEvent.id.substring(0, 8)}...',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Swipe to skip this video',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
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
    
    // ALWAYS show thumbnail background first - this is the TikTok UX secret!
    final hasValidThumbnail = widget.videoEvent.thumbnailUrl != null && 
                              widget.videoEvent.thumbnailUrl!.isNotEmpty;
    
    return Stack(
      children: [
        // LAYER 1: Thumbnail background (always shown for smooth UX)
        Positioned.fill(
          child: hasValidThumbnail
              ? CachedNetworkImage(
                  imageUrl: widget.videoEvent.thumbnailUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
        
        // LAYER 2: Video player (only when ready)
        if (_chewieController != null && _controller!.value.isInitialized)
          Positioned.fill(
            child: Center(
              child: Chewie(controller: _chewieController!),
            ),
          ),
        
        // LAYER 3: Loading indicator (when video not ready)
        if (_chewieController == null || !_controller!.value.isInitialized)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white70),
                    SizedBox(height: 8),
                    Text(
                      'Preparing video...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // LAYER 4: Play/pause overlay
        if (_chewieController != null && !_isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
      ],
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
              if (_retryCount < _maxRetries) ...[
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
                  child: Text('Retry (${_retryCount + 1}/$_maxRetries)'),
                ),
              ] else ...[
                Text(
                  'Video unavailable\nCheck your connection',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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