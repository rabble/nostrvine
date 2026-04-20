import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hls_auth_web_player/src/auth_header_provider.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_controller.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_runtime.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_status.dart';
import 'package:hls_auth_web_player/src/runtime_factory.dart';

/// Builder for the per-status overlay widget (loading, failure,
/// requiresAuth, ready). The host app provides this so the player can stay
/// chrome-free and reuse the app's age-restricted overlay, dark placeholder,
/// etc.
typedef HlsAuthWebStatusBuilder =
    Widget Function(BuildContext context, HlsAuthWebPlaybackStatus status);

/// Web-only video player widget that wraps hls.js with NIP-98 auth support.
///
/// Exposes three host-provided pieces:
///
/// * [url] — the source URL. `.m3u8` triggers the HLS path, anything else
///   starts with direct MP4 via fetch + blob, then falls back to
///   [hlsFallbackUrl] on non-auth failure.
/// * [authHeader] — an async callback returning the full NIP-98 auth header
///   value for the given URL, or `null` when no header can be made.
/// * [overlayBuilder] — renders state-specific UI on top of the video
///   surface (loading spinner, age-restricted overlay, error fallback).
class HlsAuthWebPlayer extends StatefulWidget {
  /// Creates an [HlsAuthWebPlayer].
  HlsAuthWebPlayer({
    required this.url,
    required this.authHeader,
    this.hlsFallbackUrl,
    this.overlayBuilder,
    this.onStatusChanged,
    HlsAuthWebRuntime? runtime,
    super.key,
  }) : runtime = runtime ?? createDefaultHlsAuthWebRuntime();

  /// Primary source URL. `.m3u8` uses HLS, everything else starts on MP4.
  final String url;

  /// Optional HLS manifest used as a fallback when the primary MP4 path
  /// fails with a non-auth error (e.g. `404`).
  final String? hlsFallbackUrl;

  /// Callback providing the `Authorization` header for each request.
  final AuthHeaderProvider authHeader;

  /// Renders overlay UI keyed off the current status. Called on every
  /// status transition.
  final HlsAuthWebStatusBuilder? overlayBuilder;

  /// Optional observer for status transitions. Use to bridge the player's
  /// status into the app's `VideoPlaybackStatusCubit`.
  final ValueChanged<HlsAuthWebPlaybackStatus>? onStatusChanged;

  /// Runtime that drives the JS side. Tests inject a fake; production picks
  /// the web or unsupported runtime automatically.
  final HlsAuthWebRuntime runtime;

  @override
  State<HlsAuthWebPlayer> createState() => _HlsAuthWebPlayerState();
}

class _HlsAuthWebPlayerState extends State<HlsAuthWebPlayer> {
  late String _viewType;
  late HlsAuthWebController _controller;

  @override
  void initState() {
    super.initState();
    _viewType = _buildViewType(widget.url);
    _controller = _createController(widget);
    _controller.addListener(_onControllerUpdate);
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant HlsAuthWebPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url &&
        oldWidget.hlsFallbackUrl == widget.hlsFallbackUrl &&
        identical(oldWidget.runtime, widget.runtime)) {
      return;
    }
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    _viewType = _buildViewType(widget.url);
    _controller = _createController(widget);
    _controller.addListener(_onControllerUpdate);
    unawaited(_controller.load());
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    widget.onStatusChanged?.call(_controller.status);
    setState(() {});
  }

  HlsAuthWebController _createController(HlsAuthWebPlayer config) {
    return HlsAuthWebController(
      runtime: config.runtime,
      viewType: _viewType,
      url: config.url,
      authHeader: config.authHeader,
      hlsFallbackUrl: config.hlsFallbackUrl,
    );
  }

  String _buildViewType(String url) {
    final hash = url.hashCode.toUnsigned(32).toRadixString(16);
    // Each widget instance owns a distinct <video> element, even when the
    // same URL appears more than once in a feed.
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return 'hls-auth-web-player-$hash-$salt';
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayBuilder = widget.overlayBuilder;
    final status = _controller.status;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (kIsWeb) HtmlElementView(viewType: _viewType),
        if (overlayBuilder != null)
          Positioned.fill(child: overlayBuilder(context, status)),
      ],
    );
  }
}
