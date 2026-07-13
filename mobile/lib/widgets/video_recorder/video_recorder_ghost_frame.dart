import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

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
    final (showOverlay, capturesStills, stopMotionLastFrame) = context.select(
      (VideoRecorderBloc b) => (
        b.state.showLastClipOverlay,
        b.state.recorderMode.capturesStills,
        b.state.stopMotionLastFrame,
      ),
    );

    // Use the last clip that has a ghost frame, not just the last clip.
    // This prevents the overlay from disappearing while recording a new
    // clip that doesn't have a ghost frame yet.
    final clipGhost = ref.watch(
      clipManagerProvider.select((s) {
        for (var i = s.clips.length - 1; i >= 0; i--) {
          final clip = s.clips[i];
          if (clip.ghostFramePath != null) {
            return (
              path: clip.ghostFramePath!,
              isFrontCamera: clip.isFrontCameraLens,
            );
          }
        }
        return null;
      }),
    );

    // Stop-motion assembles at the end, so there are no clips during capture —
    // align the next pose against the last captured still instead.
    final ghostData = capturesStills
        ? (stopMotionLastFrame != null
              ? (path: stopMotionLastFrame, isFrontCamera: false)
              : null)
        : clipGhost;

    final showGhost = showOverlay && ghostData != null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: showGhost
          ? IgnorePointer(
              key: ValueKey('ghost-frame-${ghostData.path}'),
              child: Opacity(
                opacity: 0.48,
                child: Transform.flip(
                  flipX: ghostData.isFrontCamera,
                  child: Image.file(
                    File(ghostData.path),
                    fit: .cover,
                    width: .infinity,
                    height: .infinity,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
