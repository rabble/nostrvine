import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

/// Horizontal pill-style mode selector for the video recorder.
///
/// Matches the Figma design: selected mode gets a dark green pill background
/// with primary green text; unselected modes are text-only at 75% opacity.
class VideoRecorderModeSelectorWheel extends StatelessWidget {
  const VideoRecorderModeSelectorWheel({
    required this.selectedMode,
    required this.onModeChanged,
    super.key,
  });

  final VideoRecorderMode selectedMode;
  final ValueChanged<VideoRecorderMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: VideoRecorderMode.values
            .map(
              (mode) => _ModeTag(
                mode: mode,
                isSelected: mode == selectedMode,
                onTap: () {
                  if (mode != selectedMode) {
                    HapticFeedback.selectionClick();
                    onModeChanged(mode);
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final VideoRecorderMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: mode.label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? VineTheme.containerLow : VineTheme.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            mode.label,
            style: VineTheme.titleSmallFont(
              color: isSelected
                  ? VineTheme.primary
                  : VineTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
