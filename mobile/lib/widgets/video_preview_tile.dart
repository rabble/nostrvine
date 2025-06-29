// ABOUTME: Lightweight video preview tile for explore screen with auto-play functionality
// ABOUTME: Optimized for grid/list display with automatic playback when visible

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../theme/vine_theme.dart';
import '../utils/unified_logger.dart';

/// Lightweight video preview widget for explore screens
/// Automatically plays when visible, pauses when scrolled away
class VideoPreviewTile extends StatefulWidget {
  final VideoEvent video;
  final bool isActive;
  final double? height;
  final VoidCallback? onTap;

  const VideoPreviewTile({
    super.key,
    required this.video,
    required this.isActive,
    this.height,
    this.onTap,
  });

  @override
  State<VideoPreviewTile> createState() => _VideoPreviewTileState();
}

class _VideoPreviewTileState extends State<VideoPreviewTile> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => false; // Don't keep alive to save memory

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      // Delay initialization slightly to ensure widget is mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeVideo();
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoPreviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeVideo();
      } else {
        _disposeVideo();
      }
    }
  }

  @override
  void dispose() {
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
      Log.debug('Initializing preview for ${widget.video.id.substring(0, 8)}...', name: 'VideoPreviewTile', category: LogCategory.ui);
      Log.debug('   Video URL: ${widget.video.videoUrl}', name: 'VideoPreviewTile', category: LogCategory.ui);
      Log.debug('   Thumbnail URL: ${widget.video.effectiveThumbnailUrl}', name: 'VideoPreviewTile', category: LogCategory.ui);
      
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl!),
      );
      
      _controller = controller;
      
      await controller.initialize();
      
      if (mounted && widget.isActive) {
        await controller.setLooping(true);
        await controller.setVolume(0); // Mute for preview
        await controller.play();
        
        setState(() {
          _isInitializing = false;
        });
        
        Log.info('Preview playing for ${widget.video.id.substring(0, 8)}', name: 'VideoPreviewTile', category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('Preview initialization failed for ${widget.video.id.substring(0, 8)}: $e', name: 'VideoPreviewTile', category: LogCategory.ui);
      Log.debug('   Video URL was: ${widget.video.videoUrl}', name: 'VideoPreviewTile', category: LogCategory.ui);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
        });
      }
    }
  }

  void _disposeVideo() {
    Log.debug('�️ Disposing preview for ${widget.video.id.substring(0, 8)}...', name: 'VideoPreviewTile', category: LogCategory.ui);
    _controller?.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or thumbnail
              if (_controller != null && _controller!.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else if (widget.video.effectiveThumbnailUrl != null)
                Image.network(
                  widget.video.effectiveThumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              // Loading indicator
              if (_isInitializing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),

              // Play button overlay (only show when not playing)
              if (!widget.isActive || _controller == null || !_controller!.value.isInitialized)
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),

              // Error overlay
              if (_hasError)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Failed to load',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
          size: 48,
        ),
      ),
    );
  }
}