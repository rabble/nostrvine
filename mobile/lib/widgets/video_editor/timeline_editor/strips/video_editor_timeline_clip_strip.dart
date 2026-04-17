import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';

part 'video_editor_timeline_clip_strip_tiles.dart';

/// Callback reporting a trim change for a clip.
typedef ClipTrimCallback =
    void Function({
      required String clipId,
      required Duration trimStart,
      required Duration trimEnd,
      required bool isStart,
    });

/// Callback reporting a reorder change — from index and to index.
typedef ClipReorderCallback = void Function(int from, int to);

class VideoEditorTimelineClipStrip extends StatefulWidget {
  const VideoEditorTimelineClipStrip({
    required this.clips,
    required this.totalWidth,
    required this.pixelsPerSecond,
    this.scrollController,
    this.onReorder,
    this.onReorderChanged,
    this.isInteracting = false,
    this.onClipTapped,
    this.trimmingClipId,
    this.onTrimChanged,
    this.onTrimDragChanged,
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

  /// Called when a clip tile is tapped with the clip's index.
  final ValueChanged<int>? onClipTapped;

  /// ID of the clip currently being trimmed, or `null`.
  final String? trimmingClipId;

  /// Called when a trim handle is dragged.
  final ClipTrimCallback? onTrimChanged;

  /// Called when a trim drag gesture starts (`true`) or ends (`false`).
  final ValueChanged<bool>? onTrimDragChanged;

  @override
  State<VideoEditorTimelineClipStrip> createState() =>
      _VideoEditorTimelineClipStripState();
}

class _VideoEditorTimelineClipStripState
    extends State<VideoEditorTimelineClipStrip>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 250);

  /// Drives reorder shrink/grow timing so we can react to completion
  /// instead of guessing with [Future.delayed].
  late final AnimationController _reorderAnimController;

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
  /// Each notifier is updated independently so only the affected
  /// clip tile rebuilds, not the entire strip.
  final _thumbnails = ClipThumbnailManager();

  static const double _reorderSize = TimelineConstants.thumbnailStripHeight;

  // Auto-scroll state.
  Timer? _autoScrollTimer;
  double _autoScrollSpeed = 0;
  static const _autoScrollEdgeZone = 40.0;
  static const _maxAutoScrollPxPerFrame = 8.0;

  @override
  void initState() {
    super.initState();
    _reorderAnimController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );
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
    _reorderAnimController.dispose();
    _thumbnails.dispose();
    super.dispose();
  }

  void _syncThumbnails() {
    _thumbnails.sync(
      clips: widget.clips,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      priorityTimestamps: _computeSlotTimestamps(),
    );
  }

  /// Computes the exact timestamps that the currently visible thumbnail
  /// slots need at the current zoom level.
  ///
  /// Each clip is divided into `ceil(clipWidth / thumbnailWidth)` slots.
  /// The center-time of every slot is returned so the generator can
  /// produce those frames first — giving instant visual coverage.
  Map<String, List<Duration>> _computeSlotTimestamps() {
    final result = <String, List<Duration>>{};

    for (final clip in widget.clips) {
      final clipPx = _clipWidth(clip);
      final durationMs = clip.duration.inMilliseconds;
      if (clipPx <= 0 || durationMs <= 0) continue;

      final slotCount = (clipPx / TimelineConstants.thumbnailWidth)
          .ceil()
          .clamp(1, 1000);
      final timestamps = <Duration>[];
      for (var i = 0; i < slotCount; i++) {
        final centerMs = durationMs * (i + 0.5) / slotCount;
        timestamps.add(Duration(milliseconds: centerMs.round()));
      }
      result[clip.id] = timestamps;
    }

    return result;
  }

  double _clipWidth(DivineVideoClip clip) {
    if (widget.clips.length == 1) return widget.totalWidth;
    return clip.trimmedDurationInSeconds * widget.pixelsPerSecond;
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
    _reorderAnimController
      ..reset()
      ..forward().then((_) {
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
    _reorderAnimController
      ..reset()
      ..forward().then((_) {
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

  /// Compute clip widths, left offsets and total width in a single pass.
  ({List<double> widths, List<double> offsets, double totalWidth})
  _computeLayout() {
    final widths = <double>[];
    final offsets = <double>[];
    var x = 0.0;
    for (var i = 0; i < _orderedClips.length; i++) {
      final w = _clipWidth(_orderedClips[i]);
      widths.add(w);
      offsets.add(x);
      x += w + TimelineConstants.clipGap;
    }
    // Subtract trailing gap.
    final total = x > 0 ? x - TimelineConstants.clipGap : 0.0;
    return (widths: widths, offsets: offsets, totalWidth: total);
  }

  @override
  Widget build(BuildContext context) {
    const gap = TimelineConstants.clipGap;
    const reorderSlotStep = _reorderSize + gap;
    const animDuration = _animDuration;
    const animCurve = Curves.easeInOut;

    final layout = _computeLayout();
    final totalWidth = _isReordering
        ? _orderedClips.length * reorderSlotStep - gap
        : layout.totalWidth;

    final shouldAnimate = _isReordering || _isReorderExiting;

    final trimExpand = widget.trimmingClipId != null
        ? TimelineConstants.trimHandleWidth + TimelineConstants.trimHitAreaExtra
        : 0.0;

    return Semantics(
      label: context.l10n.videoEditorTimelineLongPressToDragHint,
      button: true,
      child: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _isReordering ? _onLongPressMoveUpdate : null,
        onLongPressEnd: _isReordering ? _onLongPressEnd : null,
        onLongPressCancel: _isReordering ? _onLongPressCancel : null,
        child: AnimatedContainer(
          duration: shouldAnimate ? animDuration : .zero,
          curve: animCurve,
          width: totalWidth,
          height: TimelineConstants.thumbnailStripHeight,
          child: Stack(
            clipBehavior: shouldAnimate || widget.trimmingClipId != null
                ? .none
                : .hardEdge,
            children: [
              /// Non-dragged, non-trimming clips.
              _NonTrimmingClipPositions(
                orderedClips: _orderedClips,
                thumbnails: _thumbnails,
                layout: layout,
                dragIndex: _dragIndex,
                trimmingClipId: widget.trimmingClipId,
                shouldAnimate: shouldAnimate,
                animDuration: animDuration,
                animCurve: animCurve,
                isReordering: _isReordering,
                rowOffset: _rowOffset,
                reorderSlotStep: reorderSlotStep,
                pixelsPerSecond: widget.pixelsPerSecond,
                onReorder: _reorderClip,
                onClipTapped: widget.onClipTapped,
                rowOffsetSize: _reorderSize,
              ),

              /// Trimming clip — rendered last so handles stay on top.
              // AnimatedPositioned is expanded by trimExpand on each side
              // so the handle hit-areas fall within its bounds.
              _TrimmingClipPositions(
                orderedClips: _orderedClips,
                thumbnails: _thumbnails,
                layout: layout,
                dragIndex: _dragIndex,
                trimmingClipId: widget.trimmingClipId,
                shouldAnimate: shouldAnimate,
                animDuration: animDuration,
                animCurve: animCurve,
                isReordering: _isReordering,
                rowOffset: _rowOffset,
                reorderSlotStep: reorderSlotStep,
                trimExpand: trimExpand,
                pixelsPerSecond: widget.pixelsPerSecond,
                onTrimChanged: widget.onTrimChanged,
                onTrimDragChanged: widget.onTrimDragChanged,
                onClipTapped: widget.onClipTapped,
                reorderSize: _reorderSize,
              ),

              /// Dragged clip — AnimatedPositioned so left+width animate
              // together during shrink, then Duration.zero for instant
              // finger-following after the animation completes.
              if (_dragIndex != null)
                _DraggedClipPosition(
                  orderedClips: _orderedClips,
                  thumbnails: _thumbnails,
                  layout: layout,
                  dragIndex: _dragIndex,
                  dragAnimating: _dragAnimating,
                  animDuration: animDuration,
                  animCurve: animCurve,
                  dragStartClipCenter: _dragStartClipCenter,
                  dragClipWidth: _dragClipWidth,
                  effectiveLocalX: _effectiveLocalX,
                  dragFingerRatio: _dragFingerRatio,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrimmingClipPositions extends StatelessWidget {
  const _TrimmingClipPositions({
    required this.orderedClips,
    required this.thumbnails,
    required this.layout,
    required this.dragIndex,
    required this.trimmingClipId,
    required this.shouldAnimate,
    required this.animDuration,
    required this.animCurve,
    required this.isReordering,
    required this.rowOffset,
    required this.reorderSlotStep,
    required this.trimExpand,
    required this.pixelsPerSecond,
    required this.onTrimChanged,
    required this.onTrimDragChanged,
    required this.onClipTapped,
    required this.reorderSize,
  });

  final List<DivineVideoClip> orderedClips;
  final ClipThumbnailManager thumbnails;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;
  final int? dragIndex;
  final String? trimmingClipId;
  final bool shouldAnimate;
  final Duration animDuration;
  final Curve animCurve;
  final bool isReordering;
  final double rowOffset;
  final double reorderSlotStep;
  final double trimExpand;
  final double pixelsPerSecond;
  final ClipTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<int>? onClipTapped;
  final double reorderSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: .none,
      children: [
        for (int i = 0; i < orderedClips.length; i++)
          if (i != dragIndex && orderedClips[i].id == trimmingClipId)
            AnimatedPositioned(
              key: ValueKey(orderedClips[i].id),
              duration: shouldAnimate ? animDuration : Duration.zero,
              curve: animCurve,
              left: isReordering
                  ? rowOffset + i * reorderSlotStep
                  : layout.offsets[i] - trimExpand,
              top: 0,
              width: isReordering
                  ? reorderSize
                  : layout.widths[i] + trimExpand * 2,
              height: TimelineConstants.thumbnailStripHeight,
              child: _TrimmableClipTile(
                clip: orderedClips[i],
                clipWidth: layout.widths[i],
                pixelsPerSecond: pixelsPerSecond,
                thumbnailNotifier: thumbnails[orderedClips[i].id],
                onTrimChanged: onTrimChanged,
                onTrimDragChanged: onTrimDragChanged,
                trimExpand: trimExpand,
                onTap: onClipTapped != null ? () => onClipTapped!(i) : null,
              ),
            ),
      ],
    );
  }
}

class _NonTrimmingClipPositions extends StatelessWidget {
  const _NonTrimmingClipPositions({
    required this.orderedClips,
    required this.thumbnails,
    required this.layout,
    required this.dragIndex,
    required this.trimmingClipId,
    required this.shouldAnimate,
    required this.animDuration,
    required this.animCurve,
    required this.isReordering,
    required this.rowOffset,
    required this.reorderSlotStep,
    required this.pixelsPerSecond,
    required this.onReorder,
    required this.onClipTapped,
    required this.rowOffsetSize,
  });

  final List<DivineVideoClip> orderedClips;
  final ClipThumbnailManager thumbnails;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;
  final int? dragIndex;
  final String? trimmingClipId;
  final bool shouldAnimate;
  final Duration animDuration;
  final Curve animCurve;
  final bool isReordering;
  final double rowOffset;
  final double reorderSlotStep;
  final double pixelsPerSecond;
  final ClipReorderCallback onReorder;
  final ValueChanged<int>? onClipTapped;
  final double rowOffsetSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: .none,
      children: [
        for (int i = 0; i < orderedClips.length; i++)
          if (i != dragIndex && orderedClips[i].id != trimmingClipId)
            AnimatedPositioned(
              key: ValueKey(orderedClips[i].id),
              duration: shouldAnimate ? animDuration : Duration.zero,
              curve: animCurve,
              left: isReordering
                  ? rowOffset + i * reorderSlotStep
                  : layout.offsets[i],
              top: 0,
              width: isReordering ? rowOffsetSize : layout.widths[i],
              height: TimelineConstants.thumbnailStripHeight,
              child: _AccessibleClipTile(
                clip: orderedClips[i],
                index: i,
                total: orderedClips.length,
                clipWidth: layout.widths[i],
                thumbnailNotifier: thumbnails[orderedClips[i].id],
                onReorder: onReorder,
                onTap: onClipTapped,
              ),
            ),
      ],
    );
  }
}

class _DraggedClipPosition extends StatelessWidget {
  const _DraggedClipPosition({
    required this.orderedClips,
    required this.thumbnails,
    required this.layout,
    required this.dragIndex,
    required this.dragAnimating,
    required this.animDuration,
    required this.animCurve,
    required this.dragStartClipCenter,
    required this.dragClipWidth,
    required this.effectiveLocalX,
    required this.dragFingerRatio,
  });

  final List<DivineVideoClip> orderedClips;
  final ClipThumbnailManager thumbnails;
  final ({List<double> widths, List<double> offsets, double totalWidth}) layout;
  final int? dragIndex;
  final bool dragAnimating;
  final Duration animDuration;
  final Curve animCurve;
  final double dragStartClipCenter;
  final double dragClipWidth;
  final double effectiveLocalX;
  final double dragFingerRatio;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      key: const ValueKey('timeline-clip-dragged'),
      duration: dragAnimating ? animDuration : Duration.zero,
      curve: animCurve,
      left: dragAnimating
          ? dragStartClipCenter - dragClipWidth / 2
          : effectiveLocalX - dragClipWidth * dragFingerRatio,
      top: 0,
      width: dragClipWidth,
      height: TimelineConstants.thumbnailStripHeight,
      child: _DraggedClipTile(
        clip: orderedClips[dragIndex!],
        index: dragIndex!,
        fullWidth: layout.widths[dragIndex!],
        thumbnailNotifier: thumbnails[orderedClips[dragIndex!].id],
      ),
    );
  }
}
