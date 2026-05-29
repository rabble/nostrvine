import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/shutter_gesture_detector.dart';

class VideoRecorderClassicStack extends ConsumerWidget {
  const VideoRecorderClassicStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        canRecord: b.state.canRecord,
        isCameraInitialized: b.state.isCameraInitialized,
        recorderMode: b.state.recorderMode,
      ),
    );

    final hasRemainingDuration = ref.watch(
      clipManagerProvider.select(
        (p) => p.remainingDuration > const Duration(milliseconds: 30),
      ),
    );

    final isEnabled =
        (state.canRecord &&
            state.isCameraInitialized &&
            (hasRemainingDuration || !state.recorderMode.hasRecordingLimit)) ||
        state.isRecording;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const VideoRecorderClassicTopBar(),

          Expanded(
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              spacing: 30,
              children: [
                const VideoRecorderClassicActionsTop(),

                // Camera preview (includes ghost frame)
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      button: true,
                      liveRegion: true,
                      label: state.isRecording
                          ? context.l10n.videoRecorderRecordingTapToStopLabel
                          : context.l10n.videoRecorderTapToStartLabel,
                      child: ShutterGestureDetector(
                        isEnabled: isEnabled,
                        isRecording: state.isRecording,
                        behavior: .opaque,
                        onTapToggle: () => context
                            .read<VideoRecorderBloc>()
                            .add(const VideoRecorderRecordingToggleRequested()),
                        onLongPressStartRecording: () => context
                            .read<VideoRecorderBloc>()
                            .add(const VideoRecorderRecordingStartRequested()),
                        onLongPressStopRecording: () => context
                            .read<VideoRecorderBloc>()
                            .add(const VideoRecorderRecordingStopRequested()),
                        child: const IgnorePointer(
                          child: VideoRecorderCameraPreview(
                            enableTapToFocus: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const VideoRecorderClassicActionsBottom(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
