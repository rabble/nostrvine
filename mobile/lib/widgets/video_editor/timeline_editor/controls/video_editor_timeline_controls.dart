import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class VideoEditorTimelineControls extends StatelessWidget {
  const VideoEditorTimelineControls({
    required this.onDone,
    this.onDelete,
    this.onEdit,
    this.onCopy,
    this.onSplit,
    super.key,
  });

  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
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
        padding: const .fromLTRB(16, 16, 16, 8),
        child: SafeArea(
          top: false,
          child: Wrap(
            spacing: 32,
            runSpacing: 24,
            alignment: .center,
            runAlignment: .center,
            children: [
              if (onDelete != null)
                _ControlButton(
                  icon: .trash,
                  label: 'Delete',
                  onPressed: onDelete,
                  type: .error,
                ),
              if (onEdit != null)
                _ControlButton(
                  icon: .pencilSimple,
                  label: 'Edit',
                  onPressed: onEdit,
                ),
              if (onCopy != null)
                _ControlButton(
                  icon: .copy,
                  label: 'Copy',
                  onPressed: onCopy,
                ),
              if (onSplit != null)
                _ControlButton(
                  icon: .scissors,
                  label: 'Split',
                  onPressed: onSplit,
                ),
              _ControlButton(
                icon: .check,
                label: 'Done',
                onPressed: onDone,
              ),
            ],
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
    required this.onPressed,
    this.type = .secondary,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback? onPressed;
  final DivineIconButtonType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        DivineIconButton(
          icon: icon,
          onPressed: onPressed,
          type: type,
          size: .small,
        ),
        Text(
          label,
          style: VineTheme.bodySmallFont(),
        ),
      ],
    );
  }
}
