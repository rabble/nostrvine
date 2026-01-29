import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Circular record button for starting/stopping video recording.
class RecordButton extends ConsumerWidget {
  const RecordButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (isRecording: p.isRecording, timerDuration: p.timerDuration),
      ),
    );

    final notifier = ref.read(videoRecorderProvider.notifier);

    final isLongPressSupported = state.timerDuration == .off;

    return Align(
      alignment: .bottomCenter,
      child: Semantics(
        identifier: 'divine-camera-record-button',
        button: true,
        // TODO(l10n): Replace with context.l10n when localization is added.
        tooltip: state.isRecording ? 'Stop recording' : 'Start recording',
        child: GestureDetector(
          onTap: notifier.toggleRecording,
          onLongPressStart: isLongPressSupported
              ? (_) => notifier.startRecording()
              : null,
          onLongPressMoveUpdate: state.isRecording && isLongPressSupported
              ? (details) =>
                    notifier.zoomByLongPressMove(details.localOffsetFromOrigin)
              : null,
          onLongPressUp: isLongPressSupported ? notifier.stopRecording : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const .only(bottom: 20),
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              border: .all(color: Colors.white, width: 4),
              borderRadius: .circular(36),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: state.isRecording ? 32 : 64,
                height: state.isRecording ? 32 : 64,
                decoration: ShapeDecoration(
                  color: const Color(0xFFF44336),
                  shape: RoundedRectangleBorder(
                    borderRadius: .circular(state.isRecording ? 6 : 20),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x19000000),
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
