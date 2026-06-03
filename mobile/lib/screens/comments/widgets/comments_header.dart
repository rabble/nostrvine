import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Header widget for the comments draggable sheet.
///
/// Displays a "Comments" title and a close button.
class CommentsHeader extends StatelessWidget {
  const CommentsHeader({required this.onClose, super.key});

  /// Callback when close button is pressed.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            l10n.commentsHeaderTitle,
            style: VineTheme.titleMediumFont(),
          ),
          const Spacer(),
          Semantics(
            identifier: 'close_comments_button',
            button: true,
            label: l10n.commentsHeaderCloseLabel,
            child: IconButton(
              icon: const DivineIcon(
                icon: DivineIconName.x,
                color: VineTheme.whiteText,
              ),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
