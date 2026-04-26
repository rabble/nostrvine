import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

/// Shows context-specific controls at the bottom of the timeline based on
/// what is currently selected: a clip (editing), a layer overlay, or a filter
/// overlay.
class TimelineControlsBar extends StatelessWidget {
  const TimelineControlsBar({
    required this.isEditing,
    required this.playheadPosition,
    super.key,
  });

  final bool isEditing;
  final ValueNotifier<Duration> playheadPosition;

  static const _animationDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final selectedOverlayItem = context.select((TimelineOverlayBloc b) {
      final state = b.state;
      final selectedId = state.selectedItemId;
      if (selectedId == null) return null;
      return state.items.where((i) => i.id == selectedId).firstOrNull;
    });

    final showControls = isEditing || selectedOverlayItem != null;
    final controlsChild = switch ((showControls, isEditing)) {
      (true, true) => TimelineClipControls(
        key: const ValueKey('timeline_controls_clip'),
        playheadPosition: playheadPosition,
      ),
      (true, false) => TimelineOverlayControls(
        key: const ValueKey('timeline_controls_overlay'),
        item: selectedOverlayItem!,
      ),
      (false, _) => const SizedBox(
        key: ValueKey('timeline_controls_hidden'),
        width: double.infinity,
      ),
    };

    return AnimatedSwitcher(
      duration: _animationDuration,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: child,
      ),
      child: controlsChild,
    );
  }
}
