// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_video_editor/core/models/video/progress_model.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

class VideoEditorProcessingOverlay extends ConsumerWidget {
  const VideoEditorProcessingOverlay({
    required this.clip,
    super.key,
    this.inactivePlaceholder,
    this.isCurrentClip = false,
    this.isProcessing = false,
  });

  /// The clip to show processing status for.
  final DivineVideoClip clip;
  final bool isProcessing;
  final bool isCurrentClip;
  final Widget? inactivePlaceholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // draftId is set once during initialization and does not change within a
    // session, so a one-time read is sufficient.
    final draftId = ref.read(videoEditorProvider.notifier).draftId;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: isProcessing || clip.isProcessing
          ? ColoredBox(
              key: ValueKey(
                'Processing-Clip-Overlay-${clip.id}-$isCurrentClip',
              ),
              color: const Color.fromARGB(180, 0, 0, 0),
              child: Center(
                // Without RepaintBoundary, the progress indicator repaints
                // the entire screen while it's running.
                child: RepaintBoundary(
                  child: StreamBuilder<ProgressModel>(
                    stream: ProVideoEditor.instance.progressStreamById(draftId),
                    builder: (context, snapshot) {
                      final progress = snapshot.data?.progress ?? 0;
                      return PartialCircleSpinner(progress: progress);
                    },
                  ),
                ),
              ),
            )
          : inactivePlaceholder ?? const SizedBox.shrink(),
    );
  }
}
