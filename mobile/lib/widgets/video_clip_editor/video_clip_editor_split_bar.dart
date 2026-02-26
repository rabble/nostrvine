// ABOUTME: Interactive slider for selecting clip split position in video editor
// ABOUTME: Custom styled Material Slider with tall rectangular thumb for precise trimming

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// A video editor split bar using Material Slider with custom styling.
/// The left section is highlighted in primary color, the right section is
/// disabled.
class VideoClipEditorSplitBar extends ConsumerWidget {
  const VideoClipEditorSplitBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoEditorState = ref.watch(
      videoEditorProvider.select(
        (s) => (
          trimPosition: s.splitPosition,
          currentClipIndex: s.currentClipIndex,
        ),
      ),
    );
    final clipDuration = ref.watch(
      clipManagerProvider.select((p) {
        final clipIndex = videoEditorState.currentClipIndex;

        if (clipIndex >= p.clips.length) {
          assert(
            false,
            'Clip index $clipIndex is out of bounds. '
            'Total clips: ${p.clips.length}',
          );
          return Duration.zero;
        }

        return p.clips[clipIndex].duration;
      }),
    );
    const handleColor = Colors.white;
    final disabledColor = Colors.white.withAlpha(65);

    final videoPosition = videoEditorState.trimPosition;

    return RepaintBoundary(
      child: SliderTheme(
        data: SliderThemeData(
          padding: .zero,
          activeTrackColor: VineTheme.tabIndicatorGreen,
          inactiveTrackColor: disabledColor,
          trackHeight: 8,
          trackShape: const UniformTrackShape(),
          thumbColor: handleColor,
          thumbShape: const _TallRectangularThumbShape(),
          overlayShape: .noOverlay,
          showValueIndicator: .never,
        ),
        child: Slider(
          value: videoPosition.inMilliseconds.toDouble(),
          onChanged: (value) {
            final position = Duration(milliseconds: value.toInt());
            ref.read(videoEditorProvider.notifier).seekToTrimPosition(position);
          },
          max: max(
            videoPosition.inMilliseconds,
            clipDuration.inMilliseconds,
          ).toDouble(),
        ),
      ),
    );
  }
}

/// Custom thumb shape for the video editor split bar.
/// Creates a tall rectangular thumb (4px wide x 32px tall) with rounded
/// corners.
class _TallRectangularThumbShape extends SliderComponentShape {
  const _TallRectangularThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(4, 32);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Adjust center position so the thumb sits at the end of the active track
    // Offset by half the thumb width (2px) to align with track boundary
    final adjustedCenter = Offset(center.dx + 2, center.dy);

    final rect = Rect.fromCenter(center: adjustedCenter, width: 4, height: 32);

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.white
      ..style = .fill;

    final rRect = RRect.fromRectAndRadius(rect, const .circular(8));

    canvas.drawRRect(rRect, paint);
  }
}

/// Custom track shape that renders both active and inactive tracks
/// with the same height, unlike [RoundedRectSliderTrackShape] which
/// makes the inactive track thinner.
@visibleForTesting
class UniformTrackShape extends SliderTrackShape {
  /// Creates a uniform track shape for sliders.
  const UniformTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Offset offset = Offset.zero,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 8;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(
      offset.dx,
      trackTop,
      parentBox.size.width,
      trackHeight,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    required TextDirection textDirection,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 8;
    final trackRadius = Radius.circular(trackHeight / 2);
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackBottom = trackTop + trackHeight;
    final trackLeft = offset.dx;
    final trackRight = offset.dx + parentBox.size.width;

    final canvas = context.canvas;

    // Draw inactive track (right side) - flat left, rounded right
    final inactiveTrackRect = RRect.fromLTRBAndCorners(
      thumbCenter.dx,
      trackTop,
      trackRight,
      trackBottom,
      topRight: trackRadius,
      bottomRight: trackRadius,
    );
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey;
    canvas.drawRRect(inactiveTrackRect, inactivePaint);

    // Draw active track (left side) - rounded left, flat right
    final activeTrackRect = RRect.fromLTRBAndCorners(
      trackLeft,
      trackTop,
      thumbCenter.dx,
      trackBottom,
      topLeft: trackRadius,
      bottomLeft: trackRadius,
    );
    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue;
    canvas.drawRRect(activeTrackRect, activePaint);
  }
}
