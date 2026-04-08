part of 'video_editor_timeline_clip_strip.dart';

class _DraggedClipTile extends StatelessWidget {
  const _DraggedClipTile({
    required this.clip,
    required this.index,
    required this.fullWidth,
    required this.thumbnailNotifier,
  });

  final DivineVideoClip clip;
  final int index;
  final double fullWidth;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: .circular(TimelineConstants.thumbnailRadius),
        border: .all(color: VineTheme.primary, width: 2),
      ),
      child: Semantics(
        label: 'Dragging clip ${index + 1}',
        child: _ClipTile(
          clip: clip,
          fullWidth: fullWidth,
          thumbnailNotifier: thumbnailNotifier,
        ),
      ),
    );
  }
}

class _AccessibleClipTile extends StatelessWidget {
  const _AccessibleClipTile({
    required this.clip,
    required this.index,
    required this.total,
    required this.clipWidth,
    required this.thumbnailNotifier,
    required this.onReorder,
  });

  final DivineVideoClip clip;
  final int index;
  final int total;
  final double clipWidth;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final durationSec = clip.duration.inMilliseconds / 1000.0;
    return Semantics(
      label:
          'Clip ${index + 1} of $total, '
          '${durationSec.toStringAsFixed(1)} seconds',
      hint: total > 1 ? 'Long press to reorder' : null,
      customSemanticsActions: {
        if (index > 0)
          const CustomSemanticsAction(label: 'Move left'): () =>
              onReorder(index, index - 1),
        if (index < total - 1)
          const CustomSemanticsAction(label: 'Move right'): () =>
              onReorder(index, index + 1),
      },
      child: _ClipTile(
        clip: clip,
        fullWidth: clipWidth,
        thumbnailNotifier: thumbnailNotifier,
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.fullWidth,
    required this.thumbnailNotifier,
  });

  final DivineVideoClip clip;
  final double fullWidth;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: .circular(TimelineConstants.thumbnailRadius),
      child: FittedBox(
        fit: .cover,
        child: SizedBox(
          width: fullWidth,
          height: TimelineConstants.thumbnailStripHeight,
          child: ValueListenableBuilder<List<StripThumbnail>>(
            valueListenable: thumbnailNotifier,
            builder: (context, stripThumbnails, _) {
              return _ClipContainer(
                clip: clip,
                width: fullWidth,
                stripThumbnails: stripThumbnails,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Single clip — thumbnail images filling the width.
class _ClipContainer extends StatelessWidget {
  const _ClipContainer({
    required this.clip,
    required this.width,
    required this.stripThumbnails,
  });

  final DivineVideoClip clip;
  final double width;
  final List<StripThumbnail> stripThumbnails;

  int get _thumbnailCount =>
      (width / TimelineConstants.thumbnailWidth).ceil().clamp(1, 100);

  /// Maps a visual slot index to the nearest available [StripThumbnail] path.
  String? _thumbnailForSlot(int slotIndex, int slotCount) {
    if (stripThumbnails.isEmpty) return null;

    final durationMs = clip.duration.inMilliseconds;
    if (durationMs <= 0) return stripThumbnails.first.path;

    // Time at the center of this visual slot.
    final slotTimeMs = durationMs * (slotIndex + 0.5) / slotCount;

    // Find the thumbnail closest in time.
    var bestIndex = 0;
    var bestDist = (slotTimeMs - stripThumbnails[0].timestamp.inMilliseconds)
        .abs();
    for (var i = 1; i < stripThumbnails.length; i++) {
      final dist = (slotTimeMs - stripThumbnails[i].timestamp.inMilliseconds)
          .abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIndex = i;
      }
    }
    return stripThumbnails[bestIndex].path;
  }

  @override
  Widget build(BuildContext context) {
    final count = _thumbnailCount;

    return SizedBox(
      width: width,
      height: TimelineConstants.thumbnailStripHeight,
      child: Row(
        children: [
          for (int i = 0; i < count; i++)
            SizedBox(
              width: width / count,
              height: TimelineConstants.thumbnailStripHeight,
              child: _ThumbnailImage(
                thumbnailPath: clip.thumbnailPath,
                stripThumbnailPath: _thumbnailForSlot(i, count),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.thumbnailPath,
    this.stripThumbnailPath,
  });

  final String? thumbnailPath;
  final String? stripThumbnailPath;

  @override
  Widget build(BuildContext context) {
    final fallback = thumbnailPath != null
        ? Image.file(
            File(thumbnailPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: VineTheme.surfaceContainerHigh),
          )
        : const ColoredBox(color: VineTheme.surfaceContainerHigh);

    if (stripThumbnailPath == null) return fallback;

    return Image.file(
      File(stripThumbnailPath!),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
