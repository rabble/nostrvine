// ABOUTME: Reusable top toolbar for video editor sub-editors.
// ABOUTME: Provides close/done buttons with optional center widgets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Reusable top bar for video editor sub-editors.
///
/// Displays a close button on the left and a done button on the right.
/// Optional [center] widgets are placed between the two buttons.
///
/// When [center] is empty a single [Spacer] pushes the buttons to opposite
/// ends. When non-empty the caller controls spacing (e.g. wrap items in
/// [Spacer], [Flexible], or [SizedBox] as needed).
class VideoEditorToolbar extends StatelessWidget {
  const VideoEditorToolbar({
    required this.onClose,
    required this.onDone,
    this.closeIcon = DivineIconName.x,
    this.doneIcon = DivineIconName.check,
    this.center,
    super.key,
  });

  /// Called when the close button is pressed.
  final VoidCallback onClose;

  /// Called when the done button is pressed.
  final VoidCallback onDone;

  /// Icon shown on the close button. Defaults to [DivineIconName.x].
  final DivineIconName closeIcon;

  /// Icon shown on the done button. Defaults to [DivineIconName.check].
  final DivineIconName doneIcon;

  /// Optional widgets displayed between the close and done buttons.
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const .fromLTRB(16, 16, 16, 0),
        child: Row(
          spacing: 8,
          mainAxisAlignment: .spaceBetween,
          children: [
            DivineIconButton(
              icon: closeIcon,
              // TODO(l10n): Replace with context.l10n when localization is added.
              semanticLabel: 'Close',
              size: .small,
              type: .ghostSecondary,
              onPressed: onClose,
            ),
            ?center,
            DivineIconButton(
              icon: doneIcon,
              // TODO(l10n): Replace with context.l10n when localization is added.
              semanticLabel: 'Done',
              size: .small,
              type: .tertiary,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}
