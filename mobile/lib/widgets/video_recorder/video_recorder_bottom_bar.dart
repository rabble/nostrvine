// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, sound, camera flip, more options, and selected sound indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

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
        backgroundColor: VineTheme.transparent,
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
    final hasClips = clipManager.hasClips;
    final color = hasClips ? VineTheme.whiteText : VineTheme.onSurfaceDisabled;
    final destructiveColor = hasClips
        ? VineTheme.error
        : VineTheme.onSurfaceDisabled;

    videoRecorderNotifier.pauseRemoteRecordControl();

    final recorderNotifier = ref.read(videoRecorderProvider.notifier);

    await VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      children: [
        Consumer(
          builder: (context, ref, child) {
            final showLastClipOverlay = ref.watch(
              videoRecorderProvider.select((p) => p.showLastClipOverlay),
            );

            return SwitchListTile(
              value: showLastClipOverlay,
              onChanged: (_) => recorderNotifier.toggleShowLastClipOverlay(),
              title: Text(
                // TODO(l10n): Replace with context.l10n when localization is added.
                'Show last clip overlay',
                style: VineTheme.titleMediumFont(),
                maxLines: 2,
                overflow: .ellipsis,
              ),
              secondary: const DivineIcon(icon: .userFocus),
            );
          },
        ),
        ListTile(
          enabled: hasClips,
          minTileHeight: 56,
          leading: DivineIcon(icon: .save, color: color),
          title: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            clipManager.clipCount > 1
                ? 'Save clips to Library'
                : 'Save clip to Library',
            style: VineTheme.titleMediumFont(color: color),
            maxLines: 1,
            overflow: .ellipsis,
          ),
          onTap: hasClips
              ? () async {
                  final success = await clipsNotifier.saveClipsToLibrary();
                  if (!context.mounted) return;
                  context.pop();
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
        ListTile(
          enabled: hasClips,
          minTileHeight: 56,
          leading: DivineIcon(icon: .trash, color: destructiveColor),
          title: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Clear all clips',
            style: VineTheme.titleMediumFont(color: destructiveColor),
            maxLines: 1,
            overflow: .ellipsis,
          ),
          onTap: hasClips
              ? () {
                  context.pop();
                  unawaited(clipsNotifier.clearAll());
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  _showSnackBar(context: context, message: 'All clips cleared');
                }
              : null,
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
          isRecording: p.isRecording,
          recorderMode: p.recorderMode,
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: state.isRecording ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Stack(
            children: [
              const Align(
                alignment: .centerLeft,
                child: VideoRecorderLibraryButton(),
              ),
              Align(
                alignment: .center,
                child: VideoRecorderModeSelectorWheel(
                  selectedMode: state.recorderMode,
                  onModeChanged: notifier.setRecorderMode,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
