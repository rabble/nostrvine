// ABOUTME: Inline video attachment player for video comments.
// ABOUTME: Starts from thumbnail and plays the attached NIP-92 video in-place.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoCommentPlayer extends StatefulWidget {
  const VideoCommentPlayer({
    required this.videoUrl,
    this.thumbnailUrl,
    this.blurhash,
    this.borderRadius,
    this.onOpenVideo,
    super.key,
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final String? blurhash;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onOpenVideo;

  @override
  State<VideoCommentPlayer> createState() => _VideoCommentPlayerState();
}

class _VideoCommentPlayerState extends State<VideoCommentPlayer> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isMuted = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isInitializing) return;

    if (_controller == null) {
      setState(() => _isInitializing = true);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        controller.addListener(_syncPlaybackState);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _controller = controller;
        await controller.play();
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _isPlaying = true;
          });
        }
      } on Exception {
        await controller.dispose();
        if (mounted) setState(() => _isInitializing = false);
      }
      return;
    }

    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (mounted) setState(() => _isMuted = nextMuted);
  }

  void _syncPlaybackState() {
    if (!mounted) return;
    final nextPlaying = _controller?.value.isPlaying ?? false;
    if (nextPlaying != _isPlaying) {
      setState(() => _isPlaying = nextPlaying);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction < 0.35 &&
        (_controller?.value.isPlaying ?? false)) {
      _controller?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = VisibilityDetector(
      key: Key('video-comment-${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: VineTheme.containerLow),
          child: GestureDetector(
            onTap: _togglePlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller?.value.isInitialized ?? false)
                  VideoPlayer(_controller!)
                else if (widget.thumbnailUrl?.isNotEmpty ?? false)
                  VineCachedImage(
                    imageUrl: widget.thumbnailUrl!,
                    errorWidget: (_, _, _) => const _VideoPlaceholder(),
                  )
                else
                  const _VideoPlaceholder(),
                if (_isInitializing)
                  const Center(
                    child: SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VineTheme.onSurface,
                      ),
                    ),
                  )
                else if (!_isPlaying)
                  const _PlayOverlay(),
                if (_controller?.value.isInitialized ?? false)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _MuteButton(
                      isMuted: _isMuted,
                      onTap: _toggleMute,
                    ),
                  ),
                if (widget.onOpenVideo != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _OpenVideoButton(onTap: widget.onOpenVideo!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final borderRadius = widget.borderRadius;
    if (borderRadius == null) {
      return player;
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: player,
    );
  }
}

class _OpenVideoButton extends StatelessWidget {
  const _OpenVideoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: DivineIconName.arrowUpRight,
      semanticLabel: context.l10n.commentsOpenVideoLabel,
      size: DivineIconButtonSize.small,
      type: DivineIconButtonType.ghostSecondary,
      onPressed: onTap,
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim50,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: DivineIcon(
              icon: DivineIconName.play,
              color: VineTheme.whiteText,
            ),
          ),
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.isMuted, required this.onTap});

  final bool isMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: isMuted
          ? DivineIconName.speakerSimpleX
          : DivineIconName.speakerHigh,
      semanticLabel: isMuted
          ? context.l10n.commentsUnmuteVideoReplyLabel
          : context.l10n.commentsMuteVideoReplyLabel,
      size: DivineIconButtonSize.small,
      type: DivineIconButtonType.ghostSecondary,
      onPressed: onTap,
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: VineTheme.containerLow,
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.videoCamera,
          color: VineTheme.onSurfaceMuted,
          size: 32,
        ),
      ),
    );
  }
}
