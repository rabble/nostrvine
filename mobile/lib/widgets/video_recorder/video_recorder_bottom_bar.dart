// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, sound, camera flip, more options, and selected sound indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Bottom bar with record button and camera controls.
class VideoRecorderBottomBar extends ConsumerWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({super.key});

  /// Shows a styled snackbar with the given message.
  void _showSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: .floating,
        margin: const .fromLTRB(16, 0, 16, 68),
        duration: Duration(seconds: isError ? 3 : 2),
        content: DivineSnackbarContainer(label: message, error: isError),
      ),
    );
  }

  /// Show more options menu
  Future<void> _showMoreOptions(
    BuildContext context,
    WidgetRef ref,
    VideoRecorderNotifier videoRecorderNotifier,
  ) async {
    final clipManager = ref.read(
      clipManagerProvider.select(
        (p) => (hasClips: p.hasClips, clipCount: p.clipCount),
      ),
    );
    final clipsNotifier = ref.read(clipManagerProvider.notifier);

    videoRecorderNotifier.pauseRemoteRecordControl();

    await VineBottomSheetActionMenu.show(
      context: context,
      options: [
        VineBottomSheetActionData(
          iconPath: 'assets/icon/save.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: clipManager.clipCount > 1
              ? 'Save clips to Library'
              : 'Save clip to Library',
          onTap: clipManager.hasClips
              ? () async {
                  final success = await clipsNotifier.saveClipsToLibrary();
                  if (!context.mounted) return;
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(
                    context: context,
                    message: success
                        ? 'Clips saved to library'
                        : 'Failed to save clips',
                    isError: !success,
                  );
                }
              : null,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/undo.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Remove last clip',
          onTap: clipManager.hasClips
              ? () {
                  unawaited(clipsNotifier.removeLastClip());
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(context: context, message: 'Clip removed');
                }
              : null,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/trash.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Clear all clips',
          onTap: clipManager.hasClips
              ? () {
                  unawaited(clipsNotifier.clearAll());
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(context: context, message: 'All clips cleared');
                }
              : null,
          isDestructive: true,
        ),
      ],
    );

    videoRecorderNotifier.resumeRemoteRecordControl();
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
          padding: const EdgeInsets.only(bottom: 4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: state.isRecording ? 0 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Flash toggle
                _ActionButton(
                  icon: state.flashMode.icon,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Toggle flash',
                  onPressed: state.hasFlash ? notifier.toggleFlash : null,
                ),

                // Timer toggle
                _ActionButton(
                  icon: state.timer.icon,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Cycle timer',
                  onPressed: notifier.cycleTimer,
                ),

                // Aspect-Ratio
                _ActionButton(
                  icon: state.aspectRatio == .square
                      ? .cropSquare
                      : .cropPortrait,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Toggle aspect ratio',
                  onPressed: !hasClips ? notifier.toggleAspectRatio : null,
                ),

                // Flip camera
                _ActionButton(
                  icon: .arrowsClockwise,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'Switch camera',
                  onPressed: state.canSwitchCamera
                      ? notifier.switchCamera
                      : null,
                ),

                // More options
                _ActionButton(
                  icon: .moreHoriz,
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  tooltip: 'More options',
                  onPressed: () => _showMoreOptions(context, ref, notifier),
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
    required this.icon,
  });
  final VoidCallback? onPressed;
  final String tooltip;
  final DivineIconName icon;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: DivineIcon(
        icon: icon,
        size: 32,
        color: VineTheme.whiteText.withAlpha(isEnabled ? 255 : 80),
      ),
    );
  }
}
