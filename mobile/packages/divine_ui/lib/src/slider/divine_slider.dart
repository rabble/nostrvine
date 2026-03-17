import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// A custom slider matching the Divine design system.
///
/// Wraps a Material [Slider] with a themed track (pill-shaped, uniform
/// height) and a tall rectangular thumb indicator. The active portion uses
/// the primary color and the inactive portion uses
/// [VineTheme.onSurfaceDisabled].
class DivineSlider extends StatelessWidget {
  /// Creates a [DivineSlider].
  ///
  /// [value] must be between [min] and [max].
  const DivineSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.trackHeight = 8,
    this.thumbWidth = 4,
    this.thumbHeight = 32,
    this.activeColor = VineTheme.primary,
    this.inactiveColor = VineTheme.onSurfaceDisabled,
    this.thumbColor = VineTheme.onSurface,
    super.key,
  });

  /// The current value of the slider.
  final double value;

  /// Called when the user changes the slider value.
  final ValueChanged<double>? onChanged;

  /// The minimum value. Defaults to `0`.
  final double min;

  /// The maximum value. Defaults to `1`.
  final double max;

  /// Height of the track in logical pixels. Defaults to `8`.
  final double trackHeight;

  /// Width of the thumb indicator. Defaults to `4`.
  final double thumbWidth;

  /// Height of the thumb indicator. Defaults to `32`.
  final double thumbHeight;

  /// Color of the filled (active) track portion.
  final Color activeColor;

  /// Color of the unfilled (inactive) track portion.
  final Color inactiveColor;

  /// Color of the thumb indicator.
  final Color thumbColor;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        padding: EdgeInsets.zero,
        activeTrackColor: activeColor,
        inactiveTrackColor: inactiveColor,
        trackHeight: trackHeight,
        trackShape: DivineSliderTrackShape(trackHeight: trackHeight),
        thumbColor: thumbColor,
        thumbShape: DivineSliderThumbShape(
          width: thumbWidth,
          height: thumbHeight,
        ),
        overlayShape: SliderComponentShape.noOverlay,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

/// Uniform-height track with pill-shaped (fully rounded) ends.
///
/// Both the active and inactive portions share the same height, unlike
/// the default [RoundedRectSliderTrackShape].
@visibleForTesting
class DivineSliderTrackShape extends SliderTrackShape {
  /// Creates a uniform track shape with the given [trackHeight].
  const DivineSliderTrackShape({this.trackHeight = 8});

  /// Height of the track.
  final double trackHeight;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Offset offset = Offset.zero,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
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
    final trackRadius = Radius.circular(trackHeight / 2);
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackBottom = trackTop + trackHeight;
    final trackLeft = offset.dx;
    final trackRight = offset.dx + parentBox.size.width;

    final canvas = context.canvas;

    // Inactive track (right side) — flat left, rounded right
    final inactiveRect = RRect.fromLTRBAndCorners(
      thumbCenter.dx,
      trackTop,
      trackRight,
      trackBottom,
      topRight: trackRadius,
      bottomRight: trackRadius,
    );
    canvas.drawRRect(
      inactiveRect,
      Paint()
        ..color =
            sliderTheme.inactiveTrackColor ?? inactiveRect.tlRadius.x as Color,
    );

    // Active track (left side) — rounded left, flat right
    final activeRect = RRect.fromLTRBAndCorners(
      trackLeft,
      trackTop,
      thumbCenter.dx,
      trackBottom,
      topLeft: trackRadius,
      bottomLeft: trackRadius,
    );
    canvas.drawRRect(
      activeRect,
      Paint()..color = sliderTheme.activeTrackColor ?? VineTheme.primary,
    );
  }
}

/// Tall rectangular thumb with rounded corners for the Divine slider.
@visibleForTesting
class DivineSliderThumbShape extends SliderComponentShape {
  /// Creates a thumb shape with the given [width] and [height].
  const DivineSliderThumbShape({
    this.width = 4,
    this.height = 32,
  });

  /// Width of the thumb.
  final double width;

  /// Height of the thumb.
  final double height;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
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
    final adjustedCenter = Offset(center.dx + width / 2, center.dy);
    final rect = Rect.fromCenter(
      center: adjustedCenter,
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width)),
      Paint()..color = sliderTheme.thumbColor ?? VineTheme.onSurface,
    );
  }
}
