// ABOUTME: Bottom sheet with actions for a DM message bubble.
// ABOUTME: Shows Copy for all messages, Report for received messages.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Actions available from the message long-press sheet.
enum MessageAction {
  /// Copy the message text to clipboard.
  copy,

  /// Report the message.
  report,
}

/// Shows a bottom sheet with actions for a single DM message.
///
/// [isSent] controls which options appear:
/// - Sent messages: Copy
/// - Received messages: Copy, Report
///
/// Returns the selected [MessageAction], or null if dismissed.
class MessageActionsSheet {
  static Future<MessageAction?> show({
    required BuildContext context,
    required bool isSent,
  }) async {
    MessageAction? result;

    final options = <VineBottomSheetActionData>[
      VineBottomSheetActionData(
        iconPath: DivineIconName.copy.assetPath,
        label: 'Copy text',
        onTap: () => result = MessageAction.copy,
      ),
      if (!isSent)
        VineBottomSheetActionData(
          iconPath: DivineIconName.flag.assetPath,
          label: 'Report',
          onTap: () => result = MessageAction.report,
        ),
    ];

    await VineBottomSheetActionMenu.show(
      context: context,
      options: options,
    );

    return result;
  }
}
