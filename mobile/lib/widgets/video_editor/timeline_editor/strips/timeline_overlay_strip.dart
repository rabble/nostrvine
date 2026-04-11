// ABOUTME: Generic overlay strip widget for the video editor timeline.
// ABOUTME: Renders layer / filter / sound items in rows with long-press
// ABOUTME: drag to reposition (time + row) and trim handles on selection.

import 'package:divine_ui/divine_ui.dart';
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
      // TODO(hm21): If overlay item counts grow beyond ~20 per strip,
      // split into a static layer (non-dragged items) and a drag overlay
      // (single dragged item) so only 1 widget rebuilds per drag frame
      // instead of the entire Stack. Profile first on low-end devices.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in widget.items)
            _OverlayItemPositioned(
              item: item,
              isDragging: _draggingId == item.id,
              isSelected: widget.selectedItemId == item.id,
              isCollapsed: widget.isCollapsed,
              dragDeltaX: _dragDeltaX,
              dragDeltaY: _dragDeltaY,
              pixelsPerSecond: widget.pixelsPerSecond,
              rowHeight: _rowHeight,
              color: widget.color,
              displayRowCount: displayRowCount,
              onTap: () => widget.onItemTapped?.call(item.id),
              onLongPressStart: () => _onLongPressStart(item),
              onLongPressMoveUpdate: (details) =>
                  _onLongPressMoveUpdate(details, item, displayRowCount),
              onLongPressEnd: () => _onLongPressEnd(item),
              onTrimChanged: widget.onTrimChanged,
              onTrimDragChanged: widget.onTrimDragChanged,
            ),
        ],
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
      _dragDeltaX = details.offsetFromOrigin.dx;
      _dragDeltaY = details.offsetFromOrigin.dy;
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
    final maxRow = (widget.rowCount - 1).clamp(0, widget.rowCount);
    final newRow = (_dragStartRow + rowDelta).clamp(0, maxRow);

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

/// A single positioned overlay item inside the [Stack].
///
/// Computes its own x/y position from [item] timing, applies drag offsets
/// when [isDragging], and wraps with [TimelineTrimHandles] when selected.
class _OverlayItemPositioned extends StatelessWidget {
  const _OverlayItemPositioned({
    required this.item,
    required this.isDragging,
    required this.isSelected,
    required this.isCollapsed,
    required this.dragDeltaX,
    required this.dragDeltaY,
    required this.pixelsPerSecond,
    required this.rowHeight,
    required this.color,
    required this.displayRowCount,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    this.onTrimChanged,
    this.onTrimDragChanged,
  });

  final TimelineOverlayItem item;
  final bool isDragging;
  final bool isSelected;
  final bool isCollapsed;
  final double dragDeltaX;
  final double dragDeltaY;
  final double pixelsPerSecond;
  final double rowHeight;
  final Color color;
  final int displayRowCount;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final void Function(LongPressMoveUpdateDetails) onLongPressMoveUpdate;
  final VoidCallback onLongPressEnd;
  final OverlayTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;

  @override
  Widget build(BuildContext context) {
    // Layout: x position from startTime, width from trimmedDuration.
    final baseX = item.startTimeInSeconds * pixelsPerSecond;
    final itemWidth = item.trimmedDurationInSeconds * pixelsPerSecond;

    // Don't render if the item has zero width.
    if (itemWidth <= 0) return const SizedBox.shrink();

    final row = isCollapsed ? 0 : item.row;
    final baseY = row * rowHeight;

    // Apply drag offset to the dragged item.
    final x = isDragging ? baseX + dragDeltaX : baseX;
    final y = isDragging ? baseY + dragDeltaY : baseY;

    Widget tile = _OverlayItemTile(
      item: item,
      width: itemWidth,
      height: rowHeight,
      color: color,
      isDragging: isDragging,
    );

    // Wrap selected (non-dragging) items with trim handles.
    if (isSelected && !isDragging) {
      tile = _TrimmableOverlayTile(
        item: item,
        width: itemWidth,
        height: rowHeight,
        color: color,
        pixelsPerSecond: pixelsPerSecond,
        onTrimChanged: onTrimChanged,
        onTrimDragChanged: onTrimDragChanged,
      );
    }

    return Positioned(
      left: x,
      top: y,
      child: Semantics(
        label: item.label,
        hint: 'Long press to drag',
        child: GestureDetector(
          onTap: onTap,
          onLongPressStart: (_) => onLongPressStart(),
          onLongPressMoveUpdate: onLongPressMoveUpdate,
          onLongPressEnd: (_) => onLongPressEnd(),
          child: tile,
        ),
      ),
    );
  }
}

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
    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : TimelineConstants.overlayTileAnimDuration,
      width: width,
      height: height - TimelineConstants.overlayRowGap,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDragging ? 0.85 : 0.7),
        borderRadius: BorderRadius.circular(
          TimelineConstants.thumbnailRadius,
        ),
        border: isDragging
            ? Border.all(
                color: VineTheme.whiteText,
                width: TimelineConstants.dragBorderWidth,
              )
            : null,
        boxShadow: isDragging
            ? const [
                BoxShadow(
                  color: VineTheme.innerShadow,
                  blurRadius: TimelineConstants.dragShadowBlurRadius,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TimelineConstants.overlayItemPadding,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.label,
            style: VineTheme.labelSmallFont(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  State<_TrimmableOverlayTile> createState() => _TrimmableOverlayTileState();
}

class _TrimmableOverlayTileState extends State<_TrimmableOverlayTile> {
  bool _isDragStarted = false;
  bool _leftAtLimit = false;
  bool _rightAtLimit = false;

  @override
  Widget build(BuildContext context) {
    return TimelineTrimHandles(
      height: widget.height - TimelineConstants.overlayRowGap,
      handleColor: widget.color,
      onDragStart: _onDragStart,
      onDragEnd: _onDragEnd,
      onLeftDragUpdate: _onLeftTrim,
      onRightDragUpdate: _onRightTrim,
      child: _OverlayItemTile(
        item: widget.item,
        width: widget.width - TimelineConstants.trimHandleWidth * 2,
        height: widget.height,
        color: widget.color,
      ),
    );
  }

  void _onDragStart() {
    _isDragStarted = false;
    _leftAtLimit = false;
    _rightAtLimit = false;
    widget.onTrimDragChanged?.call(true);
  }

  void _onDragEnd() {
    _isDragStarted = false;
    widget.onTrimDragChanged?.call(false);
  }

  void _onLeftTrim(double dx) {
    final item = widget.item;
    final deltaDuration = Duration(
      milliseconds: (dx / widget.pixelsPerSecond * 1000).round(),
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

    final atLimit = clamped != newTrimStart;

    if (atLimit && !_leftAtLimit) {
      HapticFeedback.selectionClick();
    }
    _leftAtLimit = atLimit;

    if (clamped == item.trimStart) return;

    widget.onTrimChanged?.call(
      itemId: item.id,
      trimStart: clamped,
      trimEnd: item.trimEnd,
      isStart: !_isDragStarted,
    );
    _isDragStarted = true;
  }

  void _onRightTrim(double dx) {
    final item = widget.item;
    final deltaDuration = Duration(
      milliseconds: (-dx / widget.pixelsPerSecond * 1000).round(),
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

    final atLimit = clamped != newTrimEnd;

    if (atLimit && !_rightAtLimit) {
      HapticFeedback.selectionClick();
    }
    _rightAtLimit = atLimit;

    if (clamped == item.trimEnd) return;

    widget.onTrimChanged?.call(
      itemId: item.id,
      trimStart: item.trimStart,
      trimEnd: clamped,
      isStart: !_isDragStarted,
    );
    _isDragStarted = true;
  }
}
