import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
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
    _thumbnails.dispose();
    super.dispose();
  }

  void _syncThumbnails() {
    _thumbnails.sync(
      clips: widget.clips,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
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
    const animDuration = Duration(milliseconds: 250);
    const animCurve = Curves.easeInOut;

    final layout = _computeLayout();
    final totalWidth = _isReordering
        ? _orderedClips.length * reorderSlotStep - gap
        : layout.totalWidth;

    final shouldAnimate = _isReordering || _isReorderExiting;

    final trimExpand = widget.trimmingClipId != null
        ? TimelineConstants.trimHandleWidth + 12.0
        : 0.0;

    return _HitExpandedBox(
      expandLeft: trimExpand,
      expandRight: trimExpand,
      child: GestureDetector(
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
            clipBehavior: shouldAnimate || widget.trimmingClipId != null
                ? Clip.none
                : Clip.hardEdge,
            children: [
              // Non-dragged, non-trimming clips.
              for (int i = 0; i < _orderedClips.length; i++)
                if (i != _dragIndex &&
                    _orderedClips[i].id != widget.trimmingClipId)
                  AnimatedPositioned(
                    key: ValueKey(_orderedClips[i].id),
                    duration: shouldAnimate ? animDuration : Duration.zero,
                    curve: animCurve,
                    left: _isReordering
                        ? _rowOffset + i * reorderSlotStep
                        : layout.offsets[i],
                    top: 0,
                    width: _isReordering ? _reorderSize : layout.widths[i],
                    height: TimelineConstants.thumbnailStripHeight,
                    child: _AccessibleClipTile(
                      clip: _orderedClips[i],
                      index: i,
                      total: _orderedClips.length,
                      clipWidth: layout.widths[i],
                      thumbnailNotifier: _thumbnails[_orderedClips[i].id],
                      onReorder: _reorderClip,
                      onTap: widget.onClipTapped,
                    ),
                  ),
              // Trimming clip — rendered last so handles stay on top.
              // AnimatedPositioned is expanded by trimExpand on each side
              // so the handle hit-areas fall within its bounds.
              for (int i = 0; i < _orderedClips.length; i++)
                if (i != _dragIndex &&
                    _orderedClips[i].id == widget.trimmingClipId)
                  AnimatedPositioned(
                    key: ValueKey(_orderedClips[i].id),
                    duration: shouldAnimate ? animDuration : Duration.zero,
                    curve: animCurve,
                    left: _isReordering
                        ? _rowOffset + i * reorderSlotStep
                        : layout.offsets[i] - trimExpand,
                    top: 0,
                    width: _isReordering
                        ? _reorderSize
                        : layout.widths[i] + trimExpand * 2,
                    height: TimelineConstants.thumbnailStripHeight,
                    child: _TrimmableClipTile(
                      clip: _orderedClips[i],
                      clipWidth: layout.widths[i],
                      pixelsPerSecond: widget.pixelsPerSecond,
                      thumbnailNotifier: _thumbnails[_orderedClips[i].id],
                      onTrimChanged: widget.onTrimChanged,
                      onTrimDragChanged: widget.onTrimDragChanged,
                      trimExpand: trimExpand,
                      onTap: widget.onClipTapped != null
                          ? () => widget.onClipTapped!(i)
                          : null,
                    ),
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
                  child: _DraggedClipTile(
                    clip: _orderedClips[_dragIndex!],
                    index: _dragIndex!,
                    fullWidth: layout.widths[_dragIndex!],
                    thumbnailNotifier:
                        _thumbnails[_orderedClips[_dragIndex!].id],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a child and expands its hit-test area beyond its layout bounds.
///
/// This is needed because Flutter's [Stack] (and other [RenderBox] subclasses)
/// reject hit-tests that land outside `size`. When trim handles are positioned
/// outside the clip strip's bounds via [Clip.none], they paint correctly but
/// cannot receive touches. Wrapping the strip hierarchy with this widget
/// extends the hit-test rect so outer-positioned handles remain interactive.
class _HitExpandedBox extends SingleChildRenderObjectWidget {
  const _HitExpandedBox({
    required super.child,
    this.expandLeft = 0,
    this.expandRight = 0,
  });

  final double expandLeft;
  final double expandRight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHitExpandedBox(
      expandLeft: expandLeft,
      expandRight: expandRight,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHitExpandedBox renderObject,
  ) {
    renderObject
      ..expandLeft = expandLeft
      ..expandRight = expandRight;
  }
}

class _RenderHitExpandedBox extends RenderProxyBox {
  _RenderHitExpandedBox({
    required double expandLeft,
    required double expandRight,
  }) : _expandLeft = expandLeft,
       _expandRight = expandRight;

  double _expandLeft;
  double get expandLeft => _expandLeft;
  set expandLeft(double value) {
    if (_expandLeft == value) return;
    _expandLeft = value;
  }

  double _expandRight;
  double get expandRight => _expandRight;
  set expandRight(double value) {
    if (_expandRight == value) return;
    _expandRight = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final inExpanded =
        position.dx >= -_expandLeft &&
        position.dx < size.width + _expandRight &&
        position.dy >= 0 &&
        position.dy < size.height;
    final inNormal = size.contains(position);

    if (inExpanded) {
      if (inNormal) {
        if (hitTestChildren(result, position: position) ||
            hitTestSelf(position)) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      } else {
        // Expanded margin — must bypass size.contains on ALL intermediate
        // proxy boxes (e.g. GestureDetector creates Semantics + Listener).
        // Walk through the render tree skipping proxy boxes until we reach
        // a multi-child widget (Stack) whose hitTestChildren iterates
        // positioned children directly.
        final childHit = _hitTestDeep(result, position, child);
        if (childHit || hitTestSelf(position)) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      }
    }
    return false;
  }

  /// Recursively traverses the render tree, bypassing [size.contains]
  /// checks on intermediate [RenderProxyBox] nodes (e.g. the Semantics
  /// and Listener render objects created by [GestureDetector]).
  ///
  /// Stops at the first non-proxy child (e.g. [RenderStack]) and calls
  /// its [hitTestChildren] which iterates positioned children directly.
  static bool _hitTestDeep(
    BoxHitTestResult result,
    Offset position,
    RenderBox? node,
  ) {
    if (node == null) return false;
    // Another _RenderHitExpandedBox — let it handle its own expansion.
    if (node is _RenderHitExpandedBox) {
      return node.hitTest(result, position: position);
    }
    // Proxy box — skip its hitTest (which has size.contains) and recurse.
    if (node is RenderProxyBox) {
      return _hitTestDeep(result, position, node.child);
    }
    // Multi-child (Stack, Flex, etc.) — use standard hitTestChildren.
    return node.hitTestChildren(result, position: position);
  }
}
