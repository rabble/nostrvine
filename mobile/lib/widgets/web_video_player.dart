// ABOUTME: Web-native video player using Flutter's video_player package
// ABOUTME: Drop-in replacement for media_kit Video widget on web platforms

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hls_auth_web_player/hls_auth_web_player.dart' as hls_auth;
import 'package:video_player/video_player.dart';

typedef WebVideoPlayerControllerFactory =
    VideoPlayerController Function({
      required Uri url,
      required Map<String, String> headers,
    });

VideoPlayerController defaultWebVideoPlayerControllerFactory({
  required Uri url,
  required Map<String, String> headers,
}) => VideoPlayerController.networkUrl(url, httpHeaders: headers);

/// A simple video player widget for web that uses Flutter's video_player
/// package (backed by HTML5 video element via video_player_web_hls).
///
/// When [authHeaderProvider] is non-null AND running on web, the widget
/// swaps in the `HlsAuthWebPlayer` which attaches NIP-98 auth headers per
/// segment. Callers are expected to gate [authHeaderProvider] on
/// `kIsWeb && FeatureFlag.hlsAuthWebPlayer` — when either condition is
/// false, pass `null` to preserve the legacy behavior.
class WebVideoPlayer extends StatefulWidget {
  /// Creates a web video player.
  const WebVideoPlayer({
    required this.url,
    this.autoPlay = false,
    this.looping = true,
    this.fit = BoxFit.cover,
    this.headers = const {},
    this.onInitialized,
    this.onDisposed,
    this.onError,
    this.onRequiresAuth,
    this.initializeTimeout = const Duration(seconds: 8),
    this.controllerFactory = defaultWebVideoPlayerControllerFactory,
    this.authHeaderProvider,
    this.hlsFallbackUrl,
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

  /// HTTP headers for the video request (legacy path only).
  final Map<String, String> headers;

  /// Called when the video controller is initialized (legacy path only).
  final ValueChanged<VideoPlayerController>? onInitialized;

  /// Called when the underlying [VideoPlayerController] has been disposed.
  ///
  /// Use this to release any external references that mirror the controller
  /// (for example, feed-level caches) so they don't leak.
  final VoidCallback? onDisposed;

  /// Called when an error occurs.
  final VoidCallback? onError;

  /// Called when the NIP-98 path reports the origin needs viewer auth
  /// (`401`/`403`). The feed layer translates this into the
  /// `ageRestricted` playback status.
  final VoidCallback? onRequiresAuth;

  /// Maximum time to wait for the underlying HTML5 player to initialize.
  final Duration initializeTimeout;

  /// Factory used to create the underlying controller (legacy path).
  final WebVideoPlayerControllerFactory controllerFactory;

  /// Provides NIP-98 `Authorization` header values for per-segment signing.
  /// When non-null and running on web, the widget routes playback through
  /// `HlsAuthWebPlayer`. When null, the legacy `VideoPlayerController` path
  /// is used (preserves all existing behavior).
  final hls_auth.AuthHeaderProvider? authHeaderProvider;

  /// Optional HLS manifest to try if the primary MP4 source fails with a
  /// non-auth error. Only used on the NIP-98 path.
  final String? hlsFallbackUrl;

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

  bool get _useAuthPlayer => kIsWeb && widget.authHeaderProvider != null;

  @override
  void initState() {
    super.initState();
    if (!_useAuthPlayer) {
      _initializeController();
    }
  }

  @override
  void didUpdateWidget(WebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUseAuthPlayer = kIsWeb && oldWidget.authHeaderProvider != null;
    final authModeChanged = oldUseAuthPlayer != _useAuthPlayer;
    final urlChanged = oldWidget.url != widget.url;

    if (authModeChanged || urlChanged) {
      _disposeController();
      if (!_useAuthPlayer) {
        _initializeController();
      }
    }
  }

  Future<void> _initializeController() async {
    final controller = widget.controllerFactory(
      url: Uri.parse(widget.url),
      headers: widget.headers,
    );
    _controller = controller;

    try {
      await controller.initialize().timeout(widget.initializeTimeout);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(widget.looping);
      setState(() => _isInitialized = true);
      widget.onInitialized?.call(controller);

      if (widget.autoPlay) {
        try {
          await controller.play();
        } on Exception {
          // Browser autoplay policy can reject play() after the media is
          // fully initialized. Keep the player available instead of showing
          // a false load failure.
        }
      }
    } on Exception {
      await controller.dispose();
      if (!mounted) return;
      if (identical(_controller, controller)) {
        _controller = null;
      }
      if (!mounted) return;
      setState(() => _hasError = true);
      widget.onError?.call();
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    _hasError = false;
    if (controller != null) {
      controller.dispose();
      widget.onDisposed?.call();
    }
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
    if (_useAuthPlayer) {
      return _HlsAuthPlayerShim(
        url: widget.url,
        hlsFallbackUrl: widget.hlsFallbackUrl,
        authHeader: widget.authHeaderProvider!,
        onError: widget.onError,
        onRequiresAuth: widget.onRequiresAuth,
      );
    }

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = constraints.biggest;
          final fittedSize = _fittedVideoSize(
            videoSize: controller.value.size,
            viewportSize: viewportSize,
            fit: widget.fit,
          );

          return Center(
            child: ClipRect(
              child: OverflowBox(
                minWidth: fittedSize.width,
                maxWidth: fittedSize.width,
                minHeight: fittedSize.height,
                maxHeight: fittedSize.height,
                child: SizedBox(
                  width: fittedSize.width,
                  height: fittedSize.height,
                  // The underlying HTML video element can otherwise swallow
                  // taps that should go to the overlay action buttons.
                  child: IgnorePointer(
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Size _fittedVideoSize({
  required Size videoSize,
  required Size viewportSize,
  required BoxFit fit,
}) {
  if (videoSize.width <= 0 ||
      videoSize.height <= 0 ||
      !viewportSize.width.isFinite ||
      !viewportSize.height.isFinite ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0) {
    return videoSize;
  }

  final widthScale = viewportSize.width / videoSize.width;
  final heightScale = viewportSize.height / videoSize.height;

  final scale = switch (fit) {
    BoxFit.contain => math.min(widthScale, heightScale),
    BoxFit.cover => math.max(widthScale, heightScale),
    BoxFit.fill => null,
    BoxFit.fitWidth => widthScale,
    BoxFit.fitHeight => heightScale,
    BoxFit.none => 1.0,
    BoxFit.scaleDown => math.min(1.0, math.min(widthScale, heightScale)),
  };

  if (scale == null) {
    return viewportSize;
  }

  return Size(videoSize.width * scale, videoSize.height * scale);
}

class _HlsAuthPlayerShim extends StatelessWidget {
  const _HlsAuthPlayerShim({
    required this.url,
    required this.hlsFallbackUrl,
    required this.authHeader,
    required this.onError,
    required this.onRequiresAuth,
  });

  final String url;
  final String? hlsFallbackUrl;
  final hls_auth.AuthHeaderProvider authHeader;
  final VoidCallback? onError;
  final VoidCallback? onRequiresAuth;

  @override
  Widget build(BuildContext context) {
    return hls_auth.HlsAuthWebPlayer(
      url: url,
      hlsFallbackUrl: hlsFallbackUrl,
      authHeader: authHeader,
      onStatusChanged: (status) {
        switch (status) {
          case hls_auth.HlsAuthWebPlaybackStatus.requiresAuth:
            onRequiresAuth?.call();
          case hls_auth.HlsAuthWebPlaybackStatus.failure:
            onError?.call();
          case hls_auth.HlsAuthWebPlaybackStatus.idle:
          case hls_auth.HlsAuthWebPlaybackStatus.loading:
          case hls_auth.HlsAuthWebPlaybackStatus.ready:
            break;
        }
      },
      overlayBuilder: (context, status) {
        switch (status) {
          case hls_auth.HlsAuthWebPlaybackStatus.failure:
            return const _AuthPlayerFailureSurface();
          case hls_auth.HlsAuthWebPlaybackStatus.idle:
          case hls_auth.HlsAuthWebPlaybackStatus.loading:
            return const _AuthPlayerLoadingSurface();
          case hls_auth.HlsAuthWebPlaybackStatus.requiresAuth:
          case hls_auth.HlsAuthWebPlaybackStatus.ready:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _AuthPlayerLoadingSurface extends StatelessWidget {
  const _AuthPlayerLoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: VineTheme.backgroundColor,
      child: Center(
        child: CircularProgressIndicator(color: VineTheme.whiteText),
      ),
    );
  }
}

class _AuthPlayerFailureSurface extends StatelessWidget {
  const _AuthPlayerFailureSurface();

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
