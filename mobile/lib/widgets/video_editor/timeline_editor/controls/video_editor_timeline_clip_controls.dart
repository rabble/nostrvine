import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';

/// Controls shown when a clip is in editing mode: Delete, Copy, Split, Done.
class TimelineClipControls extends ConsumerStatefulWidget {
  const TimelineClipControls({required this.playheadPosition, super.key});

  final ValueNotifier<Duration> playheadPosition;

  @override
  ConsumerState<TimelineClipControls> createState() =>
      _TimelineClipControlsState();
}

class _TimelineClipControlsState extends ConsumerState<TimelineClipControls> {
  bool _isExtracting = false;

  @override
  Widget build(BuildContext context) {
    final clips = context.select((ClipEditorBloc b) => b.state.clips);
    final isLastClip = clips.length <= 1;

    return VideoEditorTimelineControls(
      onDelete: isLastClip ? null : () => _deleteClip(context, ref),
      onDuplicated: () => _duplicateClip(context, ref),
      onSplit: () => _splitClip(context),
      onExtractAudio: () => _extractAudio(context),
      isExtractingAudio: _isExtracting,
      onDone: () {
        context.read<ClipEditorBloc>().add(const ClipEditorEditingStopped());
      },
    );
  }

  void _deleteClip(BuildContext context, WidgetRef ref) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    final clipId = state.clips[state.currentClipIndex].id;
    final editor = VideoEditorScope.of(context).requireEditor;

    bloc.add(ClipEditorClipRemoved(clipId));

    if (state.currentClipIndex >= state.clips.length - 1) {
      bloc.add(ClipEditorClipSelected(state.clips.length - 2));
    }
    bloc.add(const ClipEditorEditingStopped());

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.clipsStateHistoryKey: state.clips
            .where((clip) => clip.id != clipId)
            .map((e) => e.toJson())
            .toList(),
      },
    );
  }

  void _duplicateClip(BuildContext context, WidgetRef ref) {
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

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.clipsStateHistoryKey: [
          ...state.clips,
          copy,
        ].map((e) => e.toJson()).toList(),
      },
    );
  }

  void _splitClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex >= state.clips.length) return;

    final selectedClip = state.clips[state.currentClipIndex];

    // Compute the split position relative to the current clip.
    // The playhead shows a global timeline position — convert to the local
    // offset within the selected clip.
    final globalPosition = widget.playheadPosition.value;
    var clipStart = Duration.zero;
    for (var i = 0; i < state.currentClipIndex; i++) {
      clipStart += state.clips[i].trimmedDuration;
    }
    final localPosition = globalPosition - clipStart;

    // Check if playhead is within the selected clip.
    if (localPosition < Duration.zero ||
        localPosition > selectedClip.trimmedDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorSplitPlayheadOutsideClip,
        ),
      );
      return;
    }

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

  Future<void> _extractAudio(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    final clip = state.clips[state.currentClipIndex];
    final videoPath = clip.video.file?.path;
    if (videoPath == null) return;

    // Compute where this clip starts in the global timeline.
    var clipStart = Duration.zero;
    for (var i = 0; i < state.currentClipIndex; i++) {
      clipStart += state.clips[i].trimmedDuration;
    }

    setState(() => _isExtracting = true);
    try {
      final result = await AudioExtractionService().extractAudio(videoPath);
      if (!context.mounted) return;

      final editor = VideoEditorScope.of(context).requireEditor;
      final updatedClip = clip.copyWith(volume: 0);

      // Build an AudioEvent for the timeline at the clip's exact position.
      // The extracted file contains the full video audio; duration is the
      // total file duration so the BLoC can compute maxDuration correctly:
      //   maxDuration = duration - startOffset = (full audio) - trimStart
      // startOffset skips the trimmed-off beginning. The composite
      // startTime/endTime then pin the visible portion in the timeline.
      final audioEvent = AudioEvent(
        id: 'local_extracted_${DateTime.now().microsecondsSinceEpoch}',
        pubkey: '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        url: result.audioFilePath,
        mimeType: result.mimeType,
        sha256: result.sha256Hash,
        fileSize: result.fileSize,
        duration: clip.duration.inMilliseconds / 1000,
        title: context.l10n.videoEditorExtractAudioLabel,
        startOffset: clip.trimStart,
        startTime: clipStart,
        endTime: clipStart + clip.duration,
      );

      bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: updatedClip));

      // Write a single atomic history entry covering both the muted clip
      // and the new audio track so undo/redo reverts both together.
      final updatedClips = state.clips
          .map((c) => c.id == clip.id ? updatedClip : c)
          .toList();
      final updatedTracks = [
        ...editor.stateManager.audioTracks,
        audioEvent,
      ];
      editor.addHistory(
        meta: {
          ...editor.stateManager.activeMeta,
          VideoEditorConstants.clipsStateHistoryKey: updatedClips
              .map((c) => c.toJson())
              .toList(),
          VideoEditorConstants.audioStateHistoryKey: updatedTracks
              .map((e) => e.toJson())
              .toList(),
        },
      );
    } on AudioExtractionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(e.message),
      );
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }
}
