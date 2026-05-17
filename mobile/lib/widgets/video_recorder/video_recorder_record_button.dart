import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/shutter_long_press_mixin.dart';

/// Circular record button for starting/stopping video recording.
class RecordButton extends ConsumerStatefulWidget {
  const RecordButton({super.key});

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton>
    with ShutterLongPressMixin {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (
          isRecording: p.isRecording,
          timerDuration: p.timerDuration,
          canRecord: p.canRecord,
          isCameraInitialized: p.isCameraInitialized,
          recorderMode: p.recorderMode,
        ),
      ),
    );

    final hasRemainingDuration = ref.watch(
      clipManagerProvider.select(
        (p) => p.remainingDuration > const Duration(milliseconds: 30),
      ),
    );

    final notifier = ref.read(videoRecorderProvider.notifier);

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
      child: GestureDetector(
        onTap: isEnabled
            ? () => handleShutterTap(notifier.toggleRecording)
            : null,
        onLongPressStart: isEnabled && isLongPressSupported
            ? (_) => handleShutterLongPressStart(
                isRecording: state.isRecording,
                start: notifier.startRecording,
              )
            : null,
        onLongPressMoveUpdate: state.isRecording && isLongPressSupported
            ? (details) =>
                  notifier.zoomByLongPressMove(details.localOffsetFromOrigin)
            : null,
        onLongPressUp: isLongPressSupported
            ? () => handleShutterLongPressUp(notifier.stopRecording)
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
