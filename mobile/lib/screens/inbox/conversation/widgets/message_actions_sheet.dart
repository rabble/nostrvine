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

  /// Save the shared video to the device gallery.
  saveVideo,

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
/// When [isVideoShare] is true, "Copy video URL" and "Save Video" entries
/// are surfaced after "Copy text".
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
      if (isVideoShare)
        VineBottomSheetActionData(
          iconPath: DivineIconName.downloadSimple.assetPath,
          label: l10n.shareSheetSaveVideo,
          onTap: () => result = MessageAction.saveVideo,
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
