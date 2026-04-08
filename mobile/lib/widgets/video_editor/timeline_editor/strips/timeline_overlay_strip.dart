// ABOUTME: Generic overlay strip widget for the video editor timeline.
// ABOUTME: Renders layer / filter / sound items in rows with long-press
// ABOUTME: drag to reposition (time + row) and trim handles on selection.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';

/// Callback reporting a trim change for an overlay item.
typedef OverlayTrimCallback =
    void Function({
      required String itemId,
      required Duration trimStart,
      required Duration trimEnd,
      required bool isStart,
    });

/// Callback reporting an item was moved to a new start time and row.
typedef OverlayMoveCallback =
    void Function({
      required String itemId,
      required Duration startTime,
      required int row,
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

  /// Accumulated horizontal drag offset in pixels.
  double _dragDeltaX = 0;

  /// Accumulated vertical drag offset in pixels.
  double _dragDeltaY = 0;

  /// The row the item was on when the drag started.
  int _dragStartRow = 0;

  static const double _rowHeight = TimelineConstants.overlayRowHeight;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final displayRowCount = widget.isCollapsed ? 1 : widget.rowCount;

    return SizedBox(
      width: widget.totalWidth,
      height: displayRowCount * _rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in widget.items) _buildItem(item, displayRowCount),
        ],
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
    final baseY = row * _rowHeight;

    // Apply drag offset to the dragged item.
    final x = isDragging ? baseX + _dragDeltaX : baseX;
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
      tile = _TrimmableOverlayTile(
        item: item,
        width: itemWidth,
        height: _rowHeight,
        color: widget.color,
        pixelsPerSecond: widget.pixelsPerSecond,
        onTrimChanged: widget.onTrimChanged,
        onTrimDragChanged: widget.onTrimDragChanged,
      );
    }

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => widget.onItemTapped?.call(item.id),
        onLongPressStart: (_) => _onLongPressStart(item),
        onLongPressMoveUpdate: (details) =>
            _onLongPressMoveUpdate(details, item, displayRowCount),
        onLongPressEnd: (_) => _onLongPressEnd(item),
        child: tile,
      ),
    );
  }

  // -- Long-press drag callbacks -------------------------------------------

  void _onLongPressStart(TimelineOverlayItem item) {
    HapticFeedback.mediumImpact();
    setState(() {
      _draggingId = item.id;
      _dragDeltaX = 0;
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
    setState(() {
      _dragDeltaX += details.offsetFromOrigin.dx - _dragDeltaX;
      _dragDeltaY += details.offsetFromOrigin.dy - _dragDeltaY;
    });
  }

  void _onLongPressEnd(TimelineOverlayItem item) {
    if (_draggingId == null) return;

    // Compute new start time from horizontal offset.
    final deltaSeconds = _dragDeltaX / widget.pixelsPerSecond;
    final newStartMs = (item.startTime.inMilliseconds + deltaSeconds * 1000)
        .round()
        .clamp(0, widget.totalDuration.inMilliseconds);

    // Compute new row from vertical offset.
    final rowDelta = (_dragDeltaY / _rowHeight).round();
    final newRow = (_dragStartRow + rowDelta).clamp(
      0,
      double.maxFinite.toInt(),
    );

    widget.onItemMoved?.call(
      itemId: item.id,
      startTime: Duration(milliseconds: newStartMs),
      row: newRow,
    );

    setState(() {
      _draggingId = null;
      _dragDeltaX = 0;
      _dragDeltaY = 0;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width,
      height: height - 2, // 2px vertical gap between rows
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDragging ? 0.85 : 0.7),
        borderRadius: BorderRadius.circular(
          TimelineConstants.thumbnailRadius,
        ),
        border: isDragging ? Border.all(color: Colors.white, width: 1.5) : null,
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
    );
  }
}

/// Overlay item tile wrapped with trim handles for duration adjustment.
class _TrimmableOverlayTile extends StatelessWidget {
  const _TrimmableOverlayTile({
    required this.item,
    required this.width,
    required this.height,
    required this.color,
    required this.pixelsPerSecond,
    this.onTrimChanged,
    this.onTrimDragChanged,
  });

  final TimelineOverlayItem item;
  final double width;
  final double height;
  final Color color;
  final double pixelsPerSecond;
  final OverlayTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;

  @override
  Widget build(BuildContext context) {
    return TimelineTrimHandles(
      height: height - 2,
      handleColor: color,
      onDragStart: () => onTrimDragChanged?.call(true),
      onDragEnd: () => onTrimDragChanged?.call(false),
      onLeftDragUpdate: _onLeftTrim,
      onRightDragUpdate: _onRightTrim,
      child: _OverlayItemTile(
        item: item,
        width: width - TimelineConstants.trimHandleWidth * 2,
        height: height,
        color: color,
      ),
    );
  }

  void _onLeftTrim(double dx) {
    final deltaDuration = Duration(
      milliseconds: (dx / pixelsPerSecond * 1000).round(),
    );
    final newTrimStart = item.trimStart + deltaDuration;
    final maxTrim =
        item.duration - item.trimEnd - TimelineConstants.minTrimDuration;

    final clamped = Duration(
      milliseconds: newTrimStart.inMilliseconds.clamp(
        0,
        maxTrim.inMilliseconds,
      ),
    );

    if (clamped == item.trimStart) {
      HapticFeedback.selectionClick();
      return;
    }

    onTrimChanged?.call(
      itemId: item.id,
      trimStart: clamped,
      trimEnd: item.trimEnd,
      isStart: true,
    );
  }

  void _onRightTrim(double dx) {
    final deltaDuration = Duration(
      milliseconds: (-dx / pixelsPerSecond * 1000).round(),
    );
    final newTrimEnd = item.trimEnd + deltaDuration;
    final maxTrim =
        item.duration - item.trimStart - TimelineConstants.minTrimDuration;

    final clamped = Duration(
      milliseconds: newTrimEnd.inMilliseconds.clamp(
        0,
        maxTrim.inMilliseconds,
      ),
    );

    if (clamped == item.trimEnd) {
      HapticFeedback.selectionClick();
      return;
    }

    onTrimChanged?.call(
      itemId: item.id,
      trimStart: item.trimStart,
      trimEnd: clamped,
      isStart: false,
    );
  }
}
