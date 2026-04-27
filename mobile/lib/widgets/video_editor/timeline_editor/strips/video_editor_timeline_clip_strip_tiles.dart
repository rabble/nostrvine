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
  bool _leftAtLimit = false;
  bool _rightAtLimit = false;

  Duration _dxToDuration(double dx) {
    final seconds = dx / widget.pixelsPerSecond;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  void _onDragStart() {
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    widget.onTrimDragChanged?.call(false);
  }

  void _onLeftDragUpdate(double dx) {
    final clip = widget.clip;
    final delta = _dxToDuration(dx);
    var newTrimStart = clip.trimStart + delta;

    final maxTrimStart =
        clip.duration - clip.trimEnd - TimelineConstants.minTrimDuration;

    var atLimit = false;

    if (newTrimStart <= Duration.zero) {
      newTrimStart = Duration.zero;
      atLimit = true;
    } else if (newTrimStart >= maxTrimStart) {
      newTrimStart = maxTrimStart;
      atLimit = true;
    }

    if (atLimit && !_leftAtLimit) {
      HapticFeedback.mediumImpact();
    }
    _leftAtLimit = atLimit;

    widget.onTrimChanged?.call(
      clipId: clip.id,
      isStart: true,
      trimStart: newTrimStart,
      trimEnd: clip.trimEnd,
    );
  }

  void _onRightDragUpdate(double dx) {
    final clip = widget.clip;
    // Dragging right handle left (negative dx) increases trimEnd.
    final delta = _dxToDuration(-dx);
    var newTrimEnd = clip.trimEnd + delta;

    final maxTrimEnd =
        clip.duration - clip.trimStart - TimelineConstants.minTrimDuration;

    var atLimit = false;

    if (newTrimEnd <= Duration.zero) {
      newTrimEnd = Duration.zero;
      atLimit = true;
    } else if (newTrimEnd >= maxTrimEnd) {
      newTrimEnd = maxTrimEnd;
      atLimit = true;
    }

    if (atLimit && !_rightAtLimit) {
      HapticFeedback.mediumImpact();
    }
    _rightAtLimit = atLimit;

    widget.onTrimChanged?.call(
      clipId: clip.id,
      isStart: false,
      trimStart: clip.trimStart,
      trimEnd: newTrimEnd,
    );
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
        child: Semantics(
          label: context.l10n.videoEditorTimelineTrimClipSemanticLabel,
          hint: context.l10n.videoEditorTimelineTrimClipHint,
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
      ),
    );
  }
}

class _DraggedClipTile extends StatelessWidget {
  const _DraggedClipTile({
    required this.clip,
    required this.index,
    required this.pixelsPerSecond,
    required this.thumbnailNotifier,
  });

  final DivineVideoClip clip;
  final int index;
  final double pixelsPerSecond;
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
        label: context.l10n.videoEditorTimelineDraggingClipSemanticLabel(
          index + 1,
        ),
        child: _ClipTile(
          clip: clip,
          fullWidth: clip.durationInSeconds * pixelsPerSecond,
          trimStartOffset:
              clip.trimStart.inMilliseconds / 1000.0 * pixelsPerSecond,
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
    required this.pixelsPerSecond,
    required this.thumbnailNotifier,
    required this.onReorder,
    this.onTap,
  });

  final DivineVideoClip clip;
  final int index;
  final int total;
  final double clipWidth;
  final double pixelsPerSecond;
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
        label: context.l10n.videoEditorTimelineClipSemanticLabel(
          index + 1,
          total,
          durationSec.toStringAsFixed(1),
        ),
        hint: total > 1
            ? context.l10n.videoEditorTimelineClipReorderHint
            : null,
        customSemanticsActions: {
          if (index > 0)
            CustomSemanticsAction(
              label: context.l10n.videoEditorTimelineClipMoveLeft,
            ): () =>
                onReorder(index, index - 1),
          if (index < total - 1)
            CustomSemanticsAction(
              label: context.l10n.videoEditorTimelineClipMoveRight,
            ): () =>
                onReorder(index, index + 1),
        },
        child: _ClipTile(
          clip: clip,
          fullWidth: clip.durationInSeconds * pixelsPerSecond,
          trimStartOffset:
              clip.trimStart.inMilliseconds / 1000.0 * pixelsPerSecond,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // displayWidth: how wide the visible tile is (e.g. _reorderSize
          // during drag). contentWidth: the natural clip width that drives
          // thumbnail count — never changes during the reorder animation so
          // thumbnails don't swap content while the tile shrinks/grows.
          final displayWidth = math.max(fullWidth, constraints.maxWidth);
          return SizedBox(
            width: displayWidth,
            height: TimelineConstants.thumbnailStripHeight,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: double.infinity,
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(-trimStartOffset, 0),
                  child: ValueListenableBuilder<List<StripThumbnail>>(
                    valueListenable: thumbnailNotifier,
                    builder: (context, stripThumbnails, _) {
                      return _ClipContainer(
                        clip: clip,
                        displayWidth: displayWidth,
                        contentWidth: fullWidth,
                        stripThumbnails: stripThumbnails,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Single clip — thumbnail images filling the width.
class _ClipContainer extends StatelessWidget {
  const _ClipContainer({
    required this.clip,
    required this.displayWidth,
    required this.contentWidth,
    required this.stripThumbnails,
  });

  final DivineVideoClip clip;

  /// Visible tile width — used to size each slot so thumbnails fill the tile.
  final double displayWidth;

  /// Natural clip width at the current zoom — used for count and timestamp
  /// mapping so thumbnail content stays stable during the reorder animation.
  final double contentWidth;

  final List<StripThumbnail> stripThumbnails;

  int get _thumbnailCount {
    final natural = (contentWidth / TimelineConstants.thumbnailWidth).ceil();
    // Keep visual slot count independent from loading progress so the strip
    // does not collapse to a single slot while thumbnails are still streaming in.
    return natural.clamp(1, 1000);
  }

  /// Maps a visual slot index to a [StripThumbnail] path that falls
  /// within the slot's time range.
  ///
  /// Each slot owns a fixed time window `[slotStart, slotEnd)`. Only a
  /// thumbnail whose timestamp falls inside that window is returned.
  /// This guarantees a slot never changes its image once a matching
  /// thumbnail has been loaded — new thumbnails for *other* slots
  /// don't cause a reassignment.
  String? _thumbnailForSlot(int slotIndex, int slotCount) {
    if (stripThumbnails.isEmpty) return null;

    final durationMs = clip.duration.inMilliseconds;
    if (durationMs <= 0) return stripThumbnails.first.path;

    // Fixed time window for this slot.
    final slotStartMs = durationMs * slotIndex / slotCount;
    final slotEndMs = durationMs * (slotIndex + 1) / slotCount;
    final slotCenterMs = (slotStartMs + slotEndMs) / 2;

    // Binary search for the first thumbnail at or after slotStartMs.
    var lo = 0;
    var hi = stripThumbnails.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (stripThumbnails[mid].timestamp.inMilliseconds < slotStartMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    // Scan candidates within [slotStartMs, slotEndMs) and pick the
    // one closest to the slot center.
    String? bestPath;
    var bestDist = double.infinity;
    for (var i = lo; i < stripThumbnails.length; i++) {
      final tsMs = stripThumbnails[i].timestamp.inMilliseconds;
      if (tsMs >= slotEndMs) break;
      final dist = (tsMs - slotCenterMs).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestPath = stripThumbnails[i].path;
      }
    }

    return bestPath;
  }

  @override
  Widget build(BuildContext context) {
    final count = _thumbnailCount;
    // Scale slots up only for tiny clips shown inside a larger container
    // (e.g. the reorder tile where displayWidth > contentWidth). For normal
    // and long clips keep thumbnailWidth fixed so each image represents the
    // correct time span instead of stretching to fill the whole tile.
    final slotWidth = contentWidth < displayWidth
        ? math.max(TimelineConstants.thumbnailWidth, displayWidth / count)
        : TimelineConstants.thumbnailWidth;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheH = (TimelineConstants.thumbnailStripHeight * dpr).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          SizedBox(
            width: slotWidth,
            height: TimelineConstants.thumbnailStripHeight,
            child: _ThumbnailImage(
              cacheHeight: cacheH,
              thumbnailPath: clip.thumbnailPath,
              stripThumbnailPath: _thumbnailForSlot(i, count),
            ),
          ),
      ],
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.cacheHeight,
    required this.thumbnailPath,
    this.stripThumbnailPath,
  });

  final int cacheHeight;
  final String? thumbnailPath;
  final String? stripThumbnailPath;

  @override
  Widget build(BuildContext context) {
    final fallback = thumbnailPath != null
        ? Image.file(
            File(thumbnailPath!),
            fit: BoxFit.cover,
            cacheHeight: cacheHeight,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: VineTheme.surfaceContainerHigh),
          )
        : const ColoredBox(color: VineTheme.surfaceContainerHigh);

    if (stripThumbnailPath == null) return fallback;

    return Image.file(
      File(stripThumbnailPath!),
      fit: BoxFit.cover,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
