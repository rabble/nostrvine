// ABOUTME: Generic overlay strip widget for the video editor timeline.
// ABOUTME: Renders layer / filter / sound items in rows with long-press
// ABOUTME: drag to reposition (time + row) and trim handles on selection.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/hit_expanded_box.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_snap_controller.dart';

/// Vertical gap between overlay rows in logical pixels.
const double _overlayRowGap = 6;

/// Callback reporting a trim / resize change for an overlay item.
///
/// [startTime] and [duration] are non-null when the resize extends
/// beyond the original item boundary (overlays have no fixed content
/// length so they can grow in either direction).
typedef OverlayTrimCallback =
    void Function({
      required String itemId,
      required Duration startTime,
      required Duration endTime,
      required bool isStart,
    });

/// Callback reporting an item was moved to a new start time and row.
///
/// When [insertAbove] is `true`, the item should keep the target row
/// and existing overlapping items shift down.
typedef OverlayMoveCallback =
    void Function({
      required String itemId,
      required Duration startTime,
      required int row,
      required bool insertAbove,
    });

/// Called on every drag-move frame with the live (snapped) start time.
typedef OverlayMovingCallback =
    void Function({
      required String itemId,
      required Duration startTime,
    });

/// A generic strip that displays [TimelineOverlayItem]s in rows.
///
/// Supports:
/// - Long-press to start dragging
/// - Horizontal drag → change start time
/// - Vertical drag → change row / z-index (new rows created on demand)
/// - Trim handles on selected item
/// - Collapse mode (all items in a single row)
class TimelineOverlayStrip extends StatefulWidget {
  const TimelineOverlayStrip({
    required this.items,
    required this.rowCount,
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.color,
    this.isCollapsed = false,
    this.selectedItemId,
    this.snapPointsMs,
    this.onItemTapped,
    this.onItemMoved,
    this.onItemMoving,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onDragStarted,
    this.onDragEnded,
    super.key,
  });

  /// Items to display, pre-filtered by type and sorted by row.
  final List<TimelineOverlayItem> items;

  /// Number of rows to display.
  final int rowCount;

  /// Total scrollable width in pixels (matches clip strip).
  final double totalWidth;

  /// Current zoom level (pixels per second of video).
  final double pixelsPerSecond;

  /// Total video duration — used to clamp item positions.
  final Duration totalDuration;

  /// Background colour for item tiles.
  final Color color;

  /// Whether the strip is in collapsed mode (single-row summary).
  final bool isCollapsed;

  /// ID of the currently selected item (shows trim handles).
  final String? selectedItemId;

  /// Edge positions (in ms) from other overlay items and clip
  /// boundaries. Used for cross-layer snap during drag and trim.
  final List<int>? snapPointsMs;

  /// Called when an item tile is tapped.
  final ValueChanged<String>? onItemTapped;

  /// Called when an item is moved via drag.
  final OverlayMoveCallback? onItemMoved;

  /// Called on every drag-move frame with the live snapped start time.
  /// Use this to update the editor layer in real-time during the drag.
  final OverlayMovingCallback? onItemMoving;

  /// Called when a trim handle is dragged.
  final OverlayTrimCallback? onTrimChanged;

  /// Called when a trim drag starts (`true`) or ends (`false`).
  final ValueChanged<bool>? onTrimDragChanged;

  /// Called when an item long-press drag starts.
  final ValueChanged<String>? onDragStarted;

  /// Called when the drag gesture ends.
  final VoidCallback? onDragEnded;

  @override
  State<TimelineOverlayStrip> createState() => _TimelineOverlayStripState();
}

class _TimelineOverlayStripState extends State<TimelineOverlayStrip> {
  /// The item currently being dragged, or `null`.
  String? _draggingId;

  /// Snapped horizontal position (item start ms) returned by the snap controller.
  int _snappedStartMs = 0;

  /// Accumulated vertical drag offset in pixels.
  double _dragDeltaY = 0;

  /// The row the item was on when the drag started.
  int _dragStartRow = 0;

  /// Snap controller for the horizontal drag (tracks left edge of item).
  late TimelineSnapController _dragSnap;

  /// Previous horizontal offset-from-origin used to compute per-frame deltas.
  double _prevDragOffsetX = 0;

  /// Cumulative scroll offset added by auto-scroll during the current drag.
  double _scrollCompensationY = 0;

  /// Distance from viewport edge that triggers auto-scroll.
  static const _autoScrollEdge = 40.0;

  /// Max pixels scrolled per gesture frame when auto-scrolling.
  static const _autoScrollSpeed = 4.0;

  static const double _rowHeight = TimelineConstants.overlayRowHeight;

  @override
  void initState() {
    super.initState();
    _dragSnap = TimelineSnapController(
      direction: SnapEdgeDirection.positive,
      pixelsPerSecond: widget.pixelsPerSecond,
    );
  }

  @override
  void didUpdateWidget(TimelineOverlayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _dragSnap = TimelineSnapController(
        direction: SnapEdgeDirection.positive,
        pixelsPerSecond: widget.pixelsPerSecond,
      );
    }
  }

  double get _trimExpansion => widget.selectedItemId != null
      ? TimelineConstants.trimHandleWidth + 12.0
      : 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final displayRowCount = widget.isCollapsed ? 1 : widget.rowCount;
    final trimExp = _trimExpansion;

    return HitExpandedBox(
      expandLeft: trimExp,
      expandRight: trimExp,
      child: SizedBox(
        width: widget.totalWidth,
        height: displayRowCount * _rowHeight,
        child: HitExpandedBox(
          expandLeft: trimExp,
          expandRight: trimExp,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Drop indicator line — only visible during drag.
              if (_draggingId != null) _buildDropIndicator(),
              for (final item in widget.items)
                _buildItem(item, displayRowCount),
            ],
          ),
        ),
      ),
    );
  }

  /// Computes the drag target info: new start time, target row, and
  /// whether the cursor is in the upper half of the row cell.
  ({int newStartMs, int targetRow, bool insertAbove})? _dragTargetInfo() {
    final draggedItem = widget.items.where((i) => i.id == _draggingId);
    if (draggedItem.isEmpty) return null;

    final item = draggedItem.first;

    final maxStartMs = (widget.totalDuration - item.duration).inMilliseconds;
    final newStartMs = _snappedStartMs.clamp(0, maxStartMs);

    final rowDelta = (_dragDeltaY / _rowHeight).round();
    final targetRow = (_dragStartRow + rowDelta).clamp(0, 999);

    // Fractional offset within the target row cell.
    // Negative → upper half → insert above.
    final subRowOffset = _dragDeltaY / _rowHeight - rowDelta;
    final insertAbove = subRowOffset < 0;

    return (
      newStartMs: newStartMs,
      targetRow: targetRow,
      insertAbove: insertAbove,
    );
  }

  /// Returns `true` when `item` at `newStartMs` would overlap another
  /// item on `targetRow`.
  bool _wouldOverlapAt(
    TimelineOverlayItem item,
    int newStartMs,
    int targetRow,
  ) {
    final newEndMs = newStartMs + item.duration.inMilliseconds;
    return widget.items.any((other) {
      if (other.id == item.id) return false;
      if (other.row != targetRow) return false;
      final otherStartMs = other.startTime.inMilliseconds;
      final otherEndMs = otherStartMs + other.duration.inMilliseconds;
      return newStartMs < otherEndMs && otherStartMs < newEndMs;
    });
  }

  /// Builds a horizontal indicator line showing where the dragged item
  /// will land. Only appears when the dragged item would overlap an
  /// existing item on the target row.
  Widget _buildDropIndicator() {
    final info = _dragTargetInfo();
    if (info == null) return const SizedBox.shrink();

    final item = widget.items.firstWhere((i) => i.id == _draggingId);
    if (!_wouldOverlapAt(item, info.newStartMs, info.targetRow)) {
      return const SizedBox.shrink();
    }

    // Above: line at the top of the target row.
    // Below: line at the bottom of the target row.
    final lineY = info.insertAbove
        ? info.targetRow * _rowHeight
        : (info.targetRow + 1) * _rowHeight;

    return Positioned(
      left: 0,
      right: 0,
      top: lineY - 0.5,
      child: const ColoredBox(
        color: Colors.white54,
        child: SizedBox(height: 1),
      ),
    );
  }

  Widget _buildItem(TimelineOverlayItem item, int displayRowCount) {
    final isDragging = _draggingId == item.id;
    final isSelected = widget.selectedItemId == item.id;

    // Layout: x position from startTime, width from trimmedDuration.
    final baseX = item.startTimeInSeconds * widget.pixelsPerSecond;
    final itemWidth = item.durationInSeconds * widget.pixelsPerSecond;

    // Don't render if the item has zero width.
    if (itemWidth <= 0) return const SizedBox.shrink();

    final row = widget.isCollapsed ? 0 : item.row;
    final baseY = row * _rowHeight + _overlayRowGap / 2;

    // Apply drag offset to the dragged item.
    final x = isDragging
        ? _snappedStartMs / 1000.0 * widget.pixelsPerSecond
        : baseX;
    final y = isDragging ? baseY + _dragDeltaY : baseY;

    Widget tile = _OverlayItemTile(
      item: item,
      width: itemWidth,
      height: _rowHeight,
      color: widget.color,
      isDragging: isDragging,
    );

    // Wrap selected (non-dragging) items with trim handles.
    if (isSelected && !isDragging) {
      final trimExp = _trimExpansion;
      tile = _TrimmableOverlayTile(
        item: item,
        width: itemWidth,
        height: _rowHeight,
        color: widget.color,
        pixelsPerSecond: widget.pixelsPerSecond,
        totalDuration: widget.totalDuration,
        onTrimChanged: widget.onTrimChanged,
        onTrimDragChanged: widget.onTrimDragChanged,
        trimExpansion: trimExp,
        snapPointsMs: widget.snapPointsMs,
      );

      return Positioned(
        left: x - trimExp,
        top: y,
        width: itemWidth + trimExp * 2,
        child: Semantics(
          label: item.label,
          hint: 'Long press to drag',
          child: GestureDetector(
            onTap: () => widget.onItemTapped?.call(item.id),
            onLongPressStart: (_) => _onLongPressStart(item),
            onLongPressMoveUpdate: (details) =>
                _onLongPressMoveUpdate(details, item, displayRowCount),
            onLongPressEnd: (_) => _onLongPressEnd(item),
            child: tile,
          ),
        ),
      );
    }

    return Positioned(
      left: x,
      top: y,
      child: Semantics(
        label: item.label,
        hint: 'Long press to drag',
        child: GestureDetector(
          onTap: () => widget.onItemTapped?.call(item.id),
          onLongPressStart: (_) => _onLongPressStart(item),
          onLongPressMoveUpdate: (details) =>
              _onLongPressMoveUpdate(details, item, displayRowCount),
          onLongPressEnd: (_) => _onLongPressEnd(item),
          child: tile,
        ),
      ),
    );
  }

  // -- Long-press drag callbacks -------------------------------------------

  void _onLongPressStart(TimelineOverlayItem item) {
    HapticFeedback.mediumImpact();
    _dragSnap.reset();
    _dragSnap.begin(
      item.startTime.inMilliseconds,
      initialExcludeMs: item.startTime.inMilliseconds,
    );
    setState(() {
      _draggingId = item.id;
      _snappedStartMs = item.startTime.inMilliseconds;
      _prevDragOffsetX = 0;
      _dragDeltaY = 0;
      _scrollCompensationY = 0;
      _dragStartRow = item.row;
    });

    final bloc = context.read<TimelineOverlayBloc>();
    bloc.add(const TimelineOverlayItemSelected(null));

    widget.onDragStarted?.call(item.id);
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    TimelineOverlayItem item,
    int displayRowCount,
  ) {
    final pps = widget.pixelsPerSecond;
    final itemDurationMs = item.duration.inMilliseconds;
    final totalMs = widget.totalDuration.inMilliseconds;
    final maxStartMs = totalMs - itemDurationMs;

    // Compute per-frame delta from the previous absolute offset.
    final currentOffsetX = details.offsetFromOrigin.dx;
    final dx = currentOffsetX - _prevDragOffsetX;
    _prevDragOffsetX = currentOffsetX;

    _dragSnap.accumulate(dx);

    final rawStartMs =
        (_dragSnap.originMs + _dragSnap.effectiveAccPx / pps * 1000)
            .round()
            .clamp(0, maxStartMs);

    // Expose both left and right edge as snap candidates.
    Set<int>? snapPoints;
    if (widget.snapPointsMs != null && widget.snapPointsMs!.isNotEmpty) {
      snapPoints = {
        ...widget.snapPointsMs!,
        ...widget.snapPointsMs!.map((sp) => sp - itemDurationMs),
      };
    }

    final snappedStartMs = _dragSnap.update(rawStartMs, snapPoints);

    _handleAutoScroll(details.globalPosition);

    final clampedStartMs = snappedStartMs.clamp(0, maxStartMs);
    widget.onItemMoving?.call(
      itemId: item.id,
      startTime: Duration(milliseconds: clampedStartMs),
    );

    setState(() {
      _snappedStartMs = clampedStartMs;
      _dragDeltaY = details.offsetFromOrigin.dy + _scrollCompensationY;
    });
  }

  void _onLongPressEnd(TimelineOverlayItem item) {
    if (_draggingId == null) return;

    final info = _dragTargetInfo();
    if (info == null) return;

    widget.onItemMoved?.call(
      itemId: item.id,
      startTime: Duration(milliseconds: info.newStartMs),
      row: info.targetRow,
      insertAbove: info.insertAbove,
    );

    _dragSnap.reset();
    setState(() {
      _draggingId = null;
      _snappedStartMs = 0;
      _prevDragOffsetX = 0;
      _dragDeltaY = 0;
      _scrollCompensationY = 0;
    });
    widget.onDragEnded?.call();
  }

  // -- Auto-scroll near viewport edges during drag --------------------------

  void _handleAutoScroll(Offset globalPosition) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    final renderBox = scrollable.context.findRenderObject()! as RenderBox;
    final localY = renderBox.globalToLocal(globalPosition).dy;
    final viewportHeight = renderBox.size.height;
    // Shrink the bottom edge by the system safe-area so the trigger zone
    // sits above the home-indicator / navigation bar.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final effectiveBottom = viewportHeight - bottomInset;

    double delta = 0;
    if (localY < _autoScrollEdge) {
      delta = -_autoScrollSpeed * (1 - localY / _autoScrollEdge);
    } else if (localY > effectiveBottom - _autoScrollEdge) {
      delta =
          _autoScrollSpeed * (1 - (effectiveBottom - localY) / _autoScrollEdge);
    }

    if (delta == 0) return;

    final pos = scrollable.position;
    final before = pos.pixels;
    final target = (before + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target == before) return;
    pos.jumpTo(target);

    // Accumulate scroll compensation so the next setState keeps the
    // item under the finger.
    _scrollCompensationY += target - before;
  }
}

// ---------------------------------------------------------------------------
// Tile widgets
// ---------------------------------------------------------------------------

/// Visual representation of a single overlay item.
class _OverlayItemTile extends StatelessWidget {
  const _OverlayItemTile({
    required this.item,
    required this.width,
    required this.height,
    required this.color,
    this.isDragging = false,
  });

  final TimelineOverlayItem item;
  final double width;
  final double height;
  final Color color;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final radius = BorderRadius.circular(
      TimelineConstants.thumbnailRadius,
    );
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return SizedBox(
      width: width,
      height: height - _overlayRowGap,
      child: AnimatedContainer(
        duration: animDuration,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDragging ? 0.85 : 0.7),
          borderRadius: radius,
          boxShadow: isDragging
              ? const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        foregroundDecoration: isDragging
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white, width: 1.5),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay item tile wrapped with trim handles for duration adjustment.
class _TrimmableOverlayTile extends StatefulWidget {
  const _TrimmableOverlayTile({
    required this.item,
    required this.width,
    required this.height,
    required this.color,
    required this.pixelsPerSecond,
    required this.totalDuration,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.trimExpansion = 0,
    this.snapPointsMs,
  });

  final TimelineOverlayItem item;
  final double width;
  final double height;
  final Color color;
  final double pixelsPerSecond;
  final Duration totalDuration;
  final OverlayTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final double trimExpansion;
  final List<int>? snapPointsMs;

  @override
  State<_TrimmableOverlayTile> createState() => _TrimmableOverlayTileState();
}

class _TrimmableOverlayTileState extends State<_TrimmableOverlayTile> {
  static const _autoScrollEdge = 60.0;
  static const _autoScrollSpeed = 6.0;

  /// Whether haptic feedback has already fired for the current boundary hit.
  bool _hitBoundary = false;

  /// Snap controllers for the left and right trim handles.
  late TimelineSnapController _leftSnap;
  late TimelineSnapController _rightSnap;

  /// Which snap controller is active during this gesture.
  TimelineSnapController? _activeSnap;

  @override
  void initState() {
    super.initState();
    _leftSnap = TimelineSnapController(
      direction: SnapEdgeDirection.positive,
      pixelsPerSecond: widget.pixelsPerSecond,
    );
    _rightSnap = TimelineSnapController(
      direction: SnapEdgeDirection.negative,
      pixelsPerSecond: widget.pixelsPerSecond,
    );
  }

  @override
  void didUpdateWidget(_TrimmableOverlayTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      _leftSnap = TimelineSnapController(
        direction: SnapEdgeDirection.positive,
        pixelsPerSecond: widget.pixelsPerSecond,
      );
      _rightSnap = TimelineSnapController(
        direction: SnapEdgeDirection.negative,
        pixelsPerSecond: widget.pixelsPerSecond,
      );
    }
  }

  void _onDragStart() {
    _hitBoundary = false;
    _activeSnap = null;
    _leftSnap.reset();
    _rightSnap.reset();
    final item = widget.item;
    _leftSnap.begin(
      item.startTime.inMilliseconds,
      initialExcludeMs: item.startTime.inMilliseconds,
    );
    _rightSnap.begin(
      item.endTime.inMilliseconds,
      initialExcludeMs: item.endTime.inMilliseconds,
    );
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    _hitBoundary = false;
    _activeSnap = null;
    _leftSnap.reset();
    _rightSnap.reset();
    widget.onTrimDragChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.trimExpansion),
      child: TimelineTrimHandles(
        height: widget.height - _overlayRowGap,
        handleColor: widget.color,
        onDragStart: _onDragStart,
        onDragEnd: _onDragEnd,
        onLeftDragUpdate: _onLeftTrim,
        onRightDragUpdate: _onRightTrim,
        onDragPositionUpdate: _handleTrimAutoScroll,
        child: _OverlayItemTile(
          item: widget.item,
          width: widget.width,
          height: widget.height,
          color: widget.color,
        ),
      ),
    );
  }

  void _handleTrimAutoScroll(Offset globalPosition) {
    final scrollable = Scrollable.maybeOf(context, axis: Axis.horizontal);
    if (scrollable == null) return;

    final renderBox = scrollable.context.findRenderObject()! as RenderBox;
    final localX = renderBox.globalToLocal(globalPosition).dx;
    final viewportWidth = renderBox.size.width;

    double delta = 0;
    if (localX < _autoScrollEdge) {
      delta = -_autoScrollSpeed * (1 - localX / _autoScrollEdge);
    } else if (localX > viewportWidth - _autoScrollEdge) {
      delta =
          _autoScrollSpeed * (1 - (viewportWidth - localX) / _autoScrollEdge);
    }

    if (delta == 0) return;

    final pos = scrollable.position;
    final before = pos.pixels;
    final target = (before + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target == before) return;
    pos.jumpTo(target);

    // Sync video position to match the new scroll offset.
    final seekMs = (target / widget.pixelsPerSecond * 1000).round();
    context.read<VideoEditorMainBloc>().add(
      VideoEditorSeekRequested(Duration(milliseconds: seekMs)),
    );

    // Compensate the active snap controller so the handle tracks the finger.
    final scrolled = target - before;
    _activeSnap?.compensateScroll(scrolled);
  }

  void _onLeftTrim(double dx) {
    _activeSnap ??= _leftSnap;
    _leftSnap.accumulate(dx);

    final pps = widget.pixelsPerSecond;
    final effectiveDeltaMs = (_leftSnap.effectiveAccPx / pps * 1000).round();
    final rawStartMs = _leftSnap.originMs + effectiveDeltaMs;

    final snapPoints = widget.snapPointsMs != null
        ? Set<int>.of(widget.snapPointsMs!)
        : null;
    final posMs = _leftSnap.update(rawStartMs, snapPoints);

    final clampedMs =
        posMs.clamp(
              0,
              math.max(
                widget.totalDuration.inMilliseconds,
                _rightSnap.originMs,
              ),
            )
            as int;

    if (clampedMs != posMs) {
      if (!_hitBoundary) {
        HapticFeedback.heavyImpact();
        _hitBoundary = true;
      }
    } else {
      _hitBoundary = false;
    }

    if ((_rightSnap.originMs - clampedMs) <
        TimelineConstants.minTrimDuration.inMilliseconds) {
      if (!_hitBoundary) {
        HapticFeedback.heavyImpact();
        _hitBoundary = true;
      }
      return;
    }

    widget.onTrimChanged?.call(
      itemId: widget.item.id,
      isStart: true,
      startTime: Duration(milliseconds: clampedMs),
      endTime: Duration(milliseconds: _rightSnap.originMs),
    );
  }

  void _onRightTrim(double dx) {
    _activeSnap ??= _rightSnap;
    _rightSnap.accumulate(-dx);

    final pps = widget.pixelsPerSecond;
    final effectiveDeltaMs = (-_rightSnap.effectiveAccPx / pps * 1000).round();
    final rawEndMs = _rightSnap.originMs + effectiveDeltaMs;

    final snapPoints = widget.snapPointsMs != null
        ? Set<int>.of(widget.snapPointsMs!)
        : null;
    final posMs = _rightSnap.update(rawEndMs, snapPoints);

    final clampedMs = posMs.clamp(
      _leftSnap.originMs,
      widget.totalDuration.inMilliseconds,
    );

    if (clampedMs != posMs) {
      if (!_hitBoundary) {
        HapticFeedback.heavyImpact();
        _hitBoundary = true;
      }
    } else {
      _hitBoundary = false;
    }

    if ((clampedMs - _leftSnap.originMs) <
        TimelineConstants.minTrimDuration.inMilliseconds) {
      if (!_hitBoundary) {
        HapticFeedback.heavyImpact();
        _hitBoundary = true;
      }
      return;
    }

    widget.onTrimChanged?.call(
      itemId: widget.item.id,
      isStart: false,
      startTime: Duration(milliseconds: _leftSnap.originMs),
      endTime: Duration(milliseconds: clampedMs),
    );
  }
}
