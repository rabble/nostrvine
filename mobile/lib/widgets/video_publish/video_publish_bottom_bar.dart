// ABOUTME: Bottom control bar for video publish screen
// ABOUTME: Contains play/pause, mute buttons and time display

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_editor/video_time_display.dart';

/// Bottom control bar with playback controls and time display.
class VideoPublishBottomBar extends ConsumerWidget {
  /// Creates a video publish bottom bar.
  const VideoPublishBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the fields that affect the controls (less frequent updates)
    final state = ref.watch(
      videoPublishProvider.select(
        (s) => (
          isPlaying: s.isPlaying,
          totalDuration: s.totalDuration,
          isMuted: s.isMuted,
        ),
      ),
    );

    final notifier = ref.read(videoPublishProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left controls
            Row(
              spacing: 16,
              children: [
                // Pause/Play button
                DivineIconButton(
                  iconPath: state.isPlaying
                      ? 'assets/icon/pause.svg'
                      : 'assets/icon/play.svg',
                  onTap: notifier.togglePlayPause,
                  semanticLabel: 'Play or pause video',
                ),
                // Mute button
                DivineIconButton(
                  iconPath: state.isMuted
                      ? 'assets/icon/volume_off.svg'
                      : 'assets/icon/volume_on.svg',
                  onTap: notifier.toggleMute,
                  semanticLabel: 'Mute or unmute audio',
                ),
              ],
            ),
            // Time display
            VideoTimeDisplay(
              isPlayingSelector: videoPublishProvider.select(
                (s) => s.isPlaying,
              ),
              currentPositionSelector: videoPublishProvider.select(
                (s) => s.currentPosition,
              ),
              totalDuration: state.totalDuration,
            ),
          ],
        ),
      ),
    );
  }
}
