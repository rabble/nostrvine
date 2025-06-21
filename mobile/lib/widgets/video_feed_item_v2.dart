// ABOUTME: TDD-driven video feed item widget with all loading states and error handling
// ABOUTME: Supports GIF and video playback with memory-efficient lifecycle management

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../services/video_manager_interface.dart';

/// Individual video item widget implementing TDD specifications
/// 
/// Key features:
/// - All loading states (loading, ready, error, disposed)
/// - GIF vs video handling
/// - Controller lifecycle management
/// - Error display and retry functionality
/// - Accessibility features
/// - Performance optimizations
class VideoFeedItemV2 extends StatefulWidget {
  final VideoEvent video;
  final bool isActive;
  final Function(String)? onVideoError;

  const VideoFeedItemV2({
    Key? key,
    required this.video,
    required this.isActive,
    this.onVideoError,
  }) : super(key: key);

  @override
  State<VideoFeedItemV2> createState() => _VideoFeedItemV2State();
}

class _VideoFeedItemV2State extends State<VideoFeedItemV2> {
  late IVideoManager _videoManager;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _initializeVideoManager();
  }

  @override
  void didUpdateWidget(VideoFeedItemV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle activation state changes
    if (widget.isActive != oldWidget.isActive) {
      _handleActivationChange();
    }
  }

  @override
  void dispose() {
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
      }
    } catch (e) {
      debugPrint('VideoFeedItemV2: VideoManager not found: $e');
      _lastError = 'Video system not available';
    }
  }

  void _handleActivationChange() {
    if (!_isInitialized) return;
    
    if (widget.isActive) {
      // Preload and potentially play video
      _videoManager.preloadVideo(widget.video.id);
      _updateController();
    } else {
      // Video became inactive - controller will be managed by VideoManager
      _controller = null;
    }
  }

  void _updateController() {
    if (!_isInitialized) return;
    
    final newController = _videoManager.getController(widget.video.id);
    if (newController != _controller) {
      setState(() {
        _controller = newController;
      });
    }
  }

  void _handleRetry() {
    if (!_isInitialized) return;
    
    setState(() {
      _lastError = null;
    });
    
    _videoManager.preloadVideo(widget.video.id);
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

        // Update controller reference
        _updateController();

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
          
          // Loading indicator (when loading)
          if (videoState.isLoading) _buildLoadingOverlay(),
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

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
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
            ],
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

}

/// Accessibility helper for video content
class VideoAccessibilityInfo extends StatelessWidget {
  final VideoEvent video;
  final VideoState? videoState;

  const VideoAccessibilityInfo({
    Key? key,
    required this.video,
    this.videoState,
  }) : super(key: key);

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