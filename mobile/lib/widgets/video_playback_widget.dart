// ABOUTME: Reusable video playback widget using consolidated VideoPlaybackController
// ABOUTME: Provides consistent video behavior with configuration-based customization

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../services/video_playback_controller.dart';
import '../theme/vine_theme.dart';

/// Reusable video widget with consolidated playback behavior
class VideoPlaybackWidget extends StatefulWidget {
  final VideoEvent video;
  final VideoPlaybackConfig config;
  final bool isActive;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Function(String)? onError;
  final EdgeInsetsGeometry? overlayPadding;
  final List<Widget>? overlayWidgets;
  final bool showControls;
  final bool showPlayPauseIcon;

  const VideoPlaybackWidget({
    super.key,
    required this.video,
    this.config = VideoPlaybackConfig.feed,
    this.isActive = true,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.onDoubleTap,
    this.onError,
    this.overlayPadding,
    this.overlayWidgets,
    this.showControls = false,
    this.showPlayPauseIcon = true,
  });

  /// Create widget configured for feed videos
  static VideoPlaybackWidget feed({
    Key? key,
    required VideoEvent video,
    required bool isActive,
    VoidCallback? onTap,
    Function(String)? onError,
    List<Widget>? overlayWidgets,
  }) {
    return VideoPlaybackWidget(
      key: key,
      video: video,
      config: VideoPlaybackConfig.feed,
      isActive: isActive,
      onTap: onTap,
      onError: onError,
      overlayWidgets: overlayWidgets,
      showPlayPauseIcon: true,
    );
  }

  /// Create widget configured for fullscreen videos
  static VideoPlaybackWidget fullscreen({
    Key? key,
    required VideoEvent video,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    Function(String)? onError,
    List<Widget>? overlayWidgets,
  }) {
    return VideoPlaybackWidget(
      key: key,
      video: video,
      config: VideoPlaybackConfig.fullscreen,
      isActive: true,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onError: onError,
      overlayWidgets: overlayWidgets,
      showPlayPauseIcon: true,
    );
  }

  /// Create widget configured for preview/thumbnail videos
  static VideoPlaybackWidget preview({
    Key? key,
    required VideoEvent video,
    Widget? placeholder,
    VoidCallback? onTap,
    Function(String)? onError,
  }) {
    return VideoPlaybackWidget(
      key: key,
      video: video,
      config: VideoPlaybackConfig.preview,
      isActive: false,
      placeholder: placeholder,
      onTap: onTap,
      onError: onError,
      showPlayPauseIcon: false,
    );
  }

  @override
  State<VideoPlaybackWidget> createState() => _VideoPlaybackWidgetState();
}

class _VideoPlaybackWidgetState extends State<VideoPlaybackWidget> 
    with TickerProviderStateMixin {
  
  late VideoPlaybackController _playbackController;
  late AnimationController _playPauseIconController;
  late Animation<double> _playPauseIconAnimation;
  bool _showPlayPauseIcon = false;

  @override
  void initState() {
    super.initState();
    
    _playbackController = VideoPlaybackController(
      video: widget.video,
      config: widget.config,
    );
    
    _playPauseIconController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _playPauseIconAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _playPauseIconController,
      curve: Curves.elasticOut,
    ));

    _playbackController.addListener(_onPlaybackStateChange);
    _playbackController.events.listen(_onPlaybackEvent);
    
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlaybackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      _playbackController.setActive(widget.isActive);
    }
  }

  @override
  void dispose() {
    _playPauseIconController.dispose();
    _playbackController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      await _playbackController.initialize();
      _playbackController.setActive(widget.isActive);
    } catch (e) {
      widget.onError?.call('Failed to initialize video: $e');
    }
  }

  void _onPlaybackStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onPlaybackEvent(VideoPlaybackEvent event) {
    if (event is VideoError) {
      widget.onError?.call(event.message);
    }
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      // Default behavior: toggle play/pause
      _playbackController.togglePlayPause();
      if (widget.showPlayPauseIcon) {
        _showPlayPauseIconBriefly();
      }
    }
  }

  void _handleDoubleTap() {
    if (widget.onDoubleTap != null) {
      widget.onDoubleTap!();
    }
  }

  void _showPlayPauseIconBriefly() {
    if (!_playbackController.isInitialized) return;
    
    setState(() {
      _showPlayPauseIcon = true;
    });
    
    _playPauseIconController.forward().then((_) {
      _playPauseIconController.reverse();
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIcon = false;
        });
      }
    });
  }

  /// Navigation helper for consistent pause/resume behavior
  Future<T?> navigateWithPause<T>(Widget destination) async {
    return _playbackController.navigateWithPause(() async {
      return Navigator.of(context).push<T>(
        MaterialPageRoute(builder: (context) => destination),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // Main video content
          _buildVideoContent(),
          
          // Custom overlay widgets
          if (widget.overlayWidgets != null)
            ...widget.overlayWidgets!,
          
          // Play/pause icon overlay
          if (_showPlayPauseIcon && widget.showPlayPauseIcon)
            _buildPlayPauseIconOverlay(),
          
          // Touch handlers
          Positioned.fill(
            child: GestureDetector(
              onTap: _handleTap,
              onDoubleTap: _handleDoubleTap,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    switch (_playbackController.state) {
      case VideoPlaybackState.notInitialized:
      case VideoPlaybackState.initializing:
        return _buildLoadingState();
        
      case VideoPlaybackState.ready:
      case VideoPlaybackState.playing:
      case VideoPlaybackState.paused:
      case VideoPlaybackState.buffering:
        return _buildVideoPlayer();
        
      case VideoPlaybackState.error:
        return _buildErrorState();
        
      case VideoPlaybackState.disposed:
        return _buildDisposedState();
    }
  }

  Widget _buildVideoPlayer() {
    final controller = _playbackController.controller;
    if (controller == null) {
      return _buildLoadingState();
    }

    // Check if video is square for alignment
    final aspectRatio = _playbackController.aspectRatio;
    final isSquare = aspectRatio > 0.9 && aspectRatio < 1.1;

    return Align(
      alignment: isSquare ? Alignment.topCenter : Alignment.center,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildLoadingState() {
    return widget.placeholder ?? 
      Container(
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

  Widget _buildErrorState() {
    return widget.errorWidget ?? 
      Container(
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
              const Text(
                'Video Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_playbackController.errorMessage != null)
                Text(
                  _playbackController.errorMessage!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _playbackController.retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
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

  Widget _buildPlayPauseIconOverlay() {
    final isPlaying = _playbackController.isPlaying;
    
    return AnimatedBuilder(
      animation: _playPauseIconAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Transform.scale(
              scale: _playPauseIconAnimation.value,
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
}