// ABOUTME: Bottom sheet with actions for a DM message bubble.
// ABOUTME: Shows Copy for all messages, Delete for sent, Report for received.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Actions available from the message long-press sheet.
enum MessageAction {
  /// Copy the message text to clipboard.
  copy,

  /// Copy the divine.video video URL embedded in the message.
  copyVideoUrl,

  /// Delete the message for everyone (NIP-09 kind 5).
  delete,

  /// Report the message.
  report,
}

/// Shows a bottom sheet with actions for a single DM message.
///
/// [isSent] controls which options appear:
/// - Sent messages: Copy, Delete for everyone
/// - Received messages: Copy, Report
///
/// When [isVideoShare] is true, an extra "Copy video URL" entry is
/// surfaced after "Copy text" so the user can grab the shared video's
/// link without the surrounding message body.
///
/// Returns the selected [MessageAction], or null if dismissed.
class MessageActionsSheet {
  static Future<MessageAction?> show({
    required BuildContext context,
    required bool isSent,
    bool isVideoShare = false,
  }) async {
    MessageAction? result;

    final l10n = context.l10n;
    final options = <VineBottomSheetActionData>[
      VineBottomSheetActionData(
        iconPath: DivineIconName.copy.assetPath,
        label: l10n.dmMessageActionCopyText,
        onTap: () => result = MessageAction.copy,
      ),
      if (isVideoShare)
        VineBottomSheetActionData(
          iconPath: DivineIconName.linkSimple.assetPath,
          label: l10n.dmMessageActionCopyVideoUrl,
          onTap: () => result = MessageAction.copyVideoUrl,
        ),
      if (isSent)
        VineBottomSheetActionData(
          iconPath: DivineIconName.trash.assetPath,
          label: l10n.dmMessageActionDeleteForEveryone,
          onTap: () => result = MessageAction.delete,
        ),
      if (!isSent)
        VineBottomSheetActionData(
          iconPath: DivineIconName.flag.assetPath,
          label: l10n.dmMessageActionReport,
          onTap: () => result = MessageAction.report,
        ),
    ];

    await VineBottomSheetActionMenu.show(context: context, options: options);

    return result;
  }
}
