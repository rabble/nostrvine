import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/clip_delete_snackbar.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_actions.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_zoom_indicator.dart';

/// Bottom inset that lifts the zoom ruler clear of the record button:
/// the 96px button plus its 24px bottom padding plus a 12px gap.
const double _zoomIndicatorBottomInset = 24.0 + 96.0 + 12.0;

/// Capture-mode stack with viewfinder, controls, and top bar.
class VideoRecorderCaptureStack extends ConsumerWidget {
  const VideoRecorderCaptureStack({
    required this.fromEditor,
    this.topBarCenter,
    this.audioProgressBar,
    this.recordButton = const RecordButton(),
    super.key,
  });

  /// Whether the recorder was opened from the video editor.
  final bool fromEditor;

  /// Optional widget rendered in the top bar between the close and next
  /// buttons. Lip-sync mode uses this slot for the audio-select chip.
  final Widget? topBarCenter;

  /// Optional waveform progress bar overlaid during recording. Lip-sync mode
  /// supplies [VideoRecorderAudioProgressBar]; when set, the top bar's generic
  /// recording-progress bar is suppressed so the two don't overlap.
  final Widget? audioProgressBar;

  /// The record button rendered at the bottom center. Defaults to the standard
  /// [RecordButton]; lip-sync mode supplies one gated on audio selection.
  final Widget recordButton;

  void _deleteLastClip(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(clipManagerProvider.notifier).scheduleDeleteLastClip());
    showClipDeleteSnackbar(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    final isRecording = context.select(
      (VideoRecorderBloc b) => b.state.isRecording,
    );

    return SafeArea(
      bottom: false,
      child: Stack(
        fit: .expand,
        children: [
          // Camera preview (includes ghost frame)
          const ClipRRect(
            clipBehavior: .hardEdge,
            borderRadius: .vertical(bottom: .circular(32)),
            child: VideoRecorderCameraPreview(),
          ),

          // Action buttons
          const Align(
            alignment: .centerRight,
            child: VideoRecorderCaptureActions(),
          ),

          // Zoom ruler — floats above the record button and only appears
          // while the user is pinch-zooming.
          const Align(
            alignment: .bottomCenter,
            child: Padding(
              padding: .fromLTRB(20, 0, 20, _zoomIndicatorBottomInset),
              child: VideoRecorderZoomIndicator(),
            ),
          ),

          /// Record button
          Align(
            alignment: .bottomCenter,
            child: Padding(
              padding: const .fromLTRB(20, 0, 20, 24),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: hasClips && !isRecording && !fromEditor ? 1 : 0,
                    child: DivineIconButton(
                      icon: .trash,
                      semanticLabel:
                          context.l10n.videoRecorderDeleteLastClipLabel,
                      type: .ghostSecondary,
                      size: .small,
                      onPressed: () => _deleteLastClip(context, ref),
                    ),
                  ),

                  recordButton,

                  /// Dummy placeholder button
                  const Opacity(
                    opacity: 0,
                    child: IgnorePointer(
                      child: DivineIconButton(
                        icon: .trash,
                        type: .ghostSecondary,
                        size: .small,
                        onPressed: null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Waveform progress bar overlaid during recording (lip-sync mode).
          ?audioProgressBar,

          // Top bar with close-button and confirm-button
          Align(
            alignment: .topCenter,
            child: VideoRecorderCaptureTopBar(
              fromEditor: fromEditor,
              center: topBarCenter,
              showRecordingProgress: audioProgressBar == null,
            ),
          ),

          // Countdown overlay
          const VideoRecorderCountdownOverlay(),
        ],
      ),
    );
  }
}
