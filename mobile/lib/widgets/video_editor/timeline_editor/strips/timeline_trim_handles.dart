// ABOUTME: Universal trim handle wrapper for timeline strips.
// ABOUTME: Adds draggable left/right handles around a child widget.
// ABOUTME: Reusable for clip, layer, and audio strip trimming.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/hit_expanded_box.dart';

/// Callback reporting the horizontal drag delta in pixels.
typedef TrimDragCallback = void Function(double dx);

/// A reusable trim-handle overlay for timeline strips.
///
/// Wraps [child] with left and right drag handles that report pixel
/// deltas. The parent converts deltas to domain values (time, etc.)
/// and manages clamping / state updates.
///
/// Designed for reuse across clip, layer, and audio strips — colours,
/// sizes, and border radius are all configurable.
class TimelineTrimHandles extends StatefulWidget {
  const TimelineTrimHandles({
    required this.child,
    required this.height,
    this.onLeftDragUpdate,
    this.onRightDragUpdate,
    this.onDragStart,
    this.onDragEnd,
    this.handleColor = VineTheme.accentYellow,
    this.markerColor = TimelineConstants.trimHandleMarkerColor,
    this.handleWidth = TimelineConstants.trimHandleWidth,
    this.markerWidth = TimelineConstants.trimHandleMarkerWidth,
    this.markerHeight = TimelineConstants.trimHandleMarkerHeight,
    this.borderWidth = TimelineConstants.trimBorderWidth,
    this.borderRadius = TimelineConstants.thumbnailRadius,
    this.hitAreaExtra = TimelineConstants.trimHitAreaExtra,
    super.key,
  });

  /// Content displayed between the two handles.
  final Widget child;

  /// Total height of the trim container (including border).
  final double height;

  /// Called with the horizontal pixel delta when the left handle moves.
  final TrimDragCallback? onLeftDragUpdate;

  /// Called with the horizontal pixel delta when the right handle moves.
  final TrimDragCallback? onRightDragUpdate;

  /// Called when a drag gesture starts on either handle.
  final VoidCallback? onDragStart;

  /// Called when a drag gesture ends on either handle.
  final VoidCallback? onDragEnd;

  /// Background colour of the handles and border.
  final Color handleColor;

  /// Colour of the vertical marker line inside each handle.
  final Color markerColor;

  /// Width of each handle in logical pixels.
  final double handleWidth;

  /// Width of the marker line inside each handle.
  final double markerWidth;

  /// Height of the marker line inside each handle.
  final double markerHeight;

  /// Width of the border wrapping the content.
  final double borderWidth;

  /// Border radius of the outer container.
  final double borderRadius;

  /// Extra invisible hit area on the outer edge of each handle
  /// to make small handles easier to grab.
  final double hitAreaExtra;

  @override
  State<TimelineTrimHandles> createState() => _TimelineTrimHandlesState();
}

class _TimelineTrimHandlesState extends State<TimelineTrimHandles> {
  void _onDragStart(DragStartDetails _) {
    widget.onDragStart?.call();
  }

  void _onLeftDragUpdate(DragUpdateDetails details) {
    widget.onLeftDragUpdate?.call(details.delta.dx);
  }

  void _onRightDragUpdate(DragUpdateDetails details) {
    widget.onRightDragUpdate?.call(details.delta.dx);
  }

  void _onDragEnd(DragEndDetails _) {
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final handleW = widget.handleWidth - widget.borderWidth;
    final innerRadius = (widget.borderRadius - widget.borderWidth).clamp(
      0.0,
      double.infinity,
    );

    return HitExpandedBox(
      expandLeft: handleW + widget.hitAreaExtra,
      expandRight: handleW + widget.hitAreaExtra,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Content fills the widget area with border overlay.
          Positioned.fill(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: widget.handleColor,
                    width: widget.borderWidth,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: widget.child,
              ),
            ),
          ),
          // Left handle visual — positioned outside the left edge.
          Positioned(
            left: -handleW,
            top: 0,
            width: handleW,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.handleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.borderRadius),
                  bottomLeft: Radius.circular(widget.borderRadius),
                ),
              ),
              child: _HandleVisual(
                color: widget.handleColor,
                markerColor: widget.markerColor,
                markerWidth: widget.markerWidth,
                markerHeight: widget.markerHeight,
              ),
            ),
          ),
          // Right handle visual — positioned outside the right edge.
          Positioned(
            right: -handleW,
            top: 0,
            width: handleW,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.handleColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(widget.borderRadius),
                  bottomRight: Radius.circular(widget.borderRadius),
                ),
              ),
              child: _HandleVisual(
                color: widget.handleColor,
                markerColor: widget.markerColor,
                markerWidth: widget.markerWidth,
                markerHeight: widget.markerHeight,
              ),
            ),
          ),
          // Left hit area — covers the outer handle + extra grab zone.
          Positioned(
            left: -(handleW + widget.hitAreaExtra),
            top: 0,
            width: handleW + widget.hitAreaExtra + widget.borderWidth,
            height: widget.height,
            child: Semantics(
              label: 'Trim start',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onLeftDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
              ),
            ),
          ),
          // Right hit area — covers the outer handle + extra grab zone.
          Positioned(
            right: -(handleW + widget.hitAreaExtra),
            top: 0,
            width: handleW + widget.hitAreaExtra + widget.borderWidth,
            height: widget.height,
            child: Semantics(
              label: 'Trim end',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onRightDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual handle bar with a centred marker line.
class _HandleVisual extends StatelessWidget {
  const _HandleVisual({
    required this.color,
    required this.markerColor,
    required this.markerWidth,
    required this.markerHeight,
  });

  final Color color;
  final Color markerColor;
  final double markerWidth;
  final double markerHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: markerWidth,
        height: markerHeight,
        decoration: BoxDecoration(
          color: markerColor,
          borderRadius: BorderRadius.circular(markerWidth),
        ),
      ),
    );
  }
}
