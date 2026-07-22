// ABOUTME: Bottom sheet for picking the track-wide caption style preset.
// ABOUTME: Each tile loops the preset's real font, colors, and animation.

import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style_preset.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Resolves the localized display name of the preset with [presetId].
String captionPresetDisplayName(AppLocalizations l10n, String presetId) =>
    switch (presetId) {
      'pop' => l10n.videoEditorCaptionsPresetPop,
      'slideUp' => l10n.videoEditorCaptionsPresetSlideUp,
      'spring' => l10n.videoEditorCaptionsPresetSpring,
      'mono' => l10n.videoEditorCaptionsPresetMono,
      'headline' => l10n.videoEditorCaptionsPresetHeadline,
      _ => l10n.videoEditorCaptionsPresetClassic,
    };

/// Shows the caption preset picker; resolves with the chosen preset id, or
/// `null` when dismissed.
Future<String?> showCaptionPresetSheet(
  BuildContext context, {
  required String selectedId,
}) {
  return VineBottomSheet.show<String>(
    context: context,
    expanded: false,
    scrollable: false,
    title: Text(context.l10n.videoEditorCaptionsPresetTitle),
    body: CaptionPresetPickerView(selectedId: selectedId),
  );
}

/// Horizontal list of caption presets with looping animated previews.
class CaptionPresetPickerView extends StatefulWidget {
  /// Creates the picker with the currently selected preset highlighted.
  const CaptionPresetPickerView({required this.selectedId, super.key});

  /// The currently selected preset id.
  final String selectedId;

  @override
  State<CaptionPresetPickerView> createState() =>
      _CaptionPresetPickerViewState();
}

class _CaptionPresetPickerViewState extends State<CaptionPresetPickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// One preview loop: enter animation, hold, repeat.
  static const _loopMs = 2400;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _loopMs),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 170,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: CaptionStylePreset.presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = CaptionStylePreset.presets[index];
          return _PresetTile(
            preset: preset,
            label: captionPresetDisplayName(l10n, preset.id),
            selected: preset.id == widget.selectedId,
            controller: _controller,
            loopMs: _loopMs,
            onTap: () => Navigator.of(context).pop(preset.id),
          );
        },
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.label,
    required this.selected,
    required this.controller,
    required this.loopMs,
    required this.onTap,
  });

  final CaptionStylePreset preset;
  final String label;
  final bool selected;
  final AnimationController controller;
  final int loopMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Same semantics shape as the layer-animation picker tiles: one button
    // node, preview and caption excluded so the label isn't announced twice.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            spacing: 6,
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? VineTheme.primary : VineTheme.transparent,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => _PresetPreview(
                          preset: preset,
                          label: label,
                          loopValue: controller.value,
                          loopMs: loopMs,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: VineTheme.labelSmallFont(
                    color: selected ? VineTheme.primary : VineTheme.lightText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the preset's sample caption with its enter animations applied at
/// the controller's current loop position.
class _PresetPreview extends StatelessWidget {
  const _PresetPreview({
    required this.preset,
    required this.label,
    required this.loopValue,
    required this.loopMs,
  });

  final CaptionStylePreset preset;
  final String label;
  final double loopValue;
  final int loopMs;

  static const double _width = 108;
  static const double _height = 120;

  @override
  Widget build(BuildContext context) {
    var opacity = 1.0;
    var scale = 1.0;
    var offset = Offset.zero;

    // Compose all enter animations, matching how the export renderer and
    // LayerTimelineVisibility combine per-layer animations.
    for (final animation in preset.enter) {
      final progress = flutterCurveFor(animation.curve).transform(
        _holdProgress(loopValue, animation.duration.inMilliseconds),
      );
      switch (animation.type.name) {
        case 'fade':
          opacity *= progress.clamp(0.0, 1.0);
        case 'scale':
          scale *= lerpDouble(animation.scaleFrom ?? 0.5, 1, progress) ?? 1;
        case 'slide':
          final away = 1 - progress;
          offset += switch (animation.slideDirection?.name) {
            'left' => Offset(-away * _width, 0),
            'right' => Offset(away * _width, 0),
            'top' => Offset(0, -away * _height),
            _ => Offset(0, away * _height),
          };
      }
    }

    final hasPill = preset.colorMode != LayerBackgroundMode.onlyColor;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VineTheme.primaryDarkGreen, VineTheme.surfaceBackground],
        ),
      ),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Center(
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  padding: hasPill
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                      : EdgeInsets.zero,
                  decoration: hasPill
                      ? BoxDecoration(
                          color: preset.background,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    label,
                    style: preset.font(
                      fontSize:
                          VideoEditorConstants.baseFontSize *
                          preset.fontScale *
                          0.62,
                      color: preset.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maps the loop position (0..1) to a held 0..1 ramp: the animation plays
  /// over its own duration, then holds fully-entered until the loop restarts.
  double _holdProgress(double value, int durationMs) {
    final ratio = (durationMs.clamp(0, loopMs)) / loopMs;
    final start = (1 - ratio) / 2;
    final end = start + ratio;
    if (ratio <= 0 || value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }
}
