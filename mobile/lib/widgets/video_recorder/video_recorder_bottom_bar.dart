// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_more_sheet.dart';

/// Bottom bar with record button and camera controls.
class VideoRecorderBottomBar extends ConsumerWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({super.key});

  /// Show more options menu
  Future<void> _showMoreOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceBackground,
      builder: (_) => const VideoRecorderMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (
          flashMode: p.flashMode,
          timer: p.timerDuration,
          aspectRatio: p.aspectRatio,
          canSwitchCamera: p.canSwitchCamera,
          hasFlash: p.hasFlash,
          isRecording: p.isRecording,
        ),
      ),
    );

    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      top: false,
      child: IgnorePointer(
        ignoring: state.isRecording,
        child: Padding(
          padding: const .only(bottom: 4.0),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: state.isRecording ? 0 : 1,
            child: Row(
              mainAxisAlignment: .spaceAround,
              children: [
                // Flash toggle
                _ActionButton(
                  iconPath: state.flashMode.iconPath,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Toggle flash',
                  onPressed: state.hasFlash ? notifier.toggleFlash : null,
                ),

                // Timer toggle
                _ActionButton(
                  iconPath: state.timer.iconPath,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Cycle timer',
                  onPressed: notifier.cycleTimer,
                ),

                // Aspect-Ratio
                _ActionButton(
                  iconPath: state.aspectRatio == .square
                      ? 'assets/icon/crop_square.svg'
                      : 'assets/icon/crop_portrait.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Toggle aspect ratio',
                  onPressed: !hasClips ? notifier.toggleAspectRatio : null,
                ),

                // Flip camera
                _ActionButton(
                  iconPath: 'assets/icon/refresh.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Switch camera',
                  onPressed: state.canSwitchCamera
                      ? notifier.switchCamera
                      : null,
                ),

                // More options
                _ActionButton(
                  iconPath: 'assets/icon/more_horiz.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'More options',
                  onPressed: () => _showMoreOptions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.tooltip,
    required this.iconPath,
  });
  final VoidCallback? onPressed;
  final String tooltip;
  final String iconPath;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: SizedBox(
        height: 32,
        width: 32,
        child: SvgPicture.asset(
          iconPath,
          colorFilter: ColorFilter.mode(
            Color.fromRGBO(255, 255, 255, isEnabled ? 1.0 : 0.3),
            .srcIn,
          ),
        ),
      ),
    );
  }
}
