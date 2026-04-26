import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';

/// Result returned when the user confirms the audio adjust sheet.
typedef AudioAdjustResult = ({double recordedVolume, double customVolume});

class VideoEditorAudioAdjustSheet extends StatefulWidget {
  const VideoEditorAudioAdjustSheet({
    super.key,
    this.initialRecordedVolume = 1,
    this.initialCustomVolume = 1,
    this.onRecordedVolumeChanged,
    this.onCustomVolumeChanged,
  });

  final double initialRecordedVolume;
  final double initialCustomVolume;

  /// Called on every slider drag for live preview of original audio volume.
  final ValueChanged<double>? onRecordedVolumeChanged;

  /// Called on every slider drag for live preview of custom audio volume.
  final ValueChanged<double>? onCustomVolumeChanged;

  @override
  State<VideoEditorAudioAdjustSheet> createState() =>
      _VideoEditorAudioAdjustSheetState();
}

class _VideoEditorAudioAdjustSheetState
    extends State<VideoEditorAudioAdjustSheet> {
  late final ValueNotifier<double> _recordedVolume;
  late final ValueNotifier<double> _customVolume;

  @override
  void initState() {
    super.initState();
    _recordedVolume = ValueNotifier(widget.initialRecordedVolume)
      ..addListener(_onRecordedVolumeChanged);
    _customVolume = ValueNotifier(widget.initialCustomVolume)
      ..addListener(_onCustomVolumeChanged);
  }

  void _onRecordedVolumeChanged() {
    widget.onRecordedVolumeChanged?.call(_recordedVolume.value);
  }

  void _onCustomVolumeChanged() {
    widget.onCustomVolumeChanged?.call(_customVolume.value);
  }

  @override
  void dispose() {
    _recordedVolume
      ..removeListener(_onRecordedVolumeChanged)
      ..dispose();
    _customVolume
      ..removeListener(_onCustomVolumeChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const .all(16),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            spacing: 8,
            children: [
              DivineIconButton(
                icon: .x,
                type: .secondary,
                size: .small,
                onPressed: () => context.pop<AudioAdjustResult>(),
              ),
              Flexible(
                child: Text(
                  context.l10n.videoEditorAdjustVolumeTitle,
                  style: VineTheme.titleMediumFont(),
                ),
              ),
              DivineIconButton(
                icon: .check,
                size: .small,
                onPressed: () => context.pop((
                  recordedVolume: _recordedVolume.value,
                  customVolume: _customVolume.value,
                )),
              ),
            ],
          ),
        ),
        const Divider(
          height: 2,
          thickness: 2,
          color: VineTheme.outlinedDisabled,
        ),
        const SizedBox(height: 16),
        _ControlBar(
          label: context.l10n.videoEditorRecordedAudioLabel,
          volume: _recordedVolume,
        ),
        const SizedBox(height: 24),
        _ControlBar(
          label: context.l10n.videoEditorCustomAudioLabel,
          volume: _customVolume,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.label, required this.volume});

  final String label;
  final ValueNotifier<double> volume;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: volume,
            builder: (_, value, _) =>
                _VolumeRow(label: label, value: '${(value * 100).round()}%'),
          ),
          ValueListenableBuilder<double>(
            valueListenable: volume,
            builder: (_, value, _) =>
                DivineSlider(value: value, onChanged: (v) => volume.value = v),
          ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Flexible(child: Text(label, style: VineTheme.labelLargeFont())),
        Flexible(child: Text(value, style: VineTheme.labelLargeFont())),
      ],
    );
  }
}
