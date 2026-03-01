// ABOUTME: Full-width inline video player for video comments.
// ABOUTME: Shows thumbnail with play overlay, tap to play inline.
// ABOUTME: Auto-pauses when scrolled off screen, auto-plays next.
// ABOUTME: NOT gated by feature flag — always displays video comments.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Full-width inline video player for video comment replies.
///
/// Displays a thumbnail with a play overlay. On tap, initializes
/// the video player and plays inline.
/// Auto-pauses when scrolled off screen.
/// When [autoPlayNotifier] is provided, auto-plays the next visible
/// video when the user scrolls past one that was playing.
class VideoCommentPlayer extends StatefulWidget {
  const VideoCommentPlayer({
    required this.videoUrl,
    this.thumbnailUrl,
    this.blurhash,
    this.autoPlayNotifier,
    super.key,
  });

  /// URL of the video to play.
  final String videoUrl;

  /// Optional thumbnail URL to show before playing.
  final String? thumbnailUrl;

  /// Optional blurhash for placeholder while thumbnail loads.
  final String? blurhash;

  /// Shared notifier to coordinate auto-play between video comments.
  /// When true, the next visible video will auto-play.
  final ValueNotifier<bool>? autoPlayNotifier;

  @override
  State<VideoCommentPlayer> createState() => _VideoCommentPlayerState();
}

class _VideoCommentPlayerState extends State<VideoCommentPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitializing = false;
  bool _isMuted = true;
  bool _isVisible = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.5;

    if (wasVisible && !_isVisible && _isPlaying) {
      _controller?.pause();
      widget.autoPlayNotifier?.value = true;
    } else if (!wasVisible && _isVisible) {
      if (widget.autoPlayNotifier?.value == true) {
        widget.autoPlayNotifier?.value = false;
        _play();
      }
    }
  }

  Future<void> _play() async {
    if (_isInitializing) return;

    if (_controller == null) {
      setState(() => _isInitializing = true);

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      try {
        await controller.initialize();
        await controller.setVolume(1);
        await controller.setLooping(true);

        if (!mounted) {
          controller.dispose();
          return;
        }

        controller.addListener(_onVideoStateChanged);
        _controller = controller;
        _isMuted = false;
        await controller.play();

        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isInitializing = false;
          });
        }
      } on Exception {
        controller.dispose();
        if (mounted) {
          setState(() => _isInitializing = false);
        }
      }
    } else {
      if (_isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
    }
  }

  Future<void> _toggleMute() async {
    if (_controller == null) return;
    final newMuted = !_isMuted;
    await _controller!.setVolume(newMuted ? 0 : 1);
    if (mounted) {
      setState(() => _isMuted = newMuted);
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;
    final isPlaying = _controller?.value.isPlaying ?? false;
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-comment-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.containerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _controller != null && _controller!.value.isInitialized
                ? GestureDetector(
                    onTap: _play,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(_controller!),
                        if (!_isPlaying) const _PlayOverlay(),
                        if (_isPlaying)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _MuteButton(
                              isMuted: _isMuted,
                              onTap: _toggleMute,
                            ),
                          ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _play,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.thumbnailUrl != null)
                          Image.network(
                            widget.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _VideoPlaceholder(),
                          )
                        else
                          const _VideoPlaceholder(),
                        if (_isInitializing)
                          const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: VineTheme.onSurface,
                              ),
                            ),
                          )
                        else
                          const _PlayOverlay(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Play button overlay centered on the video thumbnail.
class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          color: VineTheme.onSurface,
          size: 24,
        ),
      ),
    );
  }
}

/// Mute/unmute toggle button for video playback.
class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onTap});

  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isMuted ? Icons.volume_off : Icons.volume_up,
          color: VineTheme.onSurface,
          size: 18,
        ),
      ),
    );
  }
}

/// Placeholder when no thumbnail is available.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VineTheme.containerLow,
      child: const Center(
        child: Icon(Icons.videocam, color: VineTheme.onSurfaceMuted, size: 32),
      ),
    );
  }
}
