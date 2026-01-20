import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_editor/smooth_time_display.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Displays current video time and total duration with a separator.
class VideoTimeDisplay extends ConsumerWidget {
  /// Creates a video time display.
  const VideoTimeDisplay({
    required this.isPlayingSelector,
    required this.currentPositionSelector,
    required this.totalDuration,
    this.currentStyle,
    this.separatorStyle,
    this.totalStyle,
    super.key,
  });

  /// Provider selector for playing state
  final ProviderListenable<bool> isPlayingSelector;

  /// Provider selector for current position
  final ProviderListenable<Duration> currentPositionSelector;

  /// Total video duration
  final Duration totalDuration;

  /// Style for current time (defaults to white)
  final TextStyle? currentStyle;

  /// Style for separator (defaults to semi-transparent white)
  final TextStyle? separatorStyle;

  /// Style for total duration (defaults to semi-transparent white)
  final TextStyle? totalStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultCurrentStyle =
        currentStyle ??
        const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontFamily: 'Bricolage Grotesque',
          fontWeight: .w800,
          height: 1.33,
          letterSpacing: 0.15,
        );

    final defaultSeparatorStyle =
        separatorStyle ??
        defaultCurrentStyle.copyWith(
          color: Colors.white.withValues(alpha: 0.5),
        );

    final defaultTotalStyle = totalStyle ?? defaultSeparatorStyle;

    return Text.rich(
      TextSpan(
        style: defaultSeparatorStyle,
        children: [
          WidgetSpan(
            alignment: .baseline,
            baseline: .alphabetic,
            child: SmoothTimeDisplay(
              isPlayingSelector: isPlayingSelector,
              currentPositionSelector: currentPositionSelector,
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
    );
  }
}
