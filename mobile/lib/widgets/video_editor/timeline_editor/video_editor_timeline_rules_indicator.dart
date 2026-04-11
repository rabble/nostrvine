import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';

/// Ruler markers — "0s · 10f · 20f · 1s · …"
///
/// Adapts label density based on [pixelsPerSecond]. At low zoom
/// only whole-second labels appear; at high zoom frame-based
/// sub-second markers (10f, 20f) fill the gaps — like TikTok.
///
/// Uses [CustomPaint] with the [scrollController] as repaint
/// listenable so only the ~10–20 visible labels are drawn per frame,
/// regardless of total video length or zoom level.
class VideoEditorTimelineRulesIndicator extends StatelessWidget {
  const VideoEditorTimelineRulesIndicator({
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.scrollPadding,
    super.key,
  });

  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;

  /// Left padding of the enclosing [SingleChildScrollView].
  /// Needed so the painter can convert scroll offset to the
  /// ruler's local coordinate space.
  final double scrollPadding;

  @override
  Widget build(BuildContext context) {
    final totalSeconds = totalDuration.inMilliseconds / 1000.0;
    final totalWidth = totalSeconds * pixelsPerSecond;

    return ExcludeSemantics(
      child: SizedBox(
        width: totalWidth,
        height: TimelineConstants.rulerHeight,
        child: CustomPaint(
          painter: _RulerPainter(
            totalDuration: totalDuration,
            pixelsPerSecond: pixelsPerSecond,
            scrollController: scrollController,
            scrollPadding: scrollPadding,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.scrollPadding,
  }) : super(repaint: scrollController);

  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;
  final double scrollPadding;

  static const double _minLabelSpacing = 30;
  static const int _fps = 30;
  static const List<int> _frameSteps = [
    2,
    3,
    5,
    10,
    15,
    30,
    60,
    150,
    300,
    450,
    900,
    1800,
  ];

  static final TextStyle _labelStyle = VineTheme.labelSmallFont(
    color: VineTheme.onSurfaceMuted,
  ).copyWith(fontFeatures: [const FontFeature.tabularFigures()]);

  @override
  void paint(Canvas canvas, Size size) {
    final totalSeconds = totalDuration.inMilliseconds / 1000.0;
    final frameStep = _frameStepForZoom(pixelsPerSecond);
    final stepSeconds = frameStep / _fps;
    final stepPx = stepSeconds * pixelsPerSecond;
    final totalCount = (totalSeconds / stepSeconds).floor();
    final centerY = size.height / 2;

    // Convert scroll offset to the ruler's local coordinate space.
    // The ruler starts at [scrollPadding] within the scroll view,
    // so subtract it to get the visible range in ruler-local pixels.
    //
    // Use [positions] instead of [position] to avoid the assertion
    // "ScrollController attached to multiple scroll views" that can
    // trigger during rebuilds when old and new Scrollable briefly
    // coexist.
    final pos = scrollController.positions.lastOrNull;
    final scrollOffset = pos?.pixels ?? 0.0;
    final viewportWidth = pos?.viewportDimension ?? size.width;

    final rulerStart = scrollOffset - scrollPadding;

    // Add a buffer of one step on each side so labels at the edges
    // don't pop in.
    final visibleStart = rulerStart - stepPx;
    final visibleEnd = rulerStart + viewportWidth + stepPx;

    final firstIndex = (visibleStart / stepPx).floor().clamp(0, totalCount);
    final lastIndex = (visibleEnd / stepPx).ceil().clamp(0, totalCount);

    for (var i = firstIndex; i <= lastIndex; i++) {
      final x = i * stepPx;
      final label = _formatLabel(i * frameStep);

      final tp = TextPainter(
        text: TextSpan(text: label, style: _labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x, centerY - tp.height / 2));
    }
  }

  int _frameStepForZoom(double pps) {
    for (final step in _frameSteps) {
      final stepSeconds = step / _fps;
      if (stepSeconds * pps >= _minLabelSpacing) return step;
    }
    return _frameSteps.last;
  }

  String _formatLabel(int totalFrames) {
    if (totalFrames % _fps == 0) {
      return '${totalFrames ~/ _fps}s';
    }
    return '${totalFrames % _fps}f';
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.totalDuration != totalDuration ||
      oldDelegate.pixelsPerSecond != pixelsPerSecond ||
      oldDelegate.scrollPadding != scrollPadding;
}
