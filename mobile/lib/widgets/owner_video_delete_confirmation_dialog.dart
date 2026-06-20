// ABOUTME: Shared confirmation dialog for deleting the signed-in user's video.
// ABOUTME: Keeps owner-delete confirmation copy and styling consistent.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

Future<bool> showOwnerVideoDeleteConfirmationDialog(
  BuildContext context,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        dialogContext.l10n.shareMenuDeleteVideo,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: Text(
        dialogContext.l10n.shareMenuDeleteConfirmation,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.shareMenuCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: VineTheme.error),
          child: Text(dialogContext.l10n.shareMenuDelete),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
