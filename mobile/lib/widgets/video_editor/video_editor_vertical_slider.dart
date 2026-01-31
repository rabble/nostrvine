// ABOUTME: Vertical slider widget for video editor controls.
// ABOUTME: Used for adjusting filter opacity with a custom vertical design.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A vertical slider with a custom design matching the Figma specs.
///
/// Features:
/// - Vertical track with gradient (active portion colored)
/// - Round thumb with subtle drop shadow
/// - Smooth drag interaction
class VideoEditorVerticalSlider extends StatefulWidget {
  const VideoEditorVerticalSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.height = 300,
  });

  /// Current value (0.0 - 1.0).
  final double value;

  /// Called during drag with the new value.
  final ValueChanged<double> onChanged;

  /// Called when drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// Total height of the slider.
  final double height;

  @override
  State<VideoEditorVerticalSlider> createState() =>
      _VideoEditorVerticalSliderState();
}

class _VideoEditorVerticalSliderState extends State<VideoEditorVerticalSlider> {
  static const _trackWidth = 2.0;

  double _dragValue = 0;
  bool _isDragging = false;

  double get _currentValue => _isDragging ? _dragValue : widget.value;

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _updateValue(details.localPosition);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _updateValue(details.localPosition);
  }

  void _handleDragEnd(DragEndDetails details) {
    widget.onChangeEnd?.call(_dragValue);
    setState(() => _isDragging = false);
  }

  void _updateValue(Offset localPosition) {
    // Invert because 0 is at bottom, 1 is at top
    final normalizedY = 1 - (localPosition.dy / widget.height).clamp(0.0, 1.0);
    setState(() => _dragValue = normalizedY);
    widget.onChanged(normalizedY);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        behavior: .opaque,
        child: SizedBox(
          height: widget.height,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              // Extra padding for touch target
              minWidth: kMinInteractiveDimension,
            ),
            child: Stack(
              alignment: .centerRight,
              clipBehavior: .none,
              children: [
                // Track
                _Track(
                  height: widget.height,
                  trackWidth: _trackWidth,
                  value: _currentValue,
                ),
                // Thumb
                _Thumb(value: _currentValue, height: widget.height),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The vertical track with gradient coloring.
class _Track extends StatelessWidget {
  const _Track({
    required this.height,
    required this.trackWidth,
    required this.value,
  });

  final double height;
  final double trackWidth; // Not used anymore, kept for API compatibility
  final double value;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(16, height),
      painter: _TrackPainter(
        value: value,
        activeColor: VineTheme.onSurface,
        inactiveColor: VineTheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double value;
  final Color activeColor;
  final Color inactiveColor;

  static const double topWidth = 16;
  static const double bottomWidth = 4;
  static const double borderRadius = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;

    // The split point between active (bottom) and inactive (top)
    // value=1 means thumb at top (all active), value=0 means thumb at bottom
    // (all inactive)
    final splitY = (1 - value) * height;

    // Calculate width at split point (linear interpolation)
    final splitWidth = topWidth - (topWidth - bottomWidth) * (splitY / height);

    // Draw inactive part (above split) - from top to splitY
    if (splitY > 0) {
      final inactivePath = _buildTrapezoidPath(
        top: 0,
        bottom: splitY,
        topWidth: topWidth,
        bottomWidth: splitWidth,
        totalHeight: height,
      );
      canvas.drawPath(inactivePath, Paint()..color = inactiveColor);
    }

    // Draw active part (below split) - from splitY to bottom
    if (splitY < height) {
      final activePath = _buildTrapezoidPath(
        top: splitY,
        bottom: height,
        topWidth: splitWidth,
        bottomWidth: bottomWidth,
        totalHeight: height,
      );
      canvas.drawPath(activePath, Paint()..color = activeColor);
    }
  }

  Path _buildTrapezoidPath({
    required double top,
    required double bottom,
    required double topWidth,
    required double bottomWidth,
    required double totalHeight,
  }) {
    final path = Path();

    // Right side is aligned to the right edge (x = 16)
    // Left side is angled
    const rightEdge = _TrackPainter.topWidth;

    final topLeft = rightEdge - topWidth;
    final bottomLeft = rightEdge - bottomWidth;

    // Start at top-right, go clockwise
    // Top-right corner (rounded)
    path
      ..moveTo(rightEdge - borderRadius, top)
      ..quadraticBezierTo(rightEdge, top, rightEdge, top + borderRadius)
      // Right edge (straight down)
      ..lineTo(rightEdge, bottom - borderRadius)
      // Bottom-right corner (rounded)
      ..quadraticBezierTo(rightEdge, bottom, rightEdge - borderRadius, bottom)
      // Bottom edge
      ..lineTo(bottomLeft + borderRadius, bottom)
      // Bottom-left corner (rounded)
      ..quadraticBezierTo(bottomLeft, bottom, bottomLeft, bottom - borderRadius)
      // Left edge (angled up)
      ..lineTo(topLeft, top + borderRadius)
      // Top-left corner (rounded)
      ..quadraticBezierTo(topLeft, top, topLeft + borderRadius, top)
      // Top edge back to start
      ..close();

    return path;
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

/// The draggable thumb with shadow.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.value, required this.height});

  final double value;
  final double height;

  static const double _width = 24;
  static const double _height = 20;

  @override
  Widget build(BuildContext context) {
    // Position from bottom (0) to top (1)
    final thumbTop = (1 - value) * (height - _height);

    return Positioned(
      top: thumbTop,
      child: Row(
        spacing: 8,
        children: [
          Text(
            (value * 100).toStringAsFixed(0),
            style: VineTheme.labelMediumFont(
              fontFeatures: [const .tabularFigures()],
            ),
          ),
          Container(
            width: _width,
            height: _height,
            decoration: const BoxDecoration(
              color: VineTheme.whiteText,
              borderRadius: BorderRadius.horizontal(left: .circular(3)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x3C000000),
                  offset: Offset(1, 1),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
