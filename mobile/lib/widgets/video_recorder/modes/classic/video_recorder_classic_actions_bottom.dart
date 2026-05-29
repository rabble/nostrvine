import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

class VideoRecorderClassicActionsBottom extends StatelessWidget {
  const VideoRecorderClassicActionsBottom({super.key});

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = context.select(
      (VideoRecorderBloc b) => b.state.isRecording,
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
            onPressed: () => context.read<VideoRecorderBloc>().add(
              const VideoRecorderCameraSwitched(),
            ),
          ),
          DivineIconButton(
            icon: .gridNine,
            semanticLabel: context.l10n.videoRecorderToggleGridLabel,
            size: .small,
            type: .ghostSecondary,
            onPressed: () => context.read<VideoRecorderBloc>().add(
              const VideoRecorderGridLinesToggled(),
            ),
          ),
          DivineIconButton(
            icon: .ghost,
            semanticLabel: context.l10n.videoRecorderToggleGhostFrameLabel,
            size: .small,
            type: .ghostSecondary,
            onPressed: () {
              final enabled = !context
                  .read<VideoRecorderBloc>()
                  .state
                  .showLastClipOverlay;
              context.read<VideoRecorderBloc>().add(
                const VideoRecorderShowLastClipOverlayToggled(),
              );
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
