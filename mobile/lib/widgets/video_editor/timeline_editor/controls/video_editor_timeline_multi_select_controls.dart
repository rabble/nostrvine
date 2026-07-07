import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';

/// Action bar shown while the timeline is in multi-select mode.
///
/// Surfaces the selection count plus Merge / Delete / Done actions. Merge and
/// Delete are gated on the selection so the user can never merge a single clip
/// or delete every clip.
class TimelineMultiSelectControls extends StatelessWidget {
  const TimelineMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final (selectedCount, clipCount, isMerging) = context.select(
      (ClipEditorBloc b) => (
        b.state.selectedClipIds.length,
        b.state.clips.length,
        b.state.isMerging,
      ),
    );

    final canMerge = selectedCount >= 2 && !isMerging;
    final canDelete =
        selectedCount >= 1 && selectedCount < clipCount && !isMerging;

    return TimelineActionBar(
      countLabel: context.l10n.videoEditorMultiSelectCountLabel(selectedCount),
      actions: [
        TimelineActionButton(
          icon: .stackSimple,
          label: context.l10n.videoEditorMergeLabel,
          semanticLabel:
              context.l10n.videoEditorMergeSelectedClipsSemanticLabel,
          onPressed: canMerge ? () => _merge(context) : null,
          type: .primary,
        ),
        TimelineActionButton(
          icon: .trash,
          label: context.l10n.videoEditorDeleteLabel,
          semanticLabel:
              context.l10n.videoEditorDeleteSelectedClipsSemanticLabel,
          onPressed: canDelete ? () => _delete(context) : null,
          type: .error,
        ),
        TimelineActionButton(
          icon: .check,
          label: context.l10n.videoEditorDoneLabel,
          semanticLabel: context.l10n.videoEditorMultiSelectDoneSemanticLabel,
          onPressed: () => context.read<ClipEditorBloc>().add(
            const ClipEditorMultiSelectCancelled(),
          ),
        ),
      ],
    );
  }

  void _merge(BuildContext context) {
    context.read<ClipEditorBloc>().add(
      const ClipEditorSelectedClipsMergeRequested(),
    );
  }

  void _delete(BuildContext context) {
    // The bloc owns the clip-list mutation; the scaffold's removed-result
    // listener rebases markers and commits the new list to editor history.
    context.read<ClipEditorBloc>().add(
      const ClipEditorSelectedClipsRemoved(),
    );
  }
}
