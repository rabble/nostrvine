// ABOUTME: Generic overlay strip widget for the video editor timeline.
// ABOUTME: Renders layer / filter / sound items in rows with long-press
// ABOUTME: drag to reposition (time + row) and trim handles on selection.

import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/hit_expanded_box.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';

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
      required Duration trimStart,
      required Duration trimEnd,
      required bool isStart,
      Duration? startTime,
      Duration? duration,
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

  /// Snapped horizontal drag offset in pixels (accounts for edge snap).
  double _snappedDragDeltaX = 0;

  /// Accumulated vertical drag offset in pixels.
  double _dragDeltaY = 0;

  /// The row the item was on when the drag started.
  int _dragStartRow = 0;

  /// Whether the dragged item is currently snapped to an edge.
  bool _isSnapped = false;

  static const double _rowHeight = TimelineConstants.overlayRowHeight;

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

    final deltaSeconds = _snappedDragDeltaX / widget.pixelsPerSecond;
    final maxStartMs =
        (widget.totalDuration - item.trimmedDuration).inMilliseconds;
    final newStartMs = (item.startTime.inMilliseconds + deltaSeconds * 1000)
        .round()
        .clamp(0, maxStartMs);

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
    final newEndMs = newStartMs + item.trimmedDuration.inMilliseconds;
    return widget.items.any((other) {
      if (other.id == item.id) return false;
      if (other.row != targetRow) return false;
      final otherStartMs = other.startTime.inMilliseconds;
      final otherEndMs = otherStartMs + other.trimmedDuration.inMilliseconds;
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
    final itemWidth = item.trimmedDurationInSeconds * widget.pixelsPerSecond;

    // Don't render if the item has zero width.
    if (itemWidth <= 0) return const SizedBox.shrink();

    final row = widget.isCollapsed ? 0 : item.row;
    final baseY = row * _rowHeight + _overlayRowGap / 2;

    // Apply drag offset to the dragged item.
    final x = isDragging ? baseX + _snappedDragDeltaX : baseX;
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
    setState(() {
      _draggingId = item.id;
      _snappedDragDeltaX = 0;
      _dragDeltaY = 0;
      _dragStartRow = item.row;
    });
    widget.onDragStarted?.call(item.id);
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    TimelineOverlayItem item,
    int displayRowCount,
  ) {
    final baseX = item.startTimeInSeconds * widget.pixelsPerSecond;
    final itemWidth = item.trimmedDurationInSeconds * widget.pixelsPerSecond;
    final totalPx =
        widget.totalDuration.inMilliseconds / 1000.0 * widget.pixelsPerSecond;

    // Clamp so the item stays within [0, totalDuration].
    final minDx = -baseX;
    final maxDx = totalPx - baseX - itemWidth;
    final rawDx = details.offsetFromOrigin.dx.clamp(minDx, maxDx);

    // Compute snapped delta.
    final snappedDx = _computeSnappedDragDeltaX(rawDx, item);
    final isNowSnapped = snappedDx != rawDx;

    if (isNowSnapped && !_isSnapped) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _snappedDragDeltaX = snappedDx;
      _dragDeltaY = details.offsetFromOrigin.dy;
      _isSnapped = isNowSnapped;
    });
  }

  /// Returns the snapped pixel delta for the dragged item.
  ///
  /// Checks both the left and right edges of the item against
  /// [widget.snapPointsMs] and prefers the closer match.
  double _computeSnappedDragDeltaX(
    double rawDx,
    TimelineOverlayItem item,
  ) {
    final snapPoints = widget.snapPointsMs;
    if (snapPoints == null || snapPoints.isEmpty) return rawDx;

    final pps = widget.pixelsPerSecond;
    final thresholdMs = (TimelineConstants.snapDeadZonePx / pps * 1000).round();
    final maxStartMs =
        (widget.totalDuration - item.trimmedDuration).inMilliseconds;
    final rawStartMs = (item.startTime.inMilliseconds + rawDx / pps * 1000)
        .round()
        .clamp(0, maxStartMs);
    final rawEndMs = rawStartMs + item.trimmedDuration.inMilliseconds;

    int bestStartMs = rawStartMs;
    int bestDist = thresholdMs + 1;

    for (final sp in snapPoints) {
      final distStart = (rawStartMs - sp).abs();
      if (distStart <= thresholdMs && distStart < bestDist) {
        bestStartMs = sp;
        bestDist = distStart;
      }

      final distEnd = (rawEndMs - sp).abs();
      if (distEnd <= thresholdMs && distEnd < bestDist) {
        bestStartMs = sp - item.trimmedDuration.inMilliseconds;
        bestDist = distEnd;
      }
    }

    final snappedStartMs = bestStartMs.clamp(0, maxStartMs);
    if (snappedStartMs == rawStartMs) return rawDx;

    // Back-calculate pixel delta from snapped position.
    return (snappedStartMs - item.startTime.inMilliseconds) / 1000.0 * pps;
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

    setState(() {
      _draggingId = null;
      _snappedDragDeltaX = 0;
      _dragDeltaY = 0;
      _isSnapped = false;
    });
    widget.onDragEnded?.call();
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
  /// Whether haptic feedback has already fired for the current boundary hit.
  bool _hitBoundary = false;

  /// Whether haptic feedback has already fired for the current snap.
  bool _trimSnapped = false;

  /// Accumulated raw pixel delta for the active trim drag.
  double _accTrimPx = 0;

  /// Total dead-zone pixels consumed by past snaps during this gesture.
  /// Subtracted from [_accTrimPx] to obtain the effective position.
  double _deadZonePx = 0;

  /// The snap point (visual edge ms) the handle is currently held at,
  /// or `null` when moving freely.
  int? _activeSnapPointMs;

  /// Value of [_accTrimPx] when the current snap was caught.
  double _snapCatchAccPx = 0;

  /// The snap point we just released from. Excluded from the next
  /// [_snapEdge] call to prevent immediate re-catch.
  int? _lastReleasedSnapMs;

  /// Origin values captured at trim-drag start.
  int _trimStartOriginMs = 0;
  int _trimEndOriginMs = 0;
  int _startTimeOriginMs = 0;
  int _durationOriginMs = 0;

  void _onDragStart() {
    developer.log(
      'OverlayTile._onDragStart item=${widget.item.id}',
      name: 'overlay_trim',
    );
    _hitBoundary = false;
    _trimSnapped = false;
    _accTrimPx = 0;
    _deadZonePx = 0;
    _activeSnapPointMs = null;
    _snapCatchAccPx = 0;
    _lastReleasedSnapMs = null;
    final item = widget.item;
    _trimStartOriginMs = item.trimStart.inMilliseconds;
    _trimEndOriginMs = item.trimEnd.inMilliseconds;
    _startTimeOriginMs = item.startTime.inMilliseconds;
    _durationOriginMs = item.duration.inMilliseconds;
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    _hitBoundary = false;
    _trimSnapped = false;
    _accTrimPx = 0;
    _deadZonePx = 0;
    _activeSnapPointMs = null;
    _snapCatchAccPx = 0;
    _lastReleasedSnapMs = null;
    widget.onTrimDragChanged?.call(false);
  }

  /// Finds the nearest snap point to [edgeMs] within [snapCatchPx].
  /// Returns `null` if no snap point is close enough.
  int? _snapEdge(int edgeMs, {int? excludeMs}) {
    final snapPoints = widget.snapPointsMs;
    if (snapPoints == null || snapPoints.isEmpty) return null;

    final thresholdMs =
        (TimelineConstants.snapCatchPx / widget.pixelsPerSecond * 1000).round();

    int? bestSnap;
    var bestDist = thresholdMs + 1;

    for (final sp in snapPoints) {
      if (excludeMs != null && sp == excludeMs) continue;
      if (_lastReleasedSnapMs != null && sp == _lastReleasedSnapMs) continue;
      final dist = (edgeMs - sp).abs();
      if (dist <= thresholdMs && dist < bestDist) {
        bestSnap = sp;
        bestDist = dist;
      }
    }

    return bestSnap;
  }

  /// Fires haptic when entering a snap zone and resets when leaving.
  void _handleTrimSnapHaptic({required bool isSnapped}) {
    if (isSnapped && !_trimSnapped) {
      HapticFeedback.selectionClick();
    }
    _trimSnapped = isSnapped;
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
        child: _OverlayItemTile(
          item: widget.item,
          width: widget.width,
          height: widget.height,
          color: widget.color,
        ),
      ),
    );
  }

  void _onLeftTrim(double dx) {
    developer.log(
      'OverlayTile._onLeftTrim dx=$dx item=${widget.item.id}',
      name: 'overlay_trim',
    );
    _accTrimPx += dx;
    final item = widget.item;
    final pps = widget.pixelsPerSecond;

    // --- Snap hold / release ---
    if (_activeSnapPointMs != null) {
      final excessPx = _accTrimPx - _snapCatchAccPx;
      if (excessPx.abs() > TimelineConstants.snapDeadZonePx) {
        // Release: consume the full excess so effective stays at the
        // snap position. _lastReleasedSnapMs prevents re-catch.
        _lastReleasedSnapMs = _activeSnapPointMs;
        _deadZonePx += excessPx;
        _activeSnapPointMs = null;
        _handleTrimSnapHaptic(isSnapped: false);
        // Fall through to emit the new free position.
      } else {
        // Still holding at the snap point.
        _handleTrimSnapHaptic(isSnapped: true);
        final snapTrimMs =
            _trimStartOriginMs + (_activeSnapPointMs! - _startTimeOriginMs);
        final maxTrimMs =
            (_durationOriginMs -
                    _trimEndOriginMs -
                    TimelineConstants.minTrimDuration.inMilliseconds)
                .clamp(0, _durationOriginMs);
        final minTrimStartMs = math.max(
          0,
          _trimStartOriginMs - _startTimeOriginMs,
        );
        final clampedMs = snapTrimMs.clamp(minTrimStartMs, maxTrimMs);
        if (clampedMs == item.trimStart.inMilliseconds) return;
        widget.onTrimChanged?.call(
          itemId: item.id,
          trimStart: Duration(milliseconds: clampedMs),
          trimEnd: item.trimEnd,
          isStart: true,
        );
        return;
      }
    }

    // --- Free movement ---
    final effectiveAccPx = _accTrimPx - _deadZonePx;
    final accDeltaMs = (effectiveAccPx / pps * 1000).round();
    final rawTrimStartMs = _trimStartOriginMs + accDeltaMs;

    if (rawTrimStartMs >= 0) {
      final maxTrimMs =
          (_durationOriginMs -
                  _trimEndOriginMs -
                  TimelineConstants.minTrimDuration.inMilliseconds)
              .clamp(0, _durationOriginMs);
      final minTrimStartMs = math.max(
        0,
        _trimStartOriginMs - _startTimeOriginMs,
      );
      var clampedMs = rawTrimStartMs.clamp(minTrimStartMs, maxTrimMs);
      final wasClamped = rawTrimStartMs != clampedMs;

      if (wasClamped) {
        if (!_hitBoundary) {
          _hitBoundary = true;
          HapticFeedback.selectionClick();
        }
        if (clampedMs == item.trimStart.inMilliseconds) return;
      } else {
        _hitBoundary = false;

        // Check for snap catch.
        final rawVisualLeftMs = _startTimeOriginMs + accDeltaMs;

        // Clear release exclusion once we've moved well past it.
        if (_lastReleasedSnapMs != null) {
          final distMs = (rawVisualLeftMs - _lastReleasedSnapMs!).abs();
          final clearMs = (TimelineConstants.snapCatchPx * 3 / pps * 1000)
              .round();
          if (distMs > clearMs) _lastReleasedSnapMs = null;
        }

        final snappedLeftMs = _snapEdge(
          rawVisualLeftMs,
          excludeMs: _startTimeOriginMs,
        );
        if (snappedLeftMs != null && snappedLeftMs != rawVisualLeftMs) {
          _activeSnapPointMs = snappedLeftMs;
          _snapCatchAccPx = _accTrimPx;
          _lastReleasedSnapMs = null;
          // Adjust dead zone so effective maps to the snap position.
          final snapEffAccPx =
              (snappedLeftMs - _startTimeOriginMs) / 1000.0 * pps;
          _deadZonePx = _accTrimPx - snapEffAccPx;

          clampedMs = _trimStartOriginMs + (snappedLeftMs - _startTimeOriginMs);
          clampedMs = clampedMs.clamp(minTrimStartMs, maxTrimMs);
          _handleTrimSnapHaptic(isSnapped: true);
          if (clampedMs == item.trimStart.inMilliseconds) return;
          widget.onTrimChanged?.call(
            itemId: item.id,
            trimStart: Duration(milliseconds: clampedMs),
            trimEnd: item.trimEnd,
            isStart: true,
          );
          return;
        }
      }

      _handleTrimSnapHaptic(isSnapped: false);
      widget.onTrimChanged?.call(
        itemId: item.id,
        trimStart: Duration(milliseconds: clampedMs),
        trimEnd: item.trimEnd,
        isStart: true,
      );
    } else {
      // Extending left — grow duration, shift startTime earlier.
      _hitBoundary = false;
      _handleTrimSnapHaptic(isSnapped: false);
      final extendMs = -rawTrimStartMs;
      final newStartMs = math.max(0, _startTimeOriginMs - extendMs);
      final actualExtend = _startTimeOriginMs - newStartMs;
      final totalMs = widget.totalDuration.inMilliseconds;
      final maxDurationMs = totalMs - newStartMs + _trimEndOriginMs;
      final newDurationMs = math.min(
        _durationOriginMs + actualExtend,
        maxDurationMs,
      );
      final effectiveExtend = newDurationMs - _durationOriginMs;
      if (effectiveExtend <= 0 && newStartMs == 0) {
        if (!_hitBoundary) {
          _hitBoundary = true;
          HapticFeedback.selectionClick();
        }
        return;
      }
      widget.onTrimChanged?.call(
        itemId: item.id,
        trimStart: Duration.zero,
        trimEnd: Duration(milliseconds: _trimEndOriginMs),
        isStart: true,
        startTime: Duration(milliseconds: newStartMs),
        duration: Duration(milliseconds: newDurationMs),
      );
    }
  }

  void _onRightTrim(double dx) {
    developer.log(
      'OverlayTile._onRightTrim dx=$dx item=${widget.item.id}',
      name: 'overlay_trim',
    );
    _accTrimPx += dx;
    final item = widget.item;
    final pps = widget.pixelsPerSecond;

    // --- Snap hold / release ---
    if (_activeSnapPointMs != null) {
      final excessPx = _accTrimPx - _snapCatchAccPx;
      if (excessPx.abs() > TimelineConstants.snapDeadZonePx) {
        _lastReleasedSnapMs = _activeSnapPointMs;
        _deadZonePx += excessPx;
        _activeSnapPointMs = null;
        _handleTrimSnapHaptic(isSnapped: false);
      } else {
        _handleTrimSnapHaptic(isSnapped: true);
        final snapTrimEndMs =
            _startTimeOriginMs +
            _durationOriginMs -
            _trimStartOriginMs -
            _activeSnapPointMs!;
        final maxTrimMs =
            (_durationOriginMs -
                    _trimStartOriginMs -
                    TimelineConstants.minTrimDuration.inMilliseconds)
                .clamp(0, _durationOriginMs);
        final minTrimEndMs = math.max(
          0,
          _startTimeOriginMs +
              _durationOriginMs -
              _trimStartOriginMs -
              widget.totalDuration.inMilliseconds,
        );
        final clampedMs = snapTrimEndMs.clamp(minTrimEndMs, maxTrimMs);
        if (clampedMs == item.trimEnd.inMilliseconds) return;
        widget.onTrimChanged?.call(
          itemId: item.id,
          trimStart: item.trimStart,
          trimEnd: Duration(milliseconds: clampedMs),
          isStart: false,
        );
        return;
      }
    }

    // --- Free movement ---
    final effectiveAccPx = _accTrimPx - _deadZonePx;
    final accDeltaMs = (-effectiveAccPx / pps * 1000).round();
    final rawTrimEndMs = _trimEndOriginMs + accDeltaMs;

    if (rawTrimEndMs >= 0) {
      final maxTrimMs =
          (_durationOriginMs -
                  _trimStartOriginMs -
                  TimelineConstants.minTrimDuration.inMilliseconds)
              .clamp(0, _durationOriginMs);
      final minTrimEndMs = math.max(
        0,
        _startTimeOriginMs +
            _durationOriginMs -
            _trimStartOriginMs -
            widget.totalDuration.inMilliseconds,
      );
      var clampedMs = rawTrimEndMs.clamp(minTrimEndMs, maxTrimMs);
      final wasClamped = rawTrimEndMs != clampedMs;

      if (wasClamped) {
        if (!_hitBoundary) {
          _hitBoundary = true;
          HapticFeedback.selectionClick();
        }
        if (clampedMs == item.trimEnd.inMilliseconds) return;
      } else {
        _hitBoundary = false;

        // Check for snap catch.
        final rawVisualRightMs =
            _startTimeOriginMs +
            _durationOriginMs -
            _trimStartOriginMs -
            clampedMs;

        // Clear release exclusion once we've moved well past it.
        if (_lastReleasedSnapMs != null) {
          final distMs = (rawVisualRightMs - _lastReleasedSnapMs!).abs();
          final clearMs = (TimelineConstants.snapCatchPx * 3 / pps * 1000)
              .round();
          if (distMs > clearMs) _lastReleasedSnapMs = null;
        }

        final originRightMs =
            _startTimeOriginMs +
            _durationOriginMs -
            _trimStartOriginMs -
            _trimEndOriginMs;
        final snappedRightMs = _snapEdge(
          rawVisualRightMs,
          excludeMs: originRightMs,
        );
        if (snappedRightMs != null && snappedRightMs != rawVisualRightMs) {
          _activeSnapPointMs = snappedRightMs;
          _snapCatchAccPx = _accTrimPx;
          _lastReleasedSnapMs = null;
          // Adjust dead zone so effective maps to the snap position.
          final snapTrimEndMs =
              _startTimeOriginMs +
              _durationOriginMs -
              _trimStartOriginMs -
              snappedRightMs;
          final snapEffAccPx =
              -(snapTrimEndMs - _trimEndOriginMs) / 1000.0 * pps;
          _deadZonePx = _accTrimPx - snapEffAccPx;

          clampedMs = snapTrimEndMs.clamp(minTrimEndMs, maxTrimMs);
          _handleTrimSnapHaptic(isSnapped: true);
          if (clampedMs == item.trimEnd.inMilliseconds) return;
          widget.onTrimChanged?.call(
            itemId: item.id,
            trimStart: item.trimStart,
            trimEnd: Duration(milliseconds: clampedMs),
            isStart: false,
          );
          return;
        }
      }

      _handleTrimSnapHaptic(isSnapped: false);
      widget.onTrimChanged?.call(
        itemId: item.id,
        trimStart: item.trimStart,
        trimEnd: Duration(milliseconds: clampedMs),
        isStart: false,
      );
    } else {
      // Extending right — grow duration.
      _hitBoundary = false;
      _handleTrimSnapHaptic(isSnapped: false);
      final extendMs = -rawTrimEndMs;
      final newEndMs = _startTimeOriginMs + _durationOriginMs + extendMs;
      final totalMs = widget.totalDuration.inMilliseconds;
      final maxEndMs = totalMs + _trimStartOriginMs;
      final clampedEndMs = newEndMs.clamp(0, maxEndMs);
      final actualExtend =
          clampedEndMs - _startTimeOriginMs - _durationOriginMs;
      if (actualExtend <= 0) {
        if (!_hitBoundary) {
          _hitBoundary = true;
          HapticFeedback.selectionClick();
        }
        return;
      }
      widget.onTrimChanged?.call(
        itemId: item.id,
        trimStart: Duration(milliseconds: _trimStartOriginMs),
        trimEnd: Duration.zero,
        isStart: false,
        duration: Duration(milliseconds: _durationOriginMs + actualExtend),
      );
    }
  }
}
