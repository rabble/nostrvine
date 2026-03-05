// ABOUTME: Overlay widget for the centered clip with shadows and transforms
// ABOUTME: Handles drag rotation, translation, scaling for reordering state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/video_editor_clip_preview.dart';

/// Overlay widget that renders the centered clip on top of the PageView.
///
/// This ensures the centered clip appears above adjacent clips with proper
/// z-ordering. Includes animated shadows, rotation during drag, and smooth
/// transitions.
class VideoEditorCenterClipOverlay extends ConsumerWidget {
  /// Creates a center clip overlay.
  const VideoEditorCenterClipOverlay({
    required this.clip,
    required this.currentClipIndex,
    required this.page,
    required this.shadowOpacity,
    required this.pageWidth,
    required this.isReordering,
    required this.dragOffsetNotifier,
    required this.dragYOffsetNotifier,
    required this.scale,
    required this.xOffset,
    super.key,
  });

  /// The clip to display in the center.
  final DivineVideoClip clip;

  /// The currently selected clip index.
  final int currentClipIndex;

  /// The current page position from PageController.
  final double page;

  /// Opacity for the shadow (0.0 to 1.0).
  final double shadowOpacity;

  /// Maximum width constraint from parent.
  final double pageWidth;

  /// Whether the clip is in reordering mode.
  final bool isReordering;

  /// Notifier for horizontal drag offset changes (rotation + X translation).
  final ValueNotifier<double> dragOffsetNotifier;

  /// Notifier for vertical drag offset changes (Y translation).
  final ValueNotifier<double> dragYOffsetNotifier;

  /// Pre-calculated scale factor for this clip.
  final double scale;

  /// Pre-calculated horizontal offset for depth effect.
  final double xOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageViewOffset = -(page - currentClipIndex) * pageWidth;
    return AnimatedBuilder(
      animation: Listenable.merge([dragOffsetNotifier, dragYOffsetNotifier]),
      builder: (_, _) {
        final dragOffset = dragOffsetNotifier.value;
        final dragYOffset = dragYOffsetNotifier.value;

        // Calculate rotation based on drag offset (-15° to +15°)
        final rotationAngle =
            (dragOffset / pageWidth) * 0.26; // ~15° in radians
        final transformMatrix = Matrix4.identity()
          ..scaleByDouble(scale, scale, scale, 1)
          ..rotateZ(isReordering ? rotationAngle : 0)
          ..translateByDouble(
            xOffset + pageViewOffset + (isReordering ? dragOffset : 0),
            isReordering ? dragYOffset : 0,
            0,
            1,
          );

        return RepaintBoundary(
          child: IgnorePointer(
            ignoring: !isReordering,
            child: Center(
              child: Transform(
                transform: transformMatrix,
                alignment: .center,
                child: SizedBox(
                  width: pageWidth,
                  child: VideoEditorClipPreview(
                    key: ValueKey('Video-Clip-Preview-${clip.id}'),
                    clip: clip,
                    isCurrentClip: true,
                    isReordering: isReordering,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
