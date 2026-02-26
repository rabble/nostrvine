// ABOUTME: Branded loading indicator using sprite sheet animation
// ABOUTME: Efficient GPU-based rendering with single texture, cached frames

import 'package:flutter/material.dart';

/// A branded loading indicator that displays the animated divine logo.
///
/// Uses a sprite sheet for efficient GPU rendering. The sprite sheet contains
/// 27 frames arranged vertically, each 500x500 pixels. Animation cycles through
/// frames using an AnimationController for smooth, consistent playback.
///
/// Benefits over GIF:
/// - Single texture load (GPU efficient)
/// - No per-frame decoding
/// - Consistent animation across widget rebuilds
/// - Better performance on repeated displays
class BrandedLoadingIndicator extends StatefulWidget {
  const BrandedLoadingIndicator({super.key, this.size = 80.0});

  /// The size (width and height) of the loading indicator.
  final double size;

  @override
  State<BrandedLoadingIndicator> createState() =>
      _BrandedLoadingIndicatorState();
}

class _BrandedLoadingIndicatorState extends State<BrandedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Sprite sheet configuration (original frames are 500x500 pixels)
  static const int _frameCount = 27;
  static const Duration _animationDuration = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _animationDuration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calculate current frame based on animation value
        final frameIndex = (_controller.value * _frameCount).floor();
        final clampedFrame = frameIndex.clamp(0, _frameCount - 1);

        // Calculate the vertical offset to show the correct frame
        final yOffset = -clampedFrame * widget.size;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: widget.size,
              maxHeight: widget.size * _frameCount,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/loading-brand-sprite.png',
        width: widget.size,
        height: widget.size * _frameCount,
        fit: BoxFit.fitWidth,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load sprite sheet: $error');
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
          );
        },
      ),
    );
  }
}
