// ABOUTME: Top bar widget for video recorder screen
// ABOUTME: Contains close button, segment-bar, and forward button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';

/// Top bar with close button, segment bar, and forward button.
class VideoRecorderTopBar extends ConsumerWidget {
  /// Creates a video recorder top bar widget.
  const VideoRecorderTopBar({super.key});

  static const Color _buttonColor = Color(0xFF101111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final hasClips = ref.watch(clipManagerProvider.select((s) => s.hasClips));
    final isRecording = ref.watch(
      videoRecorderProvider.select((s) => s.isRecording),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const .all(16),
          child: Row(
            spacing: 16,
            children: [
              // Close button
              _buildActionButton(
                iconPath: 'assets/icon/close.svg',
                semanticLabel: 'Close video recorder',
                hidden: isRecording,
                backgroundColor: _buttonColor,
                onTap: () => notifier.closeVideoRecorder(context),
              ),

              // Segment bar
              const VideoRecorderSegmentBar(),

              // Confirm button
              _buildActionButton(
                iconPath: 'assets/icon/arrow_forward.svg',
                semanticLabel: 'Continue to video editor',
                hidden: isRecording,
                backgroundColor: hasClips
                    ? VineTheme.tabIndicatorGreen
                    : const Color(0xA6000000),
                iconColor: hasClips ? Colors.white : const Color(0xA4FFFFFF),
                onTap: hasClips
                    ? () => notifier.openVideoEditor(context)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build action button for top bar
  Widget _buildActionButton({
    required String iconPath,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    bool hidden = false,
    VoidCallback? onTap,
    String? semanticLabel,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: hidden ? 0 : 1,
      curve: Curves.ease,
      child: DivineIconButton(
        backgroundColor: backgroundColor,
        iconColor: iconColor,
        iconPath: iconPath,
        onTap: onTap,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
