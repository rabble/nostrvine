import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

class VideoRecorderClassicActionsBottom extends ConsumerWidget {
  const VideoRecorderClassicActionsBottom({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final isRecording = ref.watch(
      videoRecorderProvider.select((p) => p.isRecording),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isRecording ? 0 : 1,
      child: Row(
        spacing: 24,
        mainAxisAlignment: .center,
        children: [
          DivineIconButton(
            icon: .arrowsCounterClockwise,
            semanticLabel: context.l10n.videoRecorderSwitchCameraLabel,
            size: .small,
            type: .ghostSecondary,
            onPressed: notifier.switchCamera,
          ),
          DivineIconButton(
            icon: .gridNine,
            semanticLabel: context.l10n.videoRecorderToggleGridLabel,
            size: .small,
            type: .ghostSecondary,
            onPressed: notifier.toggleGridLines,
          ),
          DivineIconButton(
            icon: .ghost,
            semanticLabel: context.l10n.videoRecorderToggleGhostFrameLabel,
            size: .small,
            type: .ghostSecondary,
            onPressed: () {
              notifier.toggleShowLastClipOverlay();
              final enabled = ref
                  .read(videoRecorderProvider)
                  .showLastClipOverlay;
              _showSnackBar(
                context,
                enabled
                    ? context.l10n.videoRecorderGhostFrameEnabled
                    : context.l10n.videoRecorderGhostFrameDisabled,
              );
            },
          ),
        ],
      ),
    );
  }
}
