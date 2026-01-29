// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
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
    // TODO(@hm21): Update after new final snackbar-design is implemented.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        shape: RoundedRectangleBorder(borderRadius: .circular(16)),
        clipBehavior: .hardEdge,
        content: Text(
          message,
          style: VineTheme.bodyFont(
            fontSize: 14,
            fontWeight: .w600,
            height: 1.43,
            letterSpacing: 0.1,
            color: isError ? const Color(0xFFF44336) : VineTheme.whiteText,
          ),
        ),
        duration: Duration(seconds: isError ? 3 : 2),
        backgroundColor: isError
            ? const Color(0xFF410001)
            : const Color(0xFF000A06),
        behavior: .floating,
        margin: const .fromLTRB(16, 0, 16, 68),
      ),
    );
  }

  /// Show more options menu
  Future<void> _showMoreOptions(BuildContext context, WidgetRef ref) async {
    final clipManager = ref.read(
      clipManagerProvider.select(
        (p) => (hasClips: p.hasClips, clipCount: p.clipCount),
      ),
    );
    final clipsNotifier = ref.read(clipManagerProvider.notifier);

    VineBottomSheetActionMenu.show(
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
                  clipsNotifier.removeLastClip();
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
                  clipsNotifier.clearAll();
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(context: context, message: 'All clips cleared');
                }
              : null,
          isDestructive: true,
        ),
      ],
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
                  onPressed: () => _showMoreOptions(context, ref),
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
