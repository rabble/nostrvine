// ABOUTME: Widget displaying current and total video time with separator
// ABOUTME: Combines smooth interpolated current time with static total duration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_editor/clip_editor/smooth_time_display.dart';

/// Displays current video time and total duration with a separator.
class VideoTimeDisplay extends StatelessWidget {
  /// Creates a video time display.
  const VideoTimeDisplay({
    required this.isPlayingSelector,
    required this.currentPositionSelector,
    required this.totalDuration,
    this.maxDuration,
    this.currentStyle,
    this.separatorStyle,
    this.totalStyle,
    super.key,
  });

  /// Selector that extracts playing state from [ClipEditorState].
  final bool Function(ClipEditorState state) isPlayingSelector;

  /// Selector that extracts current position from [ClipEditorState].
  final Duration Function(ClipEditorState state) currentPositionSelector;

  /// Total video duration
  final Duration totalDuration;

  /// Upper bound for the interpolated current time. Defaults to
  /// [totalDuration] when not set.
  final Duration? maxDuration;

  /// Style for current time (defaults to white)
  final TextStyle? currentStyle;

  /// Style for separator (defaults to semi-transparent white)
  final TextStyle? separatorStyle;

  /// Style for total duration (defaults to semi-transparent white)
  final TextStyle? totalStyle;

  @override
  Widget build(BuildContext context) {
    final defaultCurrentStyle =
        currentStyle ??
        VineTheme.titleMediumFont().copyWith(
          fontFeatures: const [.tabularFigures()],
        );

    final defaultSeparatorStyle =
        separatorStyle ??
        defaultCurrentStyle.copyWith(
          color: VineTheme.onSurfaceMuted,
        );

    final defaultTotalStyle = totalStyle ?? defaultSeparatorStyle;
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: 1.3,
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Text.rich(
        TextSpan(
          style: defaultSeparatorStyle,

          children: [
            WidgetSpan(
              alignment: .baseline,
              baseline: .alphabetic,
              child: SmoothTimeDisplay(
                isPlayingSelector: isPlayingSelector,
                currentPositionSelector: currentPositionSelector,
                maxDuration: maxDuration ?? totalDuration,
                style: defaultCurrentStyle,
              ),
            ),
            const TextSpan(text: ' / '),
            TextSpan(
              text: '${totalDuration.toFormattedSeconds()}s',
              style: defaultTotalStyle,
            ),
          ],
        ),
      ),
    );
  }
}
