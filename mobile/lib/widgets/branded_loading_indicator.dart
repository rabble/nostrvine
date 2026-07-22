// ABOUTME: Branded loading indicator using sprite sheet animation
// ABOUTME: Efficient GPU-based rendering with single texture, cached frames

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:unified_logger/unified_logger.dart';

/// A branded loading indicator that displays the animated Divine logo.
///
/// Uses a sprite sheet for efficient GPU rendering. The sprite sheet contains
/// [frameCount] square frames arranged vertically. Animation cycles through
/// frames using an AnimationController for smooth, consistent playback.
///
/// Benefits over GIF:
/// - Single texture load (GPU efficient)
/// - No per-frame decoding
/// - Consistent animation across widget rebuilds
/// - Better performance on repeated displays
class BrandedLoadingIndicator extends StatefulWidget {
  const BrandedLoadingIndicator({super.key, this.size = 80.0});

  /// Sprite sheet backing the animation: the Divine brand mark
  /// (`assets/icon/divine_mark.svg`) in white, drawn as a wing-flap cycle.
  @visibleForTesting
  static const String spriteAsset = 'assets/loading-brand-sprite.png';

  /// Number of square frames stacked vertically in [spriteAsset].
  ///
  /// Slicing depends on this matching the sheet exactly, so
  /// `branded_loading_indicator_test.dart` pins it against the asset.
  @visibleForTesting
  static const int frameCount = 27;

  /// The size (width and height) of the loading indicator.
  final double size;

  @override
  State<BrandedLoadingIndicator> createState() =>
      _BrandedLoadingIndicatorState();
}

class _BrandedLoadingIndicatorState extends State<BrandedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _frameCount = BrandedLoadingIndicator.frameCount;
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
        BrandedLoadingIndicator.spriteAsset,
        width: widget.size,
        height: widget.size * _frameCount,
        fit: BoxFit.fitWidth,
        errorBuilder: (context, error, stackTrace) {
          Log.warning(
            'Failed to load sprite sheet: $error',
            name: 'BrandedLoadingIndicator',
            category: LogCategory.ui,
          );
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  VineTheme.onSurfaceMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
