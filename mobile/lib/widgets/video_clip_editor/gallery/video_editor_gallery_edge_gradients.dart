// ABOUTME: Edge gradient overlays for clip gallery
// ABOUTME: Darkens left and right edges to focus attention on centered clip

import 'package:flutter/material.dart';

/// Edge gradient overlays that darken the left and right sides of the gallery.
///
/// These gradients fade in when a clip is near center, helping to focus
/// visual attention on the centered clip by darkening adjacent areas.
class ClipGalleryEdgeGradients extends StatelessWidget {
  /// Creates edge gradient overlays.
  const ClipGalleryEdgeGradients({
    required this.opacity,
    required this.isReordering,
    super.key,
  });

  /// Opacity of the gradients (0.0-1.0).
  final double opacity;

  /// Whether the gallery is in reordering mode.
  ///
  /// When true, the center transparent area is removed for a solid gradient.
  final bool isReordering;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity * 0.65,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF000A06),
                if (!isReordering) const Color(0x00000A06),
                const Color(0xFF000A06),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
