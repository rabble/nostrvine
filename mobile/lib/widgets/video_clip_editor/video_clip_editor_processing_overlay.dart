// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/core/models/video/progress_model.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

class VideoClipEditorProcessingOverlay extends StatelessWidget {
  const VideoClipEditorProcessingOverlay({
    required this.clip,
    super.key,
    this.inactivePlaceholder,
    this.isCurrentClip = false,
    this.isProcessing = false,
  });

  /// The clip to show processing status for.
  final RecordingClip clip;
  final bool isProcessing;
  final bool isCurrentClip;
  final Widget? inactivePlaceholder;

  @override
  Widget build(BuildContext context) {
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
                    stream: ProVideoEditor.instance.progressStreamById(clip.id),
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
