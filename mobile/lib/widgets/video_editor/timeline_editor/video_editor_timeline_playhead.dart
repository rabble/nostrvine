import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';

/// Playhead — thin vertical line centered in the viewport
class VideoEditorTimelinePlayhead extends StatelessWidget {
  const VideoEditorTimelinePlayhead({super.key});

  @override
  Widget build(BuildContext context) {
    final (isReordering) = context.select(
      (VideoEditorMainBloc b) => b.state.isReordering,
    );

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedOpacity(
      opacity: isReordering ? 0.0 : 1.0,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: const IgnorePointer(
        child: Align(
          child: SizedBox(
            width: TimelineConstants.playheadWidth,
            height: .infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: VineTheme.onSurface,
                boxShadow: [BoxShadow(color: VineTheme.backgroundCamera)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
