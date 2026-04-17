import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

class VideoRecorderClassicActionsTop extends ConsumerWidget {
  const VideoRecorderClassicActionsTop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(
      videoRecorderProvider.select((p) => p.isRecording),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: isRecording || !hasClips ? 0 : 1,
      child: Row(
        mainAxisAlignment: .center,
        children: [
          DivineIconButton(
            icon: .arrowCounterClockwise,
            semanticLabel: context.l10n.videoRecorderDeleteLastClipLabel,
            size: .small,
            type: .ghostSecondary,
            onPressed: ref
                .read(clipManagerProvider.notifier)
                .deleteLastRecordedClip,
          ),
        ],
      ),
    );
  }
}
