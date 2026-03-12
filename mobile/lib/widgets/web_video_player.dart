// ABOUTME: Web-native video player using Flutter's video_player package
// ABOUTME: Drop-in replacement for media_kit Video widget on web platforms

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A simple video player widget for web that uses Flutter's video_player
/// package (backed by HTML5 video element via video_player_web_hls).
class WebVideoPlayer extends StatefulWidget {
  /// Creates a web video player.
  const WebVideoPlayer({
    required this.url,
    this.autoPlay = false,
    this.looping = true,
    this.fit = BoxFit.cover,
    this.headers = const {},
    this.onInitialized,
    this.onError,
    super.key,
  });

  /// The video URL to play.
  final String url;

  /// Whether to auto-play when initialized.
  final bool autoPlay;

  /// Whether to loop the video.
  final bool looping;

  /// How the video should fit within its container.
  final BoxFit fit;

  /// HTTP headers for the video request.
  final Map<String, String> headers;

  /// Called when the video controller is initialized.
  final ValueChanged<VideoPlayerController>? onInitialized;

  /// Called when an error occurs.
  final VoidCallback? onError;

  @override
  State<WebVideoPlayer> createState() => WebVideoPlayerState();
}

/// State for [WebVideoPlayer].
class WebVideoPlayerState extends State<WebVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  /// The video player controller for external access.
  VideoPlayerController? get controller => _controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(WebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _initializeController();
    }
  }

  Future<void> _initializeController() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: widget.headers,
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      await controller.setLooping(widget.looping);
      if (widget.autoPlay) {
        await controller.play();
      }

      setState(() => _isInitialized = true);
      widget.onInitialized?.call(controller);
    } on Exception {
      if (!mounted) return;
      setState(() => _hasError = true);
      widget.onError?.call();
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _hasError = false;
  }

  /// Plays the video.
  Future<void> play() async {
    await _controller?.play();
  }

  /// Pauses the video.
  Future<void> pause() async {
    await _controller?.pause();
  }

  /// Seeks to the given position.
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  /// Sets the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    await _controller?.setVolume(volume);
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: VineTheme.secondaryText,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to load video',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (!_isInitialized || controller == null) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.whiteText),
        ),
      );
    }

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          // The underlying HTML video element can otherwise swallow taps that
          // should go to the overlay action buttons.
          child: IgnorePointer(
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
