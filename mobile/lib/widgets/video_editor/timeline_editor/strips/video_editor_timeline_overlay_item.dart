import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
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
    final radius = BorderRadius.circular(TimelineConstants.thumbnailRadius);
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
                    currentDuration: item.duration,
                    sourceDuration: item.sourceDuration,
                    startOffset: item.startOffset,
                    leftChannel: item.waveformLeftChannel,
                    rightChannel: item.waveformRightChannel,
                  )
                : Align(
                    alignment: .centerLeft,
                    child: Padding(
                      padding: const .symmetric(horizontal: 6),
                      child: item.layer is PaintLayer
                          ? _PaintPreview(layer: item.layer! as PaintLayer)
                          : item.layer is WidgetLayer
                          ? _StickerPreview(item: item)
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
        painter: DrawPaintItem(item: layer.item, scale: layer.scale),
      ),
    );
  }
}

class _StickerPreview extends StatelessWidget {
  const _StickerPreview({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    final layer = item.layer as WidgetLayer?;
    StickerData? sticker;
    if (layer?.meta != null) {
      try {
        sticker = StickerData.fromJson(layer!.meta!);
      } catch (_) {
        // Non-sticker WidgetLayer — fall back to item.label below.
      }
    }

    final label = sticker != null
        ? sticker.layerName(
            Localizations.localeOf(context).languageCode,
            packDisplayName: _packDisplayName(context, sticker),
          )
        : item.label;

    return OverflowBox(
      maxWidth: double.infinity,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: .min,
        children: [
          if (layer != null) layer.widget,
          Text(
            label,
            style: VineTheme.labelMediumFont(
              color: VineTheme.accentVioletVariant,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  /// Resolves the localized pack name shown after the description.
  ///
  /// The bundled "Divine Originals" pack is translated through app
  /// localizations — the same key the picker header uses — so the strip
  /// label matches it across locales. Other packs fall back to the name
  /// shipped in their manifest metadata.
  String _packDisplayName(BuildContext context, StickerData sticker) {
    if (sticker.packData.packId == StickerPackData.fallback.packId) {
      return context.l10n.videoEditorStickersDivineOriginals;
    }
    return sticker.packData.packName;
  }
}

/// Sound-item content: label text at top, waveform bars at bottom.
///
/// The waveform shows the source samples windowed to
/// `[startOffset, startOffset + currentDuration]`. Left-trimming advances
/// [startOffset], scrolling the trimmed-away head out of view instead of
/// clipping the tail — so the visible waveform matches what actually plays.
class _SoundContent extends StatelessWidget {
  const _SoundContent({
    required this.label,
    required this.color,
    required this.currentDuration,
    this.sourceDuration,
    this.startOffset = Duration.zero,
    this.leftChannel,
    this.rightChannel,
  });

  final String label;
  final Color color;

  /// Visible span of the item on the timeline (`endTime - startTime`).
  final Duration currentDuration;

  /// Full duration of the underlying audio source, or `null` if unknown.
  final Duration? sourceDuration;

  /// Offset into the audio source where the visible segment begins.
  final Duration startOffset;

  final Float32List? leftChannel;
  final Float32List? rightChannel;

  @override
  Widget build(BuildContext context) {
    // The painter maps samples against the full-source duration, then windows
    // them to [startOffset, startOffset + currentDuration]. When the source
    // duration is unknown there's no basis to resolve the offset against, so
    // fall back to treating the visible span as the whole source.
    final hasSourceDuration =
        sourceDuration != null && sourceDuration! > Duration.zero;
    final audioDuration = hasSourceDuration ? sourceDuration! : currentDuration;
    final effectiveOffset = hasSourceDuration ? startOffset : Duration.zero;

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
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: StereoWaveformPainter(
                  leftChannel: leftChannel ?? Float32List(0),
                  rightChannel: rightChannel,
                  progress: 1,
                  activeColor: VineTheme.accentPurple,
                  inactiveColor: VineTheme.accentPurple,
                  audioDuration: audioDuration,
                  maxDuration: currentDuration,
                  startOffset: effectiveOffset,
                  barWidth: TimelineConstants.soundWaveformBarWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
