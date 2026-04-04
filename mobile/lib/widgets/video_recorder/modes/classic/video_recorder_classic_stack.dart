import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';

class VideoRecorderClassicStack extends ConsumerWidget {
  const VideoRecorderClassicStack({super.key});

  static const _animationDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final isRecording = ref.watch(
      videoRecorderProvider.select((p) => p.isRecording),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const .all(16),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                DivineIconButton(
                  icon: .x,
                  size: .small,
                  type: .ghostSecondary,
                  onPressed: () => notifier.closeVideoRecorder(context),
                ),
                DivineIconButton(
                  icon: .caretRight,
                  size: .small,
                  type: .ghostSecondary,
                  // FIXME: navigate directly to metadata screen
                  onPressed: () => notifier.openVideoEditor(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              spacing: 30,
              children: [
                AnimatedOpacity(
                  duration: _animationDuration,
                  opacity: isRecording || !hasClips ? 0 : 1,
                  child: Row(
                    mainAxisAlignment: .center,
                    children: [
                      DivineIconButton(
                        icon: .arrowCounterClockwise,
                        size: .small,
                        type: .ghostSecondary,
                        onPressed: ref
                            .read(clipManagerProvider.notifier)
                            .removeLastClip,
                      ),
                    ],
                  ),
                ),

                // Camera preview (includes ghost frame)
                GestureDetector(
                  behavior: .opaque,
                  onTap: notifier.toggleRecording,
                  child: const IgnorePointer(
                    child: VideoRecorderCameraPreview(
                      enableGridLines: true,
                      enableTapToFocus: false,
                    ),
                  ),
                ),

                AnimatedOpacity(
                  duration: _animationDuration,
                  opacity: isRecording ? 0 : 1,
                  child: Row(
                    spacing: 24,
                    mainAxisAlignment: .center,
                    children: [
                      DivineIconButton(
                        icon: .arrowsCounterClockwise,
                        size: .small,
                        type: .ghostSecondary,
                        onPressed: notifier.switchCamera,
                      ),
                      // FIXME: add grid toggler
                      DivineIconButton(
                        icon: .arrowsCounterClockwise,
                        size: .small,
                        type: .ghostSecondary,
                        onPressed: notifier.switchCamera,
                      ),
                      // FIXME: add ghost frame
                      DivineIconButton(
                        icon: .arrowsCounterClockwise,
                        size: .small,
                        type: .ghostSecondary,
                        onPressed: notifier.toggleShowLastClipOverlay,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
