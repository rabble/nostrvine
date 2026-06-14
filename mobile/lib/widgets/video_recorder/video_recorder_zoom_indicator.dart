// ABOUTME: Android-style zoom ruler that appears only while pinch-zooming
// ABOUTME: Fine ticks scroll under a fixed centre marker; value floats above

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Transient zoom indicator modelled on the native Android camera ruler.
///
/// A horizontal strip of fine tick marks scrolls under a fixed centre
/// accent while the user pinch-zooms, with the live zoom factor floating
/// above it. It is purely a read-out — the pinch gesture on the preview
/// drives the zoom — so it ignores pointer events and only becomes visible
/// while [VideoRecorderBlocState.showZoomIndicator] is set (during a pinch
/// and for a short hold afterwards).
///
/// Renders nothing when the active camera exposes no usable zoom range
/// (single lens / before initialization).
class VideoRecorderZoomIndicator extends StatelessWidget {
  const VideoRecorderZoomIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final (
      :zoomLevel,
      :minZoomLevel,
      :maxZoomLevel,
      :showZoomIndicator,
    ) = context.select(
      (VideoRecorderBloc b) => (
        zoomLevel: b.state.zoomLevel,
        minZoomLevel: b.state.minZoomLevel,
        maxZoomLevel: b.state.maxZoomLevel,
        showZoomIndicator: b.state.showZoomIndicator,
      ),
    );

    // Single lens / no usable zoom range: nothing to indicate.
    if (maxZoomLevel - minZoomLevel <= _zoomRangeEpsilon) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: ExcludeSemantics(
        excluding: !showZoomIndicator,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: showZoomIndicator ? 1 : 0,
          child: Semantics(
            label: context.l10n.videoRecorderZoomLevelLabel(
              _accessibilityValue(zoomLevel),
            ),
            child: _ZoomRuler(
              zoom: zoomLevel,
              minZoom: minZoomLevel,
              maxZoom: maxZoomLevel,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomRuler extends StatelessWidget {
  const _ZoomRuler({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _valueLabel(zoom),
            style: VineTheme.titleMediumFont().copyWith(
              shadows: const [Shadow(color: VineTheme.scrim70, blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: _rulerHeight,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ZoomRulerPainter(
                  zoom: zoom,
                  minZoom: minZoom,
                  maxZoom: maxZoom,
                  labelStyle: VineTheme.labelSmallFont(
                    color: VineTheme.whiteText.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomRulerPainter extends CustomPainter {
  _ZoomRulerPainter({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.labelStyle,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final minorPaint = Paint()
      ..color = VineTheme.whiteText.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = VineTheme.whiteText.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Walk the ruler in integer steps of [_minorStep] to avoid float drift.
    final first = (minZoom / _minorStep).ceil();
    final last = (maxZoom / _minorStep).floor();
    for (var i = first; i <= last; i++) {
      final value = i * _minorStep;
      final x = centerX + (value - zoom) * _pxPerZoomUnit;
      if (x < 0 || x > size.width) continue;

      // Majors: every whole factor, plus the 0.5× ultra-wide stop.
      final isMajor = i % 10 == 0 || i == 5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, isMajor ? _majorTickHeight : _minorTickHeight),
        isMajor ? majorPaint : minorPaint,
      );

      if (isMajor) _paintLabel(canvas, x, _majorLabel(value));
    }

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, _accentHeight),
      Paint()
        ..color = VineTheme.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintLabel(Canvas canvas, double x, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(x - painter.width / 2, _majorTickHeight + 4),
    );
  }

  @override
  bool shouldRepaint(_ZoomRulerPainter old) =>
      old.zoom != zoom ||
      old.minZoom != minZoom ||
      old.maxZoom != maxZoom ||
      old.labelStyle != labelStyle;
}

/// Pixels of horizontal travel per 1.0× of zoom.
const _pxPerZoomUnit = 110.0;

/// Spacing between minor tick marks, in zoom units.
const _minorStep = 0.1;

const _minorTickHeight = 9.0;
const _majorTickHeight = 16.0;
const _accentHeight = 20.0;
const _rulerHeight = 36.0;

/// Below this the camera has effectively a single zoom stop, so the ruler
/// is never shown.
const _zoomRangeEpsilon = 0.01;

/// Floating value label, e.g. `0.5×`, `1×`, `2.4×` (drops a trailing `.0`).
String _valueLabel(double zoom) {
  final rounded = (zoom * 10).roundToDouble() / 10;
  if (rounded == rounded.truncateToDouble()) return '${rounded.toInt()}×';
  return '${rounded.toStringAsFixed(1)}×';
}

/// Compact tick label, e.g. `0.5` → `.5`, `1.0` → `1`.
String _majorLabel(double value) {
  if (value == value.truncateToDouble()) return '${value.toInt()}';
  return value.toStringAsFixed(1).replaceFirst('0.', '.');
}

/// Spoken value for screen readers, e.g. `0.5` or `1`.
String _accessibilityValue(double zoom) {
  final rounded = (zoom * 10).roundToDouble() / 10;
  if (rounded == rounded.truncateToDouble()) return '${rounded.toInt()}';
  return rounded.toStringAsFixed(1);
}
