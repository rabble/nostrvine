// ---------------------------------------------------------------------------
// Clip thumbnail strip — horizontal row of clip containers
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_constants.dart';

class VideoEditorTimelineClipStrip extends StatelessWidget {
  const VideoEditorTimelineClipStrip({
    required this.clips,
    required this.totalWidth,
    required this.pixelsPerSecond,
    super.key,
  });

  final List<DivineVideoClip> clips;
  final double totalWidth;
  final double pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineConstants.thumbnailStripHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < clips.length; i++) ...[
            if (i > 0) const SizedBox(width: TimelineConstants.clipGap),
            _ClipContainer(
              clip: clips[i],
              width: _clipWidth(clips[i]),
            ),
          ],
        ],
      ),
    );
  }

  double _clipWidth(DivineVideoClip clip) {
    if (clips.length == 1) return totalWidth;
    return clip.durationInSeconds * pixelsPerSecond;
  }
}

// ---------------------------------------------------------------------------
// Single clip — rounded border + thumbnail images filling the width
// ---------------------------------------------------------------------------

class _ClipContainer extends StatelessWidget {
  const _ClipContainer({
    required this.clip,
    required this.width,
  });

  final DivineVideoClip clip;
  final double width;

  @override
  Widget build(BuildContext context) {
    final thumbnailCount = (width / TimelineConstants.thumbnailWidth)
        .ceil()
        .clamp(1, 100);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          TimelineConstants.thumbnailRadius,
        ),
        border: Border.all(color: VineTheme.onSurfaceMuted),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          TimelineConstants.thumbnailRadius,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: width,
          height: TimelineConstants.thumbnailStripHeight,
          child: Row(
            children: [
              for (int i = 0; i < thumbnailCount; i++)
                SizedBox(
                  width: width / thumbnailCount,
                  height: TimelineConstants.thumbnailStripHeight,
                  child: _ThumbnailImage(
                    thumbnailPath: clip.thumbnailPath,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.thumbnailPath});

  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    if (thumbnailPath == null) {
      return const ColoredBox(color: VineTheme.surfaceContainerHigh);
    }

    return Image.file(
      File(thumbnailPath!),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: VineTheme.surfaceContainerHigh),
    );
  }
}
