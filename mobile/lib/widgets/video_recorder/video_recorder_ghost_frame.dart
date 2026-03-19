import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Semi-transparent overlay of the last recorded clip's final frame.
///
/// Helps the user align the next shot with the previous one.
/// Uses [AnimatedSwitcher] for smooth fade transitions when the ghost
/// frame changes or disappears.
class VideoRecorderGhostFrame extends ConsumerWidget {
  /// Creates a video recorder ghost frame widget.
  const VideoRecorderGhostFrame({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOverlay = ref.watch(
      videoRecorderProvider.select((p) => p.showLastClipOverlay),
    );

    // Use the last clip that has a ghost frame, not just the last clip.
    // This prevents the overlay from disappearing while recording a new
    // clip that doesn't have a ghost frame yet.
    final ghostFramePath = ref.watch(
      clipManagerProvider.select((s) {
        for (var i = s.clips.length - 1; i >= 0; i--) {
          final path = s.clips[i].ghostFramePath;
          if (path != null) return path;
        }
        return null;
      }),
    );

    final showGhost = showOverlay && ghostFramePath != null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: showGhost
          ? IgnorePointer(
              key: ValueKey(ghostFramePath),
              child: Opacity(
                opacity: 0.48,
                child: Image.file(
                  File(ghostFramePath),
                  fit: .cover,
                  width: .infinity,
                  height: .infinity,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
