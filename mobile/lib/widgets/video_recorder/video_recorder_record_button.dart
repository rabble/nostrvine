import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/shutter_gesture_detector.dart';

/// Circular record button for starting/stopping video recording.
class RecordButton extends ConsumerWidget {
  const RecordButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        timerDuration: b.state.timerDuration,
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

    final isLongPressSupported = state.timerDuration == .off;
    final isEnabled =
        (state.canRecord &&
            state.isCameraInitialized &&
            (hasRemainingDuration || !state.recorderMode.hasRecordingLimit)) ||
        state.isRecording;

    return Semantics(
      identifier: 'divine-camera-record-button',
      button: true,
      enabled: isEnabled,
      tooltip: state.isRecording
          ? context.l10n.videoRecorderStopRecordingTooltip
          : context.l10n.videoRecorderStartRecordingTooltip,
      child: ShutterGestureDetector(
        isEnabled: isEnabled,
        isRecording: state.isRecording,
        isLongPressSupported: isLongPressSupported,
        onTapToggle: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRecordingToggleRequested(),
        ),
        onLongPressStartRecording: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRecordingStartRequested(),
        ),
        onLongPressStopRecording: () => context.read<VideoRecorderBloc>().add(
          const VideoRecorderRecordingStopRequested(),
        ),
        onLongPressMoveUpdate: state.isRecording && isLongPressSupported
            ? (details) => context.read<VideoRecorderBloc>().add(
                VideoRecorderZoomedByLongPress(details.localOffsetFromOrigin),
              )
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isEnabled ? 1.0 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              border: .all(
                color: state.isRecording
                    ? VineTheme.error
                    : VineTheme.whiteText,
                width: 4,
              ),
              borderRadius: .circular(36),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: state.isRecording ? 32 : 64,
                height: state.isRecording ? 32 : 64,
                decoration: ShapeDecoration(
                  color: VineTheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: .circular(state.isRecording ? 6 : 20),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: VineTheme.innerShadow,
                      blurRadius: 1,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
