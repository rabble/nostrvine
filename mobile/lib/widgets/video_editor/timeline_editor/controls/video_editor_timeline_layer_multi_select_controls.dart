import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Action bar shown while the timeline is in draw-layer multi-select mode.
///
/// Surfaces the selection count plus Combine / Done actions. Combine is gated
/// on the selection so the user can never combine a single drawing.
class TimelineLayerMultiSelectControls extends StatelessWidget {
  const TimelineLayerMultiSelectControls({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedCount = context.select(
      (TimelineOverlayBloc b) => b.state.multiSelectedLayerIds.length,
    );

    final canCombine = selectedCount >= 2;
    final canClear = selectedCount >= 1;

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
                context.l10n.videoEditorLayerMultiSelectCountLabel(
                  selectedCount,
                ),
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
                        label: context.l10n.videoEditorCombineLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorCombineDrawLayersSemanticLabel,
                        onPressed: canCombine ? () => _combine(context) : null,
                        type: .primary,
                      ),
                      _ControlButton(
                        icon: .x,
                        label:
                            context.l10n.videoEditorLayerMultiSelectClearLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorLayerMultiSelectClearSemanticLabel,
                        onPressed: canClear
                            ? () => context.read<TimelineOverlayBloc>().add(
                                const TimelineOverlayLayerSelectionCleared(),
                              )
                            : null,
                        type: .error,
                      ),
                      _ControlButton(
                        icon: .check,
                        label: context.l10n.videoEditorDoneLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorLayerMultiSelectDoneSemanticLabel,
                        onPressed: () =>
                            context.read<TimelineOverlayBloc>().add(
                              const TimelineOverlayLayerMultiSelectCancelled(),
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

  /// Combines the selected draw layers into one via
  /// [ProImageEditorState.mergeSelectedLayers], then exits multi-select mode
  /// and selects the merged layer.
  void _combine(BuildContext context) {
    final editor = VideoEditorScope.of(context).editor;
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final ids = overlayBloc.state.multiSelectedLayerIds;
    if (editor == null || ids.length < 2) return;

    editor.unselectAllLayers();
    for (final id in ids) {
      editor.selectLayerById(id, enableMultiSelect: true);
    }
    final merged = editor.mergeSelectedLayers();
    editor.clearLayerSelection();

    overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled());
    if (merged != null) {
      overlayBloc.add(TimelineOverlayItemSelected(merged.id));
    }
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
