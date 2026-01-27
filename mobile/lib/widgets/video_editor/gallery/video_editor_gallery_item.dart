// ABOUTME: Single clip item widget for the gallery PageView
// ABOUTME: Handles scale, offset transformations and opacity animations

import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_preview.dart';

/// A single clip item in the clip gallery.
///
/// Applies scale and offset transformations based on distance from center.
/// Clips near center (< 0.2 distance) are faded out to be replaced by the
/// center overlay.
class VideoEditorGalleryItem extends StatelessWidget {
  /// Creates a clip gallery item.
  const VideoEditorGalleryItem({
    required this.clip,
    required this.index,
    this.isCurrentClip = false,
    required this.page,
    required this.scale,
    required this.xOffset,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  /// The clip to display.
  final RecordingClip clip;

  /// Index of this clip in the list.
  final int index;

  /// Whether this is the currently selected clip.
  final bool isCurrentClip;

  /// Current page position from PageController.
  final double page;

  /// Pre-calculated scale factor for this clip.
  final double scale;

  /// Pre-calculated horizontal offset for depth effect.
  final double xOffset;

  /// Callback when clip is tapped.
  final VoidCallback onTap;

  /// Callback when clip is long-pressed (optional).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final clipDifference = (index - page).abs();
    final opacity = (clipDifference / 0.2).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: Transform(
          transform: .identity()
            ..translateByDouble(xOffset, 0, 0, 1)
            ..scaleByDouble(scale, scale, scale, 1),
          alignment: .center,
          child: VideoClipPreview(
            key: ValueKey('Video-Clip-Preview-${clip.id}'),
            clip: clip,
            isCurrentClip: isCurrentClip,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }
}
