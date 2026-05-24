import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_clip_speed_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';

/// Controls shown when a clip is in editing mode: Delete, Copy, Split, Done.
class TimelineClipControls extends StatefulWidget {
  const TimelineClipControls({required this.playheadPosition, super.key});

  final ValueNotifier<Duration> playheadPosition;

  @override
  State<TimelineClipControls> createState() => _TimelineClipControlsState();
}

class _TimelineClipControlsState extends State<TimelineClipControls> {
  @override
  Widget build(BuildContext context) {
    final clips = context.select((ClipEditorBloc b) => b.state.clips);
    final isLastClip = clips.length <= 1;
    final isExtractingAudio = context.select(
      (ClipEditorBloc b) => b.state.isExtractingAudio,
    );

    return VideoEditorTimelineControls(
      onDelete: isLastClip ? null : () => _deleteClip(context),
      onDuplicated: () => _duplicateClip(context),
      onSplit: () => _splitClip(context),
      onSpeed: () => _setPlaybackSpeed(context),
      onExtractAudio: () => _requestExtractAudio(context),
      isExtractingAudio: isExtractingAudio,
      // Done is gated while extraction is in flight purely as a UX cue —
      // the success/failure side effect itself is handled by an editor-
      // session-level listener in [VideoEditorScaffold], so it survives
      // even if the user Deletes/Duplicates/Splits the clip (which exits
      // edit mode and unmounts these controls) before extraction returns.
      onDone: isExtractingAudio
          ? null
          : () {
              context.read<ClipEditorBloc>().add(
                const ClipEditorEditingStopped(),
              );
            },
    );
  }

  Future<void> _setPlaybackSpeed(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clip = state.clips[state.currentClipIndex];
    final editor = VideoEditorScope.of(context).requireEditor;

    final result = await VineBottomSheet.show<double>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoEditorClipSpeedSheet(initialSpeed: clip.playbackSpeed ?? 1.0),
    );

    if (result == null || !mounted) return;

    final updated = clip.copyWith(playbackSpeed: result);
    bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: updated));

    editor.setClipState(
      state.clips.map((c) => c.id == clip.id ? updated : c).toList(),
    );
  }

  void _requestExtractAudio(BuildContext context) {
    context.read<ClipEditorBloc>().add(
      ClipEditorAudioExtractionRequested(
        clipTitle: context.l10n.videoEditorClipAudioTitle,
      ),
    );
  }

  void _deleteClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    final clipId = state.clips[state.currentClipIndex].id;
    final editor = VideoEditorScope.of(context).requireEditor;

    bloc.add(ClipEditorClipRemoved(clipId));

    if (state.currentClipIndex >= state.clips.length - 1) {
      bloc.add(ClipEditorClipSelected(state.clips.length - 2));
    }
    bloc.add(const ClipEditorEditingStopped());

    editor.setClipState(
      state.clips.where((clip) => clip.id != clipId).toList(),
    );
  }

  void _duplicateClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    final clip = state.clips[state.currentClipIndex];
    final editor = VideoEditorScope.of(context).requireEditor;

    final copy = clip.copyWith(
      id:
          '${clip.id}_copy_'
          '${DateTime.now().millisecondsSinceEpoch}',
    );

    bloc
      ..add(ClipEditorClipInserted(index: state.clips.length, clip: copy))
      ..add(const ClipEditorEditingStopped());

    editor.setClipState([...state.clips, copy]);
  }

  void _splitClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex >= state.clips.length) return;

    final selectedClip = state.clips[state.currentClipIndex];

    // The playhead is in playback time; preceding clips must be accumulated
    // with playbackDuration (not trimmedDuration) to stay in the same
    // coordinate space.
    final globalPosition = widget.playheadPosition.value;
    var clipStart = Duration.zero;
    for (var i = 0; i < state.currentClipIndex; i++) {
      clipStart += state.clips[i].playbackDuration;
    }
    final localPlaybackPosition = globalPosition - clipStart;

    // Bounds-check in playback time.
    if (localPlaybackPosition < Duration.zero ||
        localPlaybackPosition > selectedClip.playbackDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorSplitPlayheadOutsideClip,
        ),
      );
      return;
    }

    // The split service and bloc expect a source-time offset relative to
    // trimmedDuration.  Convert: source = playback × speed
    // (since playbackDuration = trimmedDuration / speed).
    final speed = selectedClip.playbackSpeed ?? 1.0;
    final localPosition = speed == 1.0
        ? localPlaybackPosition
        : Duration(
            microseconds: (localPlaybackPosition.inMicroseconds * speed)
                .round(),
          );

    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      localPosition,
    )) {
      const minDuration = VideoEditorSplitService.minClipDuration;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorSplitPositionInvalid(
            minDuration.inMilliseconds,
          ),
        ),
      );
      return;
    }

    // Update the split position and request the split.
    bloc
      ..add(ClipEditorSplitPositionChanged(localPosition))
      ..add(const ClipEditorSplitRequested());
  }
}
