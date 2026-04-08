import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';

/// Playhead — thin vertical line centered in the viewport
class VideoEditorTimelinePlayhead extends StatelessWidget {
  const VideoEditorTimelinePlayhead({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        margin: const EdgeInsets.only(top: TimelineConstants.rulerHeight),
        width: TimelineConstants.playheadWidth,
        height: .infinity,
        child: const ColoredBox(color: VineTheme.onSurface),
      ),
    );
  }
}
