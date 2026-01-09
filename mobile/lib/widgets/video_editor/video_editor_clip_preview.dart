// ABOUTME: Displays individual video clip thumbnail with aspect ratio
// ABOUTME: Shows thumbnail image or placeholder icon with rounded corners

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:video_player/video_player.dart';

/// Displays a video clip thumbnail with aspect ratio preserved.
class VideoClipPreview extends ConsumerStatefulWidget {
  /// Creates a video clip preview widget.
  const VideoClipPreview({
    required this.clip,
    super.key,
    this.isCurrentClip = false,
    this.isReordering = false,
    this.isDeletionZone = false,
    this.onTap,
    this.onLongPress,
  });

  /// The clip to display.
  final RecordingClip clip;

  /// Whether this is the currently selected/centered clip.
  final bool isCurrentClip;

  final bool isReordering;

  final bool isDeletionZone;

  /// Callback when the clip is tapped.
  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  @override
  ConsumerState<VideoClipPreview> createState() => _VideoClipPreviewState();
}

class _VideoClipPreviewState extends ConsumerState<VideoClipPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hadPlayed = false;

  @override
  void initState() {
    super.initState();

    // Only initialize if this is the current clip
    if (widget.isCurrentClip) {
      unawaited(_initializeVideoPlayer());

      // Listen to play/pause state changes
      ref.listenManual(videoEditorProvider.select((state) => state.isPlaying), (
        previous,
        next,
      ) {
        _handlePlaybackStateChange(next);
      });
    }
  }

  void _handlePlaybackStateChange(bool isPlaying) {
    if (_controller == null || !_isInitialized || !mounted) return;

    final shouldPlay = widget.isCurrentClip && isPlaying;

    if (shouldPlay && !_controller!.value.isPlaying) {
      _controller!.play();
    } else if (!shouldPlay && _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    final videoPath = await widget.clip.video.safeFilePath();

    _controller = VideoPlayerController.file(File(videoPath));
    await _controller?.initialize();

    // Add listener to detect when video ends
    _controller?.addListener(_videoPlayerListener);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _videoPlayerListener() {
    if (_controller == null || !mounted) return;

    final notifier = ref.read(videoEditorProvider.notifier);

    // Check if video has ended
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    notifier.updatePosition(_controller!.value.position);

    if (!_hadPlayed) {
      _hadPlayed = _controller?.value.isPlaying ?? false;
      setState(() {});
    }

    if (position >= duration &&
        duration > Duration.zero &&
        widget.isCurrentClip) {
      // Video has finished playing - pause the playback state
      notifier.pauseVideo();
      _controller?.pause();
      _controller?.seekTo(.zero);
    }
  }

  @override
  void didUpdateWidget(VideoClipPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Initialize video player when becoming current clip
    if (!oldWidget.isCurrentClip &&
        widget.isCurrentClip &&
        _controller == null) {
      unawaited(_initializeVideoPlayer());
    }

    // Dispose video player when no longer current clip
    if (oldWidget.isCurrentClip && !widget.isCurrentClip) {
      unawaited(_disposeController());
      _hadPlayed = false;
      _isInitialized = false;
    }

    // Handle playback when isCurrentClip changes
    if (oldWidget.isCurrentClip != widget.isCurrentClip) {
      final isPlaying = ref.read(videoEditorProvider).isPlaying;
      _handlePlaybackStateChange(isPlaying);
    }
  }

  Future<void> _disposeController() async {
    _controller?.removeListener(_videoPlayerListener);
    await _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.clip.aspectRatio.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: .circular(16),
              border: .all(
                color: widget.isDeletionZone
                    ? const Color(0xFFF44336) // Red when over delete zone
                    : widget.isReordering
                    ? const Color(0xFFEBDE3B) // Yellow when reordering
                    : const Color(0x00000000), // Transparent otherwise
                width: 4,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: ClipRRect(
              borderRadius: .circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show video player ONLY when this is the current clip
                  if (_isInitialized &&
                      _controller != null &&
                      widget.isCurrentClip)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: IgnorePointer(child: VideoPlayer(_controller!)),
                      ),
                    ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child:
                        (_controller != null && _controller!.value.isPlaying) ||
                            _hadPlayed
                        ? const SizedBox.shrink()
                        : widget.clip.thumbnailPath != null
                        ?
                          // Show thumbnail when not playing or not initialized
                          Image.file(
                            File(widget.clip.thumbnailPath!),
                            fit: .cover,
                          )
                        :
                          // Video thumbnail placeholder
                          Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
