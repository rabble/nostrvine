// ABOUTME: VideoPlayerWidget component for displaying videos with Chewie player integration
// ABOUTME: Handles video initialization, controls, error states, and lifecycle management

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_event.dart';

/// Video player widget with comprehensive state management
/// 
/// This widget handles video display using Chewie for enhanced controls
/// and provides proper lifecycle management including error handling,
/// loading states, and memory cleanup.
class VideoPlayerWidget extends StatefulWidget {
  /// The video event to display
  final VideoEvent videoEvent;
  
  /// The video player controller (may be null during initialization)
  final VideoPlayerController? controller;
  
  /// Whether this video is currently active (should auto-play)
  final bool isActive;
  
  /// Whether to show video controls
  final bool showControls;
  
  /// Callback when video reaches end
  final VoidCallback? onVideoEnd;
  
  /// Callback when video encounters an error
  final VoidCallback? onVideoError;
  
  /// Callback when video is tapped
  final VoidCallback? onVideoTap;

  const VideoPlayerWidget({
    super.key,
    required this.videoEvent,
    this.controller,
    this.isActive = false,
    this.showControls = true,
    this.onVideoEnd,
    this.onVideoError,
    this.onVideoTap,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  ChewieController? _chewieController;
  bool _hasError = false;
  String? _errorMessage;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reinitialize if controller changed
    if (widget.controller != oldWidget.controller) {
      _disposeChewieController();
      _initializePlayer();
    }
    
    // Handle active state changes
    if (widget.isActive != oldWidget.isActive) {
      _handleActiveStateChange();
    }
  }

  @override
  void dispose() {
    _disposeChewieController();
    super.dispose();
  }

  void _initializePlayer() {
    _hasError = false;
    _errorMessage = null;
    
    if (widget.controller == null) {
      setState(() {
        _isInitializing = true;
      });
      return;
    }

    try {
      if (widget.controller!.value.hasError) {
        _handleError('Video controller has error');
        return;
      }

      if (!widget.controller!.value.isInitialized) {
        setState(() {
          _isInitializing = true;
        });
        
        // Listen for initialization
        widget.controller!.addListener(_onControllerUpdate);
        return;
      }

      _createChewieController();
      
    } catch (e) {
      _handleError('Failed to initialize video player: $e');
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    
    try {
      final controller = widget.controller;
      if (controller == null) return;

      if (controller.value.hasError) {
        _handleError(controller.value.errorDescription ?? 'Video playback error');
        return;
      }

      if (controller.value.isInitialized && _chewieController == null) {
        setState(() {
          _isInitializing = false;
        });
        _createChewieController();
      }

      // Handle video end
      if (controller.value.position >= controller.value.duration) {
        widget.onVideoEnd?.call();
      }
      
    } catch (e) {
      _handleError('Controller update error: $e');
    }
  }

  void _createChewieController() {
    try {
      _chewieController = ChewieController(
        videoPlayerController: widget.controller!,
        autoPlay: widget.isActive,
        looping: false,
        showControls: widget.showControls,
        showControlsOnInitialize: false,
        errorBuilder: (context, errorMessage) {
          return _buildErrorWidget(errorMessage);
        },
      );
      
      setState(() {
        _isInitializing = false;
        _hasError = false;
      });
      
    } catch (e) {
      _handleError('Failed to create Chewie controller: $e');
    }
  }

  void _handleActiveStateChange() {
    if (_chewieController == null) return;
    
    try {
      if (widget.isActive) {
        _chewieController!.play();
      } else {
        _chewieController!.pause();
      }
    } catch (e) {
      debugPrint('Error handling active state change: $e');
    }
  }

  void _handleError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isInitializing = false;
    });
    
    widget.onVideoError?.call();
    debugPrint('VideoPlayerWidget error: $message');
  }

  void _disposeChewieController() {
    _chewieController?.dispose();
    _chewieController = null;
    
    // Remove listener if it was added
    try {
      widget.controller?.removeListener(_onControllerUpdate);
    } catch (e) {
      // Ignore disposal errors
    }
  }

  void _onRetryTap() {
    widget.onVideoError?.call();
    _initializePlayer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onVideoTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background thumbnail
            if (widget.videoEvent.thumbnailUrl != null)
              _buildThumbnail(),
            
            // Video player or states
            if (_hasError)
              _buildErrorWidget(_errorMessage ?? 'Video failed to load')
            else if (_isInitializing || widget.controller == null)
              _buildLoadingWidget()
            else if (_chewieController != null)
              _buildVideoPlayer()
            else
              _buildLoadingWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return CachedNetworkImage(
      imageUrl: widget.videoEvent.thumbnailUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Chewie(controller: _chewieController!);
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Initializing video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.black.withOpacity(0.8),
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
              'Video failed to load',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _onRetryTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap to retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}