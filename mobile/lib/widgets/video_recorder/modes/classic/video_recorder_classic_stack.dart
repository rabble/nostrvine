import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_bottom.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_actions_top.dart';
import 'package:openvine/widgets/video_recorder/modes/classic/video_recorder_classic_top_bar.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';

class VideoRecorderClassicStack extends ConsumerWidget {
  const VideoRecorderClassicStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      label:
                          ref.watch(
                            videoRecorderProvider.select((s) => s.isRecording),
                          )
                          ? context.l10n.videoRecorderRecordingTapToStopLabel
                          : context.l10n.videoRecorderTapToStartLabel,
                      child: GestureDetector(
                        behavior: .opaque,
                        onTap: ref
                            .read(videoRecorderProvider.notifier)
                            .toggleRecording,
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
