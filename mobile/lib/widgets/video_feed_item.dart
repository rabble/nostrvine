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
import '../services/analytics_service.dart';
import '../widgets/share_video_menu.dart';
import '../widgets/clickable_hashtag_text.dart';
import '../services/user_profile_service.dart';
import '../screens/hashtag_feed_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/profile_screen.dart';
import '../utils/unified_logger.dart';
import '../main.dart';

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
  bool _userPaused = false; // Track if user manually paused the video
  late AnimationController _iconAnimationController;
  
  // Lazy comment loading state
  bool _hasLoadedComments = false;
  int? _commentCount;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeVideoManager();
    _loadUserProfile();
    
    // Handle initial activation state
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleActivationChange();
      });
    }
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle activation state changes OR video changes
    if (widget.isActive != oldWidget.isActive || 
        widget.video.id != oldWidget.video.id) {
      Log.info('📱 Widget updated: isActive changed: ${widget.isActive != oldWidget.isActive}, video changed: ${widget.video.id != oldWidget.video.id}', name: 'VideoFeedItem', category: LogCategory.ui);
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
        try {
          _videoManager.preloadVideo(widget.video.id);
        } catch (e) {
          Log.info('VideoFeedItem: Video not ready for preload yet: ${widget.video.id}', name: 'VideoFeedItem', category: LogCategory.ui);
        }
        
        // Schedule controller update after current frame to ensure proper initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateController();
        });
      }
    } catch (e) {
      Log.info('VideoFeedItem: VideoManager not found: $e', name: 'VideoFeedItem', category: LogCategory.ui);
    }
  }

  void _loadUserProfile() {
    // Profile loading is now handled at the feed level with batch fetching
    // This method is kept for compatibility but no longer fetches individually
    Log.verbose('Profile loading handled at feed level for ${widget.video.pubkey.substring(0, 8)}...', 
        name: 'VideoFeedItem', category: LogCategory.ui);
  }

  void _handleActivationChange() {
    if (!_isInitialized) return;
    
    Log.info('🎯 _handleActivationChange called for ${widget.video.id.substring(0, 8)}... isActive: ${widget.isActive}', 
        name: 'VideoFeedItem', category: LogCategory.ui);
    
    // Only use isActive prop from parent (PageView index-based control)
    if (widget.isActive) {
      _userPaused = false; // Reset user pause flag when video becomes active
      // Preload video - Consumer<IVideoManager> will trigger _updateController via stream when ready
      try {
        Log.info('📥 Starting preload for ${widget.video.id.substring(0, 8)}...', name: 'VideoFeedItem', category: LogCategory.ui);
        _videoManager.preloadVideo(widget.video.id);
      } catch (e) {
        Log.info('VideoFeedItem: Video not ready for preload yet: ${widget.video.id}', name: 'VideoFeedItem', category: LogCategory.ui);
      }
      
      // IMPORTANT: Also check immediately after preload starts
      // The controller might already be ready from previous loads
      _updateController();
      
      // Auto-play if controller is already ready
      Log.info('🎮 Checking existing controller: ${_controller != null}', name: 'VideoFeedItem', category: LogCategory.ui);
      if (_controller != null) {
        Log.info('🎮 Controller exists, isInitialized: ${_controller!.value.isInitialized}', name: 'VideoFeedItem', category: LogCategory.ui);
        if (_controller!.value.isInitialized) {
          Log.info('▶️ Controller ready, calling _playVideo immediately', name: 'VideoFeedItem', category: LogCategory.ui);
          _playVideo();
        } else {
          Log.info('⏳ Controller not initialized, adding listener', name: 'VideoFeedItem', category: LogCategory.ui);
          // Add listener to play when initialized
          void onInitialized() {
            Log.info('🔔 Controller initialization listener triggered, isInitialized: ${_controller!.value.isInitialized}', name: 'VideoFeedItem', category: LogCategory.ui);
            if (_controller!.value.isInitialized && widget.isActive) {
              Log.info('▶️ Controller now ready, calling _playVideo from listener', name: 'VideoFeedItem', category: LogCategory.ui);
              _playVideo();
              _controller!.removeListener(onInitialized);
            }
          }
          _controller!.addListener(onInitialized);
        }
      } else {
        Log.info('❌ No controller available yet, waiting for Consumer update', name: 'VideoFeedItem', category: LogCategory.ui);
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
    
    Log.info('🔄 _updateController called for ${widget.video.id.substring(0, 8)}...', name: 'VideoFeedItem', category: LogCategory.ui);
    
    final videoState = _videoManager.getVideoState(widget.video.id);
    final newController = _videoManager.getController(widget.video.id);
    
    Log.info('📊 Current controller state: ${_controller?.value.isInitialized ?? "null"}', name: 'VideoFeedItem', category: LogCategory.ui);
    Log.info('📊 Video state: ${videoState?.loadingState}', name: 'VideoFeedItem', category: LogCategory.ui);
    Log.info('📊 New controller from VideoManager: ${newController != null}', name: 'VideoFeedItem', category: LogCategory.ui);
    
    if (newController != _controller) {
      Log.info('🔄 Controller changed! Old: ${_controller != null}, New: ${newController != null}', name: 'VideoFeedItem', category: LogCategory.ui);
      setState(() {
        _controller = newController;
      });
      
      // Auto-play video when controller becomes available and video is active
      if (newController != null && widget.isActive) {
        Log.info('🎬 New controller available and widget is active', name: 'VideoFeedItem', category: LogCategory.ui);
        // Check if already initialized
        if (newController.value.isInitialized) {
          Log.info('✅ Controller already initialized, calling _playVideo', name: 'VideoFeedItem', category: LogCategory.ui);
          _playVideo();
        } else {
          Log.info('⏳ Controller not yet initialized, adding listener', name: 'VideoFeedItem', category: LogCategory.ui);
          // Add listener to play when initialized
          void onInitialized() {
            Log.info('🔔 UpdateController listener triggered, isInitialized: ${newController.value.isInitialized}', name: 'VideoFeedItem', category: LogCategory.ui);
            if (newController.value.isInitialized && widget.isActive) {
              Log.info('▶️ Controller ready in listener, calling _playVideo', name: 'VideoFeedItem', category: LogCategory.ui);
              _playVideo();
              newController.removeListener(onInitialized);
            }
          }
          newController.addListener(onInitialized);
        }
      } else {
        Log.info('⚠️ Controller not available or widget not active. Controller: ${newController != null}, isActive: ${widget.isActive}', name: 'VideoFeedItem', category: LogCategory.ui);
      }
    } else {
      Log.info('↔️ No controller change detected', name: 'VideoFeedItem', category: LogCategory.ui);
    }
  }

  void _handleRetry() {
    if (!_isInitialized) return;
    
    setState(() {
    });
    
    _videoManager.preloadVideo(widget.video.id);
  }

  void _playVideo() {
    // Only play if widget is marked as active by parent
    if (!widget.isActive) {
      Log.warning('⚠️ Attempted to play video ${widget.video.id.substring(0, 8)} but widget is not active!', 
          name: 'VideoFeedItem', category: LogCategory.ui);
      return;
    }
    
    if (_controller != null && _controller!.value.isInitialized && !_controller!.value.isPlaying) {
      Log.info('🎬 VideoFeedItem playing video: ${widget.video.id.substring(0, 8)} (isActive: ${widget.isActive})', 
          name: 'VideoFeedItem', category: LogCategory.ui);
      _videoManager.resumeVideo(widget.video.id);
      // Only loop when the video is active (not in background/comments)
      _controller!.setLooping(widget.isActive);
      
      // Track video view if analytics is enabled
      _trackVideoView();
    }
  }
  
  void _trackVideoView() {
    try {
      final analyticsService = Provider.of<AnalyticsService>(context, listen: false);
      analyticsService.trackVideoView(widget.video);
    } catch (e) {
      // Analytics is optional - don't crash if service is not available
      Log.warning('Analytics service not available: $e', name: 'VideoFeedItem', category: LogCategory.ui);
    }
  }
  
  void _checkAutoPlay(VideoState videoState) {
    // Only auto-play if video is ready, widget is active, and user hasn't manually paused
    if (widget.isActive &&
        videoState.loadingState == VideoLoadingState.ready &&
        _controller != null && 
        _controller!.value.isInitialized &&
        !_controller!.value.isPlaying &&
        !_userPaused) { // Don't auto-play if user manually paused
      
      Log.info('🎬 Auto-playing video: ${widget.video.id.substring(0, 8)}', 
          name: 'VideoFeedItem', category: LogCategory.ui);
      _playVideo();
    }
  }

  void _pauseVideo({bool userInitiated = false}) {
    if (_controller != null && _controller!.value.isPlaying) {
      Log.info('⏸️ VideoFeedItem pausing video: ${widget.video.id.substring(0, 8)} (userInitiated: $userInitiated)', 
          name: 'VideoFeedItem', category: LogCategory.ui);
      _videoManager.pauseVideo(widget.video.id);
      
      if (userInitiated) {
        _userPaused = true; // Set flag to prevent auto-play
        Log.info('🛑 User paused video', name: 'VideoFeedItem', category: LogCategory.ui);
      }
    }
  }

  void _togglePlayPause() {
    Log.debug('_togglePlayPause called for ${widget.video.id.substring(0, 8)}...', name: 'VideoFeedItem', category: LogCategory.ui);
    if (_controller != null && _controller!.value.isInitialized) {
      final wasPlaying = _controller!.value.isPlaying;
      Log.debug('Current playing state: $wasPlaying', name: 'VideoFeedItem', category: LogCategory.ui);
      
      if (wasPlaying) {
        Log.debug('Calling _pauseVideo() with userInitiated=true', name: 'VideoFeedItem', category: LogCategory.ui);
        _pauseVideo(userInitiated: true);
      } else {
        _userPaused = false; // Reset flag when user manually starts video
        Log.debug('▶️ Calling _playVideo()', name: 'VideoFeedItem', category: LogCategory.ui);
        _playVideo();
      }
      Log.debug('� Showing play/pause icon', name: 'VideoFeedItem', category: LogCategory.ui);
      _showPlayPauseIconBriefly();
    } else {
      Log.error('_togglePlayPause failed - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}', name: 'VideoFeedItem', category: LogCategory.ui);
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
    Log.debug('📍 Navigating to hashtag feed: #$hashtag', name: 'VideoFeedItem', category: LogCategory.ui);
    
    // Pause video before navigating away
    _pauseVideo();
    
    // Use global navigation key for hashtag navigation
    final mainNavState = mainNavigationKey.currentState;
    if (mainNavState != null) {
      // Navigate through main navigation to maintain footer
      mainNavState.navigateToHashtag(hashtag);
    } else {
      // Fallback to direct navigation if not in main navigation context
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => HashtagFeedScreen(hashtag: hashtag),
        ),
      ).then((_) {
        // Resume video when returning (only if still active)
        if (widget.isActive && _controller != null) {
          _playVideo();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildErrorState('Video system not available');
    }

    // Simple Consumer without visibility detection for control
    return Consumer<IVideoManager>(
        builder: (context, videoManager, child) {
          Log.info('🔵 Consumer rebuild triggered for ${widget.video.id.substring(0, 8)}...', name: 'VideoFeedItem', category: LogCategory.ui);
          
          final videoState = videoManager.getVideoState(widget.video.id);
          
          if (videoState == null) {
            Log.info('❌ Video state is null for ${widget.video.id.substring(0, 8)}', name: 'VideoFeedItem', category: LogCategory.ui);
            return _buildErrorState('Video not found');
          }

          Log.info('🔵 Video state: ${videoState.loadingState} for ${widget.video.id.substring(0, 8)}', name: 'VideoFeedItem', category: LogCategory.ui);

          // Schedule controller update after build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Log.info('🕐 PostFrameCallback triggering _updateController for ${widget.video.id.substring(0, 8)}', name: 'VideoFeedItem', category: LogCategory.ui);
            _updateController();
            
            // Check for auto-play after controller update
            _checkAutoPlay(videoState);
          });

          return _buildVideoContent(videoState);
        },
    );
  }

  Widget _buildVideoContent(VideoState videoState) {
    // Check if video is square (aspect ratio close to 1:1) and ready
    final isSquare = _controller != null && 
                    _controller!.value.isInitialized && 
                    _controller!.value.aspectRatio > 0.9 && 
                    _controller!.value.aspectRatio < 1.1;
    
    // For square videos, use column layout instead of stack
    if (isSquare && videoState.loadingState == VideoLoadingState.ready) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          children: [
            // Video player at top
            Flexible(
              child: Stack(
                children: [
                  _buildMainContent(videoState),
                  // Loading indicator (when loading but not showing loading state)
                  if (videoState.isLoading && videoState.loadingState != VideoLoadingState.loading) _buildLoadingOverlay(),
                  // Play/Pause icon overlay (when tapped and video is ready)
                  if (_showPlayPauseIcon && !videoState.isLoading) _buildPlayPauseIconOverlay(),
                ],
              ),
            ),
            // Info below video
            _buildVideoInfoBelow(),
          ],
        ),
      );
    }
    
    // For non-square videos, use overlay layout
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

    // Check if video is square (aspect ratio close to 1:1)
    final aspectRatio = _controller!.value.aspectRatio;
    final isSquare = aspectRatio > 0.9 && aspectRatio < 1.1;

    // Web platform needs special handling for video tap events
    if (kIsWeb) {
      return Align(
        alignment: isSquare ? Alignment.topCenter : Alignment.center,
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Log.debug('Web video tap detected for ${widget.video.id.substring(0, 8)}...', name: 'VideoFeedItem', category: LogCategory.ui);
                if (_controller != null && _controller!.value.isInitialized && !_controller!.value.hasError) {
                  Log.info('Web video tap conditions met, toggling play/pause', name: 'VideoFeedItem', category: LogCategory.ui);
                  _togglePlayPause();
                } else {
                  Log.error('Web video tap ignored - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}, hasError: ${_controller?.value.hasError}', name: 'VideoFeedItem', category: LogCategory.ui);
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
    return Align(
      alignment: isSquare ? Alignment.topCenter : Alignment.center,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: GestureDetector(
          onTap: () {
            Log.debug('Native video tap detected for ${widget.video.id.substring(0, 8)}...', name: 'VideoFeedItem', category: LogCategory.ui);
            if (_controller != null && _controller!.value.isInitialized && !_controller!.value.hasError) {
              Log.info('Native video tap conditions met, toggling play/pause', name: 'VideoFeedItem', category: LogCategory.ui);
              _togglePlayPause();
            } else {
              Log.error('Native video tap ignored - controller: ${_controller != null}, initialized: ${_controller?.value.isInitialized}, hasError: ${_controller?.value.hasError}', name: 'VideoFeedItem', category: LogCategory.ui);
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
                _getUserFriendlyErrorMessage(videoState.errorMessage!),
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
              _getUserFriendlyErrorMessage(message),
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
              SelectableText(
                widget.video.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
            ],
            
            // Video content/description
            if (widget.video.content.isNotEmpty) ...[
              ClickableHashtagText(
                text: widget.video.content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 3,
                onVideoStateChange: _pauseVideo,
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

  Widget _buildVideoInfoBelow() {
    return Container(
      color: Colors.black,
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
            SelectableText(
              widget.video.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
          ],
          
          // Video content/description
          if (widget.video.content.isNotEmpty) ...[
            ClickableHashtagText(
              text: widget.video.content,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 3,
              onVideoStateChange: _pauseVideo,
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
    return Consumer2<UserProfileService, AuthService>(
      builder: (context, profileService, authService, child) {
        final profile = profileService.getCachedProfile(widget.video.pubkey);
        final displayName = profile?.displayName ?? 
                           profile?.name ?? 
                           '@${widget.video.pubkey.substring(0, 8)}...';
        
        // Check if this is the current user's video
        final isOwnVideo = authService.currentPublicKeyHex == widget.video.pubkey;
        
        return Row(
          children: [
            const Icon(
              Icons.person,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                Log.verbose('Navigating to profile: ${widget.video.pubkey}', name: 'VideoFeedItem', category: LogCategory.ui);
                // Pause video before navigating away
                _pauseVideo();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      profilePubkey: widget.video.pubkey,
                    ),
                  ),
                ).then((_) {
                  // Resume video when returning (only if still active)
                  if (widget.isActive && _controller != null) {
                    _playVideo();
                  }
                });
              },
              child: Row(
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  // Add NIP-05 verification badge if verified
                  if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ],
                ],
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
            // Add follow button if not own video
            if (!isOwnVideo) ...[
              const SizedBox(width: 12),
              Consumer<SocialService>(
                builder: (context, socialService, child) {
                  final isFollowing = socialService.isFollowing(widget.video.pubkey);
                  return ElevatedButton(
                    onPressed: () => _handleFollow(context, socialService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey[700] : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: const Size(60, 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRepostAttribution() {
    return Consumer<UserProfileService>(
      builder: (context, profileService, child) {
        if (widget.video.reposterPubkey == null) {
          return const SizedBox.shrink();
        }
        
        final repostProfile = profileService.getCachedProfile(widget.video.reposterPubkey!);
        final reposterName = repostProfile?.displayName ?? 
                           repostProfile?.name ?? 
                           '@${widget.video.reposterPubkey!.substring(0, 8)}...';
        
        return Row(
          children: [
            const Icon(
              Icons.repeat,
              color: Colors.green,
              size: 16,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                Log.verbose('Navigating to reposter profile: ${widget.video.reposterPubkey}', name: 'VideoFeedItem', category: LogCategory.ui);
                // Pause video before navigating away
                _pauseVideo();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      profilePubkey: widget.video.reposterPubkey!,
                    ),
                  ),
                ).then((_) {
                  // Resume video when returning (only if still active)
                  if (widget.isActive && _controller != null) {
                    _playVideo();
                  }
                });
              },
              child: Text(
                'Reposted by $reposterName',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      },
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
          
          // Comment button with lazy loading count
          Stack(
            alignment: Alignment.center,
            children: [
              _buildActionButton(
                icon: Icons.comment_outlined,
                onPressed: () => _handleCommentTap(context),
              ),
              Positioned(
                top: 32,
                child: Text(
                  _hasLoadedComments 
                    ? (_commentCount != null && _commentCount! > 0 ? _commentCount!.toString() : '')
                    : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          // Repost button
          Consumer<SocialService>(
            builder: (context, socialService, child) {
              final hasReposted = socialService.hasReposted(widget.video.id);
              return _buildActionButton(
                icon: Icons.repeat,
                color: hasReposted ? Colors.green : Colors.white,
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
      Log.error('Error getting comment count: $e', name: 'VideoFeedItem', category: LogCategory.ui);
      return 0;
    }
  }

  /// Handle comment icon tap - loads comments lazily and then opens comments screen
  Future<void> _handleCommentTap(BuildContext context) async {
    if (!_hasLoadedComments) {
      try {
        setState(() {
          _hasLoadedComments = true; // Show loading state immediately
        });
        
        final count = await _getCommentCount();
        setState(() {
          _commentCount = count;
        });
      } catch (e) {
        Log.error('Error loading comment count: $e', name: 'VideoFeedItem', category: LogCategory.ui);
        setState(() {
          _commentCount = 0;
        });
      }
    }
    
    _openComments(context);
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
    // Pause video before showing share menu
    _pauseVideo();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(
        video: widget.video,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    ).then((_) {
      // Resume video when share menu is dismissed (only if still active)
      if (widget.isActive && _controller != null) {
        _playVideo();
      }
    });
  }

  void _handleFollow(BuildContext context, SocialService socialService) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to follow users'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final isFollowing = socialService.isFollowing(widget.video.pubkey);
      if (isFollowing) {
        await socialService.unfollowUser(widget.video.pubkey);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User unfollowed'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } else {
        await socialService.followUser(widget.video.pubkey);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User followed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow/unfollow user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  /// Convert technical error messages to user-friendly messages
  String _getUserFriendlyErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    
    if (lowerError.contains('404') || lowerError.contains('not found')) {
      return 'Video not found';
    } else if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Check your internet connection';
    } else if (lowerError.contains('timeout')) {
      return 'Loading timed out';
    } else if (lowerError.contains('format') || lowerError.contains('codec')) {
      return 'Video format not supported';
    } else if (lowerError.contains('permission') || lowerError.contains('unauthorized')) {
      return 'Access denied';
    } else {
      return 'Unable to play video';
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