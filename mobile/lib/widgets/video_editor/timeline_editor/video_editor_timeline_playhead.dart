import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';

/// Playhead — thin vertical line centered in the viewport
class VideoEditorTimelinePlayhead extends StatelessWidget {
  const VideoEditorTimelinePlayhead({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: const IgnorePointer(
        child: Align(
          child: SizedBox(
            width: TimelineConstants.playheadWidth,
            height: .infinity,
            child: ColoredBox(color: VineTheme.onSurface),
          ),
        ),
      ),
    );
  }
}
