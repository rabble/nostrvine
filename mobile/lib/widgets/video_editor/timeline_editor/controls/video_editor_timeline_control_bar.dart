import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

/// Shows context-specific controls at the bottom of the timeline based on
/// what is currently selected: a clip (editing), a layer overlay, or a filter
/// overlay.
class TimelineControlsBar extends ConsumerWidget {
  const TimelineControlsBar({
    required this.isEditing,
    required this.playheadPosition,
    super.key,
  });

  final bool isEditing;
  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelectedOverlay = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId != null,
    );

    final showControls = isEditing || hasSelectedOverlay;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: .topCenter,
      child: showControls
          ? isEditing
                ? TimelineClipControls(playheadPosition: playheadPosition)
                : const TimelineOverlayControls()
          : const SizedBox.shrink(),
    );
  }
}
