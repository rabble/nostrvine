import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

class VideoEditorTimelineControls extends StatelessWidget {
  const VideoEditorTimelineControls({
    required this.onDone,
    this.onDelete,
    this.onEdit,
    this.onDuplicated,
    this.onSplit,
    super.key,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicated;
  final VoidCallback? onSplit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.backgroundCamera,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const .fromLTRB(0, 16, 0, 8),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: .horizontal,
              padding: const .symmetric(horizontal: 16),
              child: Row(
                spacing: 16,
                mainAxisAlignment: .center,
                children: [
                  if (onDelete != null)
                    _ControlButton(
                      icon: .trash,
                      label: context.l10n.videoEditorDeleteLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorDeleteSelectedItemSemanticLabel,
                      onPressed: onDelete,
                      type: .error,
                    ),
                  if (onEdit != null)
                    _ControlButton(
                      icon: .pencilSimple,
                      label: context.l10n.videoEditorEditLabel,
                      semanticLabel:
                          context.l10n.videoEditorEditSelectedItemSemanticLabel,
                      onPressed: onEdit,
                    ),
                  if (onDuplicated != null)
                    _ControlButton(
                      icon: .copy,
                      label: context.l10n.videoEditorDuplicateLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorDuplicateSelectedItemSemanticLabel,
                      onPressed: onDuplicated,
                    ),
                  if (onSplit != null)
                    _ControlButton(
                      icon: .scissors,
                      label: context.l10n.videoEditorSplitLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorSplitSelectedClipSemanticLabel,
                      onPressed: onSplit,
                    ),
                  _ControlButton(
                    icon: .check,
                    label: context.l10n.videoEditorDoneLabel,
                    semanticLabel: context
                        .l10n
                        .videoEditorFinishTimelineEditingSemanticLabel,
                    onPressed: onDone,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
