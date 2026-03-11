// ABOUTME: HTML5 video player widget for Flutter web platform
// ABOUTME: Uses video_player package which renders via HTML5 video element on web

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A simple video player widget for Flutter web.
///
/// Uses the `video_player` package which renders via HTML5 `<video>` element
/// on web. Supports autoplay, looping, and tap-to-pause.
class WebVideoPlayer extends StatefulWidget {
  const WebVideoPlayer({
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoplay = true,
    super.key,
  });

  /// The URL of the video to play.
  final String videoUrl;

  /// Optional thumbnail URL shown while loading.
  final String? thumbnailUrl;

  /// Whether to start playing automatically.
  final bool autoplay;

  @override
  State<WebVideoPlayer> createState() => WebVideoPlayerState();
}

class WebVideoPlayerState extends State<WebVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(WebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _initController() {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null) {
      setState(() => _hasError = true);
      return;
    }

    _controller = VideoPlayerController.networkUrl(uri)
      ..setLooping(true)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _initialized = true);
            if (widget.autoplay) {
              _controller?.play();
            }
          })
          .catchError((Object error) {
            if (!mounted) return;
            setState(() => _hasError = true);
            debugPrint(
              'WebVideoPlayer: Failed to load ${widget.videoUrl}: $error',
            );
          });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _hasError = false;
  }

  /// Pause playback.
  void pause() => _controller?.pause();

  /// Resume playback.
  void play() => _controller?.play();

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: VineTheme.lightText,
            size: 48,
          ),
        ),
      );
    }

    if (!_initialized) {
      return ColoredBox(
        color: VineTheme.backgroundColor,
        child: _buildThumbnailOrLoading(),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(color: VineTheme.backgroundColor);
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailOrLoading() {
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const Center(
            child: CircularProgressIndicator(color: VineTheme.lightText),
          ),
        ],
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.lightText),
    );
  }
}
