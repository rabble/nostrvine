import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_constants.dart';

/// Ruler markers — "0s · 10f · 20f · 1s · …"
///
/// Adapts label density based on [pixelsPerSecond]. At low zoom
/// only whole-second labels appear; at high zoom frame-based
/// sub-second markers (10f, 20f) fill the gaps — like TikTok.
class VideoEditorTimelineRulesIndicator extends StatelessWidget {
  const VideoEditorTimelineRulesIndicator({
    required this.totalDuration,
    required this.pixelsPerSecond,
    super.key,
  });

  final Duration totalDuration;
  final double pixelsPerSecond;

  /// Minimum pixel distance between two adjacent labels.
  static const double _minLabelSpacing = 30;

  /// Assumed frame rate for frame-based labels.
  static const int _fps = 30;

  /// Candidate steps as frame counts at [_fps].
  /// Sub-second: 2f, 3f, 5f, 10f, 15f → then whole-second multiples.
  static const List<int> _frameSteps = [
    2, // 2f  = 0.067s
    3, // 3f  = 0.1s
    5, // 5f  = 0.167s
    10, // 10f = 0.333s
    15, // 15f = 0.5s
    30, // 30f = 1s
    60, // 60f = 2s
    150, // 150f = 5s
    300, // 300f = 10s
    450, // 450f = 15s
    900, // 900f = 30s
    1800, // 1800f = 60s
  ];

  @override
  Widget build(BuildContext context) {
    final totalSeconds = totalDuration.inMilliseconds / 1000.0;
    final totalWidth = totalSeconds * pixelsPerSecond;

    final style = VineTheme.labelSmallFont(
      color: VineTheme.onSurfaceMuted,
    ).copyWith(fontFeatures: [const FontFeature.tabularFigures()]);

    final frameStep = _frameStepForZoom(pixelsPerSecond);
    final stepSeconds = frameStep / _fps;
    final count = (totalSeconds / stepSeconds).floor();

    return SizedBox(
      width: totalWidth,
      height: TimelineConstants.rulerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i <= count; i++)
            Positioned(
              left: i * stepSeconds * pixelsPerSecond,
              top: 0,
              bottom: 0,
              child: _RulerLabel(
                label: _formatLabel(i * frameStep),
                style: style,
              ),
            ),
        ],
      ),
    );
  }

  int _frameStepForZoom(double pps) {
    for (final step in _frameSteps) {
      final stepSeconds = step / _fps;
      if (stepSeconds * pps >= _minLabelSpacing) return step;
    }
    return _frameSteps.last;
  }

  /// Formats a frame count as a label.
  ///
  /// Whole seconds → "0s", "1s", "2s".
  /// Sub-second → "10f", "20f".
  String _formatLabel(int totalFrames) {
    if (totalFrames % _fps == 0) {
      return '${totalFrames ~/ _fps}s';
    }
    return '${totalFrames % _fps}f';
  }
}

class _RulerLabel extends StatelessWidget {
  const _RulerLabel({
    required this.label,
    required this.style,
  });

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: style, maxLines: 1),
    );
  }
}
