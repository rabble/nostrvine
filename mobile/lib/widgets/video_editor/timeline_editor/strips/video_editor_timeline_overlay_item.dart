import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Visual representation of a single overlay item.
class TimelineOverlayItemTile extends StatelessWidget {
  const TimelineOverlayItemTile({
    required this.item,
    required this.width,
    required this.height,
    required this.color,
    super.key,
    this.isDragging = false,
    this.isSelected = false,
  });

  final TimelineOverlayItem item;
  final double width;
  final double height;
  final Color color;
  final bool isDragging;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final radius = BorderRadius.circular(
      TimelineConstants.thumbnailRadius,
    );
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);

    final Color backgroundColor;
    final Color foregroundColor;
    String? fontFamily;

    switch (item.layer) {
      case final TextLayer layer:
        foregroundColor = layer.color;
        backgroundColor = layer.background;
        fontFamily = layer.textStyle?.fontFamily;

      case final PaintLayer layer:
        foregroundColor = layer.item.color;
        // Pick a contrasting background so paint strokes stay visible.
        backgroundColor = layer.item.color.computeLuminance() > 0.5
            ? VineTheme.onPrimaryButton
            : VineTheme.whiteText;

      default:
        // Sound items use the violet palette from the Figma spec;
        // other overlay types fall back to the strip color.
        if (item.type == .sound) {
          foregroundColor = VineTheme.accentVioletVariant;
        } else {
          foregroundColor = VineTheme.whiteText;
        }
        backgroundColor = color;
    }

    return SizedBox(
      width: width,
      height: height - TimelineConstants.overlayRowGap,
      child: AnimatedContainer(
        duration: animDuration,
        decoration: BoxDecoration(
          boxShadow: isDragging
              ? const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        foregroundDecoration: isDragging
            ? BoxDecoration(
                borderRadius: radius,
                border: .all(color: VineTheme.whiteText, width: 1.5),
              )
            : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: isSelected ? .circular(0) : radius,
          ),
          child: ClipRRect(
            borderRadius: isSelected ? .zero : radius,
            child: item.type == .sound
                ? _SoundContent(
                    label: item.label,
                    color: foregroundColor,
                    duration: item.duration,
                    leftChannel: item.waveformLeftChannel,
                    rightChannel: item.waveformRightChannel,
                  )
                : Align(
                    alignment: .centerLeft,
                    child: Padding(
                      padding: const .symmetric(horizontal: 6),
                      child: item.layer is PaintLayer
                          ? _PaintPreview(layer: item.layer! as PaintLayer)
                          : Text(
                              item.label,
                              style: VineTheme.labelMediumFont(
                                color: foregroundColor,
                              ).copyWith(fontFamily: fontFamily),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Renders a live preview of paint strokes inside the timeline tile.
class _PaintPreview extends StatelessWidget {
  const _PaintPreview({required this.layer});

  final PaintLayer layer;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: CustomPaint(
        size: layer.size,
        painter: DrawPaintItem(
          item: layer.item,
          scale: layer.scale,
        ),
      ),
    );
  }
}

/// Sound-item content: label text at top, waveform bars at bottom.
class _SoundContent extends StatelessWidget {
  const _SoundContent({
    required this.label,
    required this.color,
    required this.duration,
    this.leftChannel,
    this.rightChannel,
  });

  final String label;
  final Color color;
  final Duration duration;
  final Float32List? leftChannel;
  final Float32List? rightChannel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(0, 8, 0, 4),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 4,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 8),
            child: Text(
              label,
              style: VineTheme.labelMediumFont(color: color),
              maxLines: 1,
              overflow: .ellipsis,
            ),
          ),

          Expanded(
            child: CustomPaint(
              painter: StereoWaveformPainter(
                leftChannel: leftChannel ?? Float32List(0),
                rightChannel: rightChannel,
                progress: 1, // No progress indicator needed
                activeColor: VineTheme.accentPurple,
                inactiveColor: VineTheme.accentPurple,
                audioDuration: duration,
                maxDuration: duration,
                barWidth: TimelineConstants.soundWaveformBarWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
