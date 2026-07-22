// ABOUTME: Editor canvas preview of CC-overlay captions during playback.
// ABOUTME: Shows the active cue as the same pill viewers see in the feed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/caption_pill.dart';

/// Previews CC-overlay caption cues on the editor canvas.
///
/// Only cues of the non-burned track render here (captions items without a
/// layer); burned-in cues are real layers previewed by the canvas itself.
class VideoEditorCaptionPreviewOverlay extends StatelessWidget {
  /// Creates the preview overlay.
  const VideoEditorCaptionPreviewOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final position = context.select(
      (VideoEditorMainBloc b) => b.state.currentPosition,
    );
    final items = context.select((TimelineOverlayBloc b) => b.state.items);

    String? activeText;
    for (final item in items) {
      if (item.type == TimelineOverlayType.captions &&
          item.layer == null &&
          position >= item.startTime &&
          position <= item.endTime) {
        activeText = item.label;
        break;
      }
    }

    if (activeText == null || activeText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 16,
      right: 16,
      bottom: 48,
      child: IgnorePointer(
        child: Center(child: CaptionPill(text: activeText)),
      ),
    );
  }
}
