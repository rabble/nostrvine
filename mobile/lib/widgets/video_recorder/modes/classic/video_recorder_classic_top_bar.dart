import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

class VideoRecorderClassicTopBar extends ConsumerWidget {
  const VideoRecorderClassicTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    return Padding(
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
            onPressed: () => notifier.openVideoEditor(context),
          ),
        ],
      ),
    );
  }
}
