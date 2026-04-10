part of 'video_editor_timeline_clip_strip.dart';

class _TrimmableClipTile extends StatefulWidget {
  const _TrimmableClipTile({
    required this.clip,
    required this.clipWidth,
    required this.pixelsPerSecond,
    required this.thumbnailNotifier,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onTap,
    this.trimExpand = 0,
  });

  final DivineVideoClip clip;
  final double clipWidth;
  final double pixelsPerSecond;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;
  final ClipTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final VoidCallback? onTap;

  /// Extra horizontal padding on each side to keep the content at
  /// the original [clipWidth] while the parent [AnimatedPositioned]
  /// is wider for hit-testing.
  final double trimExpand;

  @override
  State<_TrimmableClipTile> createState() => _TrimmableClipTileState();
}

class _TrimmableClipTileState extends State<_TrimmableClipTile> {
  bool _isDragStarted = false;
  bool _leftAtLimit = false;
  bool _rightAtLimit = false;

  Duration _dxToDuration(double dx) {
    final seconds = dx / widget.pixelsPerSecond;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  void _onDragStart() {
    developer.log(
      'ClipTile._onDragStart clip=${widget.clip.id}',
      name: 'clip_trim',
    );
    _isDragStarted = false;
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    _isDragStarted = false;
    widget.onTrimDragChanged?.call(false);
  }

  void _onLeftDragUpdate(double dx) {
    developer.log(
      'ClipTile._onLeftDragUpdate dx=$dx clip=${widget.clip.id}',
      name: 'clip_trim',
    );
    final clip = widget.clip;
    final delta = _dxToDuration(dx);
    var newTrimStart = clip.trimStart + delta;

    final maxTrimStart =
        clip.duration - clip.trimEnd - TimelineConstants.minTrimDuration;

    var atLimit = false;

    if (newTrimStart < Duration.zero) {
      newTrimStart = Duration.zero;
      atLimit = true;
    } else if (newTrimStart > maxTrimStart) {
      newTrimStart = maxTrimStart;
      atLimit = true;
    }

    if (atLimit && !_leftAtLimit) {
      HapticFeedback.mediumImpact();
    }
    _leftAtLimit = atLimit;

    widget.onTrimChanged?.call(
      clipId: clip.id,
      trimStart: newTrimStart,
      trimEnd: clip.trimEnd,
      isStart: !_isDragStarted,
    );
    _isDragStarted = true;
  }

  void _onRightDragUpdate(double dx) {
    developer.log(
      'ClipTile._onRightDragUpdate dx=$dx clip=${widget.clip.id}',
      name: 'clip_trim',
    );
    final clip = widget.clip;
    // Dragging right handle left (negative dx) increases trimEnd.
    final delta = _dxToDuration(-dx);
    var newTrimEnd = clip.trimEnd + delta;

    final maxTrimEnd =
        clip.duration - clip.trimStart - TimelineConstants.minTrimDuration;

    var atLimit = false;

    if (newTrimEnd < Duration.zero) {
      newTrimEnd = Duration.zero;
      atLimit = true;
    } else if (newTrimEnd > maxTrimEnd) {
      newTrimEnd = maxTrimEnd;
      atLimit = true;
    }

    if (atLimit && !_rightAtLimit) {
      HapticFeedback.mediumImpact();
    }
    _rightAtLimit = atLimit;

    widget.onTrimChanged?.call(
      clipId: clip.id,
      trimStart: clip.trimStart,
      trimEnd: newTrimEnd,
      isStart: !_isDragStarted,
    );
    _isDragStarted = true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.trimExpand),
      child: TimelineTrimHandles(
        height: TimelineConstants.thumbnailStripHeight,
        onLeftDragUpdate: _onLeftDragUpdate,
        onRightDragUpdate: _onRightDragUpdate,
        onDragStart: _onDragStart,
        onDragEnd: _onDragEnd,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: _ClipTile(
            clip: widget.clip,
            fullWidth: widget.clip.durationInSeconds * widget.pixelsPerSecond,
            trimStartOffset:
                widget.clip.trimStart.inMilliseconds /
                1000.0 *
                widget.pixelsPerSecond,
            thumbnailNotifier: widget.thumbnailNotifier,
          ),
        ),
      ),
    );
  }
}

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
    this.onTap,
  });

  final DivineVideoClip clip;
  final int index;
  final int total;
  final double clipWidth;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;
  final void Function(int from, int to) onReorder;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final durationSec = clip.duration.inMilliseconds / 1000.0;
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(index) : null,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
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
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.fullWidth,
    required this.thumbnailNotifier,
    this.trimStartOffset = 0,
  });

  final DivineVideoClip clip;
  final double fullWidth;
  final ValueNotifier<List<StripThumbnail>> thumbnailNotifier;

  /// Pixel offset from the left to shift thumbnails for trim-start.
  final double trimStartOffset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: .circular(TimelineConstants.thumbnailRadius),
      child: OverflowBox(
        maxWidth: fullWidth,
        minWidth: fullWidth,
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: Offset(-trimStartOffset, 0),
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
  ///
  /// Slots map across the full clip duration so thumbnails stay at fixed
  /// positions regardless of trimming.
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
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: VineTheme.surfaceContainerHigh),
          )
        : const ColoredBox(color: VineTheme.surfaceContainerHigh);

    if (stripThumbnailPath == null) return fallback;

    return Image.file(
      File(stripThumbnailPath!),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
