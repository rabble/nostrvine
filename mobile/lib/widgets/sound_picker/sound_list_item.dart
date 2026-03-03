// ABOUTME: List item widget for sound selection with play/pause preview
// ABOUTME: Dark theme design with selection indicator and duration display

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/vine_sound.dart';

class SoundListItem extends StatelessWidget {
  const SoundListItem({
    required this.sound,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    super.key,
  });

  final VineSound sound;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isSelected
          ? VineTheme.success.withValues(alpha: 0.2)
          : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: isPlaying ? VineTheme.success : VineTheme.whiteText,
            size: 32,
          ),
          onPressed: onPlayPause,
        ),
        title: Text(
          sound.title,
          style: TextStyle(
            color: isSelected ? VineTheme.success : VineTheme.whiteText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          sound.artist ?? '${sound.durationInSeconds.round()}s',
          style: const TextStyle(color: VineTheme.lightText),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: VineTheme.success, size: 28)
            : Text(
                '${sound.durationInSeconds.round()}s',
                style: const TextStyle(color: VineTheme.lightText),
              ),
      ),
    );
  }
}
