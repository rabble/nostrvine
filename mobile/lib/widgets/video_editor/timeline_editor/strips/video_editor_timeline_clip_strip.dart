// ---------------------------------------------------------------------------
// Clip thumbnail strip — horizontal row of clip containers
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_constants.dart';

class VideoEditorTimelineClipStrip extends StatefulWidget {
  const VideoEditorTimelineClipStrip({
    required this.clips,
    required this.totalWidth,
    required this.pixelsPerSecond,
    this.scrollController,
    this.onReorder,
    this.onReorderChanged,
    this.isInteracting = false,
    super.key,
  });

  final List<DivineVideoClip> clips;
  final double totalWidth;
  final double pixelsPerSecond;
  final ScrollController? scrollController;
  final ValueChanged<List<DivineVideoClip>>? onReorder;
  final ValueChanged<bool>? onReorderChanged;

  /// When `true` the user is scrolling or pinch-zooming — long press
  /// must not start a reorder drag.
  final bool isInteracting;

  @override
  State<VideoEditorTimelineClipStrip> createState() =>
      _VideoEditorTimelineClipStripState();
}

class _VideoEditorTimelineClipStripState
    extends State<VideoEditorTimelineClipStrip> {
  bool _isReordering = false;
  bool _isReorderExiting = false;
  bool _dragAnimating = false;
  int? _dragIndex;
  double _rowOffset = 0;
  double _dragClipWidth = 0;
  double _dragFingerRatio = 0.5;
  double _dragStartClipCenter = 0;
  late List<DivineVideoClip> _orderedClips;

  // Finger tracking — global X is the source of truth so that auto-scroll
  // and gesture callbacks never conflict.
  double _dragGlobalX = 0;
  double _dragStartGlobalX = 0;
  double _dragStartLocalX = 0;
  double _dragStartScrollOffset = 0;

  /// Current local finger X derived from global position + scroll delta.
  double get _effectiveLocalX {
    final scrollDelta =
        (widget.scrollController?.offset ?? 0) - _dragStartScrollOffset;
    return _dragGlobalX - _dragStartGlobalX + _dragStartLocalX + scrollDelta;
  }

  /// Thumbnail data keyed by clip ID — survives reordering.
  final Map<String, List<StripThumbnail>> _thumbnailCache = {};
  final Map<String, StreamSubscription<List<StripThumbnail>>> _subscriptions =
      {};

  static const double _reorderSize = TimelineConstants.thumbnailStripHeight;

  // Auto-scroll state.
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0;
  static const _autoScrollEdgeZone = 40.0;
  static const _maxAutoScrollPxPerFrame = 8.0;

  @override
  void initState() {
    super.initState();
    _orderedClips = List.of(widget.clips);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncThumbnails();
  }

  @override
  void didUpdateWidget(VideoEditorTimelineClipStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReordering) {
      _orderedClips = List.of(widget.clips);
    }
    _syncThumbnails();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    for (final thumbs in _thumbnailCache.values) {
      _deleteFiles(thumbs);
    }
    super.dispose();
  }

  /// Starts thumbnail loading for new clips, cleans up removed clips.
  void _syncThumbnails() {
    final currentIds = widget.clips.map((c) => c.id).toSet();

    // Remove stale entries.
    final staleIds = _thumbnailCache.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _subscriptions.remove(id)?.cancel();
      _deleteFiles(_thumbnailCache.remove(id) ?? const []);
    }

    // Start loading for new clips.
    for (final clip in widget.clips) {
      if (!_subscriptions.containsKey(clip.id)) {
        _loadStripThumbnails(clip);
      }
    }
  }

  void _loadStripThumbnails(DivineVideoClip clip) {
    final videoPath = clip.video.file?.path;
    if (videoPath == null) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final outputSize = Size(
      TimelineConstants.thumbnailWidth * dpr,
      TimelineConstants.thumbnailStripHeight * dpr,
    );

    _subscriptions[clip.id] =
        VideoThumbnailService.generateStripThumbnails(
          videoPath: videoPath,
          clipId: clip.id,
          duration: clip.duration,
          outputSize: outputSize,
        ).listen((thumbnails) {
          if (mounted) {
            setState(() => _thumbnailCache[clip.id] = thumbnails);
          }
        });
  }

  static Future<void> _deleteFiles(List<StripThumbnail> thumbnails) async {
    for (final thumb in thumbnails) {
      try {
        await File(thumb.path).delete();
      } catch (_) {}
    }
  }

  double _clipWidth(DivineVideoClip clip) {
    if (widget.clips.length == 1) return widget.totalWidth;
    return clip.durationInSeconds * widget.pixelsPerSecond;
  }

  int _clipIndexAtX(double localX) {
    const slotWidth = _reorderSize + TimelineConstants.clipGap;
    return (localX / slotWidth).floor().clamp(0, _orderedClips.length - 1);
  }

  /// Slot-center X for a given index in the reorder grid.
  double _slotLeft(int index) {
    return index * (_reorderSize + TimelineConstants.clipGap);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.clips.length <= 1) return;
    if (widget.isInteracting) return;

    final fingerX = details.localPosition.dx;

    // Find which clip was pressed in the normal layout.
    var accX = 0.0;
    var pressedIndex = _orderedClips.length - 1;
    for (var i = 0; i < _orderedClips.length; i++) {
      final w = _clipWidth(_orderedClips[i]);
      if (fingerX < accX + w) {
        pressedIndex = i;
        break;
      }
      accX += w + TimelineConstants.clipGap;
    }

    // Where in the clip the finger landed (0.0 = left edge, 1.0 = right).
    final clipW = _clipWidth(_orderedClips[pressedIndex]);
    final fingerInClip = (fingerX - accX).clamp(0.0, clipW);
    final fingerRatio = clipW > 0 ? fingerInClip / clipW : 0.5;

    // Offset so the reorder grid starts aligned with the pressed clip.
    final slotCenter = _slotLeft(pressedIndex) + _reorderSize / 2;

    HapticFeedback.mediumImpact();
    widget.onReorderChanged?.call(true);
    setState(() {
      _rowOffset = fingerX - slotCenter;
      _dragGlobalX = details.globalPosition.dx;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartLocalX = fingerX;
      _dragStartScrollOffset = widget.scrollController?.offset ?? 0;
      _dragClipWidth = clipW;
      _dragFingerRatio = fingerRatio;
      _dragStartClipCenter = accX + clipW / 2;
      _dragAnimating = true;
      _isReordering = true;
      _dragIndex = pressedIndex;
    });

    // Trigger the width shrink in the next frame so AnimatedContainer can
    // interpolate from the full clip width to _reorderSize.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isReordering) {
        setState(() => _dragClipWidth = _reorderSize);
      }
    });

    // After the shrink animation completes, switch to finger-following mode.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted && _isReordering) {
        setState(() => _dragAnimating = false);
      }
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isReordering || _dragIndex == null) return;

    setState(() {
      _dragGlobalX = details.globalPosition.dx;
      final adjustedX = _effectiveLocalX - _rowOffset;
      final targetIndex = _clipIndexAtX(adjustedX);
      if (targetIndex != _dragIndex) {
        HapticFeedback.selectionClick();
        final clip = _orderedClips.removeAt(_dragIndex!);
        _orderedClips.insert(targetIndex, clip);
        _dragIndex = targetIndex;
      }
    });

    _updateAutoScroll(details.globalPosition.dx);
  }

  // --------------- Auto-scroll while dragging near screen edges -------------

  void _updateAutoScroll(double globalX) {
    if (widget.scrollController == null) return;

    final screenWidth = MediaQuery.sizeOf(context).width;

    if (globalX < _autoScrollEdgeZone) {
      final t = 1 - (globalX / _autoScrollEdgeZone);
      _autoScrollSpeed = -t * _maxAutoScrollPxPerFrame;
    } else if (globalX > screenWidth - _autoScrollEdgeZone) {
      final t = 1 - ((screenWidth - globalX) / _autoScrollEdgeZone);
      _autoScrollSpeed = t * _maxAutoScrollPxPerFrame;
    } else {
      _autoScrollSpeed = 0;
    }

    if (_autoScrollSpeed != 0 && _autoScrollTimer == null) {
      _autoScrollTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _tickAutoScroll(),
      );
    } else if (_autoScrollSpeed == 0) {
      _stopAutoScroll();
    }
  }

  void _tickAutoScroll() {
    final sc = widget.scrollController;
    if (sc == null || !_isReordering || _dragIndex == null) {
      _stopAutoScroll();
      return;
    }

    final pos = sc.position;
    final newOffset = (pos.pixels + _autoScrollSpeed).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    final actualDelta = newOffset - pos.pixels;
    if (actualDelta == 0) return;

    sc.jumpTo(newOffset);

    // _effectiveLocalX auto-adjusts via the scroll-offset delta — no manual
    // finger-position patching needed.
    setState(() {
      final adjustedX = _effectiveLocalX - _rowOffset;
      final targetIndex = _clipIndexAtX(adjustedX);
      if (targetIndex != _dragIndex) {
        HapticFeedback.selectionClick();
        final clip = _orderedClips.removeAt(_dragIndex!);
        _orderedClips.insert(targetIndex, clip);
        _dragIndex = targetIndex;
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollSpeed = 0;
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _endReorder();
  }

  void _onLongPressCancel() {
    _endReorder();
  }

  /// Programmatic reorder for accessibility custom actions.
  void _reorderClip(int from, int to) {
    if (from == to) return;
    HapticFeedback.selectionClick();
    setState(() {
      final clip = _orderedClips.removeAt(from);
      _orderedClips.insert(to, clip);
    });
    widget.onReorder?.call(List.of(_orderedClips));
  }

  void _endReorder() {
    if (!_isReordering) return;

    _stopAutoScroll();

    final reordered = List<DivineVideoClip>.of(_orderedClips);
    final changed = !_sameOrder(reordered, widget.clips);

    // Phase 1: switch to exit mode — layout returns to normal widths
    // while AnimatedPositioned still has animDuration.
    setState(() {
      _isReordering = false;
      _isReorderExiting = true;
      _dragIndex = null;
      _dragAnimating = false;
    });

    widget.onReorderChanged?.call(false);

    if (changed) {
      widget.onReorder?.call(reordered);
    }

    // Phase 2: after the grow-back animation completes, clean up.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _isReorderExiting = false;
          _dragGlobalX = 0;
          _dragStartGlobalX = 0;
          _dragStartLocalX = 0;
          _dragStartScrollOffset = 0;
          _dragClipWidth = 0;
          _dragFingerRatio = 0.5;
          _dragStartClipCenter = 0;
          _rowOffset = 0;
        });
      }
    });
  }

  static bool _sameOrder(
    List<DivineVideoClip> a,
    List<DivineVideoClip> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Compute the left offset for each clip in normal (non-reorder) layout.
  List<double> _normalLeftOffsets() {
    final offsets = <double>[];
    var x = 0.0;
    for (var i = 0; i < _orderedClips.length; i++) {
      offsets.add(x);
      x += _clipWidth(_orderedClips[i]) + TimelineConstants.clipGap;
    }
    return offsets;
  }

  /// Total width of the strip in normal layout.
  double get _normalTotalWidth {
    var w = 0.0;
    for (final clip in _orderedClips) {
      w += _clipWidth(clip);
    }
    w += (_orderedClips.length - 1) * TimelineConstants.clipGap;
    return w;
  }

  @override
  Widget build(BuildContext context) {
    const gap = TimelineConstants.clipGap;
    const reorderSlotStep = _reorderSize + gap;
    const animDuration = Duration(milliseconds: 250);
    const animCurve = Curves.easeInOut;

    final normalOffsets = _normalLeftOffsets();
    final totalWidth = _isReordering
        ? _orderedClips.length * reorderSlotStep - gap
        : _normalTotalWidth;

    final shouldAnimate = _isReordering || _isReorderExiting;

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _isReordering ? _onLongPressMoveUpdate : null,
      onLongPressEnd: _isReordering ? _onLongPressEnd : null,
      onLongPressCancel: _isReordering ? _onLongPressCancel : null,
      child: AnimatedContainer(
        duration: shouldAnimate ? animDuration : Duration.zero,
        curve: animCurve,
        width: totalWidth,
        height: TimelineConstants.thumbnailStripHeight,
        child: Stack(
          clipBehavior: shouldAnimate ? Clip.none : Clip.hardEdge,
          children: [
            // Non-dragged clips.
            for (int i = 0; i < _orderedClips.length; i++)
              if (i != _dragIndex)
                AnimatedPositioned(
                  key: ValueKey(_orderedClips[i].id),
                  duration: shouldAnimate ? animDuration : Duration.zero,
                  curve: animCurve,
                  left: _isReordering
                      ? _rowOffset + i * reorderSlotStep
                      : normalOffsets[i],
                  top: 0,
                  width: _isReordering
                      ? _reorderSize
                      : _clipWidth(_orderedClips[i]),
                  height: TimelineConstants.thumbnailStripHeight,
                  child: _buildAccessibleClipTile(i),
                ),
            // Dragged clip — AnimatedPositioned so left+width animate
            // together during shrink, then Duration.zero for instant
            // finger-following after the animation completes.
            if (_dragIndex != null)
              AnimatedPositioned(
                key: const ValueKey('dragged'),
                duration: _dragAnimating ? animDuration : Duration.zero,
                curve: animCurve,
                left: _dragAnimating
                    ? _dragStartClipCenter - _dragClipWidth / 2
                    : _effectiveLocalX - _dragClipWidth * _dragFingerRatio,
                top: 0,
                width: _dragClipWidth,
                height: TimelineConstants.thumbnailStripHeight,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      TimelineConstants.thumbnailRadius,
                    ),
                    border: Border.all(
                      color: VineTheme.primary,
                      width: 2,
                    ),
                  ),
                  child: _buildClipTile(
                    _orderedClips[_dragIndex!],
                    _clipWidth(_orderedClips[_dragIndex!]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibleClipTile(int index) {
    final clip = _orderedClips[index];
    final total = _orderedClips.length;
    return Semantics(
      label: 'Clip ${index + 1} of $total',
      customSemanticsActions: {
        if (index > 0)
          const CustomSemanticsAction(label: 'Move left'): () =>
              _reorderClip(index, index - 1),
        if (index < total - 1)
          const CustomSemanticsAction(label: 'Move right'): () =>
              _reorderClip(index, index + 1),
      },
      child: _buildClipTile(clip, _clipWidth(clip)),
    );
  }

  Widget _buildClipTile(DivineVideoClip clip, double fullWidth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TimelineConstants.thumbnailRadius),
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: fullWidth,
          height: TimelineConstants.thumbnailStripHeight,
          child: _ClipContainer(
            clip: clip,
            width: fullWidth,
            stripThumbnails: _thumbnailCache[clip.id] ?? const [],
          ),
        ),
      ),
    );
  }
}

// Single clip — thumbnail images filling the width
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
