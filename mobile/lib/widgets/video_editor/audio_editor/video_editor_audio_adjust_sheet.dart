import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VideoEditorAudioAdjustSheet extends StatelessWidget {
  const VideoEditorAudioAdjustSheet({super.key});

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
                onPressed: context.pop,
              ),
              Flexible(
                child: Text(
                  'Adjust volume',
                  style: VineTheme.titleMediumFont(),
                ),
              ),
              DivineIconButton(
                icon: .check,
                size: .small,
                onPressed: () {},
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

        const _ControlBar(label: 'Recorded audio', value: '95%'),
        const SizedBox(height: 24),

        const _ControlBar(label: 'Custom audio', value: '95%'),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          _VolumeRow(label: label, value: value),
          const Placeholder(
            fallbackHeight: 40,
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
        Flexible(
          child: Text(label, style: VineTheme.labelLargeFont()),
        ),
        Flexible(
          child: Text(value, style: VineTheme.labelLargeFont()),
        ),
      ],
    );
  }
}
