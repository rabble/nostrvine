// ABOUTME: Paused-state overlay for the web video feed. Watches a
// ABOUTME: VideoPlayerController and renders the shared PausedAffordance
// ABOUTME: (pill + play icon) when the player is paused and not buffering.

import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_feed_item/paused_affordance.dart';
import 'package:video_player/video_player.dart';

/// Web equivalent of [PausedVideoPlayOverlay] — watches a
/// [VideoPlayerController] (from `package:video_player`) and renders the
/// shared [PausedAffordance] when the player is paused and not buffering.
///
/// Renders nothing when [controller] is `null` or not initialized.
class WebPausedVideoPlayOverlay extends StatefulWidget {
  const WebPausedVideoPlayOverlay({
    required this.controller,
    this.isVisible = true,
    super.key,
  });

  final VideoPlayerController? controller;
  final bool isVisible;

  @override
  State<WebPausedVideoPlayOverlay> createState() =>
      _WebPausedVideoPlayOverlayState();
}

class _WebPausedVideoPlayOverlayState extends State<WebPausedVideoPlayOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant WebPausedVideoPlayOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.removeListener(_onControllerTick);
      widget.controller?.addListener(_onControllerTick);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerTick);
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final value = controller.value;
    final shouldShowPaused = !value.isPlaying && !value.isBuffering;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: shouldShowPaused
          ? const PausedAffordance(key: ValueKey('paused-play'))
          : const SizedBox.shrink(),
    );
  }
}
