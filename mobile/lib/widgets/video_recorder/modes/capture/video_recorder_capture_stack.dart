import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_actions.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_record_button.dart';

class VideoRecorderCaptureStack extends ConsumerWidget {
  const VideoRecorderCaptureStack({super.key});

  void _deleteLastClip(
    BuildContext context,
    WidgetRef ref,
  ) {
    final clipsNotifier = ref.read(clipManagerProvider.notifier);
    unawaited(clipsNotifier.deleteLastRecordedClip());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        behavior: .floating,
        margin: const .fromLTRB(16, 0, 16, 68),
        content: DivineSnackbarContainer(
          label: context.l10n.videoRecorderClipDeletedMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    final isRecording = ref.watch(
      videoRecorderProvider.select((p) => p.isRecording),
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
                    opacity: hasClips && !isRecording ? 1 : 0,
                    child: DivineIconButton(
                      icon: .arrowCounterClockwise,
                      semanticLabel:
                          context.l10n.videoRecorderDeleteLastClipLabel,
                      type: .ghostSecondary,
                      size: .small,
                      onPressed: () => _deleteLastClip(context, ref),
                    ),
                  ),

                  const RecordButton(),

                  /// Dummy placeholder button
                  const Opacity(
                    opacity: 0,
                    child: IgnorePointer(
                      child: DivineIconButton(
                        icon: .arrowCounterClockwise,
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

          // Top bar with close-button and confirm-button
          const Align(
            alignment: .topCenter,
            child: VideoRecorderCaptureTopBar(),
          ),

          // Countdown overlay
          const VideoRecorderCountdownOverlay(),
        ],
      ),
    );
  }
}
