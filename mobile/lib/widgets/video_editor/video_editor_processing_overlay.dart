// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class VideoEditorProcessingOverlay extends StatelessWidget {
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
                child: Column(
                  mainAxisSize: .min,
                  spacing: 12,
                  children: [
                    const BrandedLoadingIndicator(size: 44),

                    // Without RepaintBoundary, the progress indicator repaints
                    // the entire screen while it's running.
                    RepaintBoundary(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final progress =
                              (ref
                                          .watch(
                                            videoEditorCompositeProgressProvider,
                                          )
                                          .asData
                                          ?.value
                                          .progress ??
                                      0)
                                  .clamp(0.0, 1.0);
                          return PartialCircleSpinner(progress: progress);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : inactivePlaceholder ?? const SizedBox.shrink(),
    );
  }
}
