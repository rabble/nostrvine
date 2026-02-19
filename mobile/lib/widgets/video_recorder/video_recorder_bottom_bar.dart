// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, sound, camera flip, more options, and selected sound indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/sounds_screen.dart';

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

  /// Opens the sounds screen for sound selection.
  void _openSoundsScreen(
    BuildContext context,
    VideoRecorderNotifier videoRecorderNotifier,
  ) async {
    videoRecorderNotifier.pauseRemoteRecordControl();

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SoundsScreen()));

    videoRecorderNotifier.resumeRemoteRecordControl();
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
    final selectedSound = ref.watch(selectedSoundProvider);

    return SafeArea(
      top: false,
      child: IgnorePointer(
        ignoring: state.isRecording,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: state.isRecording ? 0 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected sound indicator
                if (selectedSound != null)
                  _SelectedSoundChip(sound: selectedSound),

                // Controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Flash toggle
                    _ActionButton(
                      iconPath: state.flashMode.iconPath,
                      // TODO(l10n): Replace with context.l10n
                      // when localization is added.
                      tooltip: 'Toggle flash',
                      onPressed: state.hasFlash ? notifier.toggleFlash : null,
                    ),

                    // Timer toggle
                    _ActionButton(
                      iconPath: state.timer.iconPath,
                      // TODO(l10n): Replace with context.l10n
                      // when localization is added.
                      tooltip: 'Cycle timer',
                      onPressed: notifier.cycleTimer,
                    ),

                    // Aspect-Ratio
                    _ActionButton(
                      iconPath: state.aspectRatio == .square
                          ? 'assets/icon/crop_square.svg'
                          : 'assets/icon/crop_portrait.svg',
                      // TODO(l10n): Replace with context.l10n
                      // when localization is added.
                      tooltip: 'Toggle aspect ratio',
                      onPressed: !hasClips ? notifier.toggleAspectRatio : null,
                    ),

                    // Sound selection
                    _ActionButton(
                      iconPath: 'assets/icon/music_note.svg',
                      // TODO(l10n): Replace with context.l10n
                      // when localization is added.
                      tooltip: 'Select sound',
                      onPressed: () => _openSoundsScreen(context, notifier),
                      hasIndicator: selectedSound != null,
                    ),

                    // Flip camera
                    _ActionButton(
                      iconPath: 'assets/icon/refresh.svg',
                      // TODO(l10n): Replace with context.l10n
                      // when localization is added.
                      tooltip: 'Switch camera',
                      onPressed: state.canSwitchCamera
                          ? notifier.switchCamera
                          : null,
                    ),

                    // More options
                    _ActionButton(
                      iconPath: 'assets/icon/more_horiz.svg',
                      // TODO(l10n): Replace with context.l10n
                      // when localization is added.
                      tooltip: 'More options',
                      onPressed: () => _showMoreOptions(context, ref, notifier),
                    ),
                  ],
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
    this.hasIndicator = false,
  });
  final VoidCallback? onPressed;
  final String tooltip;
  final String iconPath;
  final bool hasIndicator;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: 32,
            width: 32,
            child: SvgPicture.asset(
              iconPath,
              colorFilter: ColorFilter.mode(
                Color.fromRGBO(255, 255, 255, isEnabled ? 1.0 : 0.3),
                BlendMode.srcIn,
              ),
            ),
          ),
          if (hasIndicator)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: VineTheme.vineGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedSoundChip extends ConsumerWidget {
  const _SelectedSoundChip({required this.sound});

  final AudioEvent sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = sound.title ?? 'Selected sound';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icon/music_note.svg',
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                VineTheme.vineGreen,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                title,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => ref.read(selectedSoundProvider.notifier).clear(),
              child: const Icon(
                Icons.close,
                size: 14,
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
