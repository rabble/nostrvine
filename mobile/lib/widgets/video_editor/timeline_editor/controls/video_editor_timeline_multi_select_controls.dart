import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.backgroundCamera,
        boxShadow: [
          BoxShadow(
            color: VineTheme.backgroundColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                context.l10n.videoEditorMultiSelectCountLabel(selectedCount),
                style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
              ),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    spacing: 16,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(
                        icon: .stackSimple,
                        label: context.l10n.videoEditorMergeLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorMergeSelectedClipsSemanticLabel,
                        onPressed: canMerge ? () => _merge(context) : null,
                        type: .primary,
                      ),
                      _ControlButton(
                        icon: .trash,
                        label: context.l10n.videoEditorDeleteLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorDeleteSelectedClipsSemanticLabel,
                        onPressed: canDelete ? () => _delete(context) : null,
                        type: .error,
                      ),
                      _ControlButton(
                        icon: .check,
                        label: context.l10n.videoEditorDoneLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorMultiSelectDoneSemanticLabel,
                        onPressed: () => context.read<ClipEditorBloc>().add(
                          const ClipEditorMultiSelectCancelled(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.type = .secondary,
  });

  final DivineIconName icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final DivineIconButtonType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        DivineIconButton(
          icon: icon,
          semanticLabel: semanticLabel,
          onPressed: onPressed,
          type: type,
          size: .small,
        ),
        Text(label, style: VineTheme.bodySmallFont()),
      ],
    );
  }
}
