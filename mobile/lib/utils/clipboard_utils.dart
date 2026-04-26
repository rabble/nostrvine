// ABOUTME: Utility for clipboard operations with visual feedback
// ABOUTME: Provides consistent copy-to-clipboard experience across the app

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for clipboard operations with visual feedback.
///
/// Provides a consistent copy-to-clipboard experience across the app,
/// showing a styled snackbar on success.
class ClipboardUtils {
  /// Copies the given text to clipboard and shows a success snackbar.
  ///
  /// [context] is used to show the snackbar.
  /// [text] is the content to copy to clipboard.
  /// [message] is the snackbar message (defaults to 'Copied to clipboard').
  static Future<void> copy(
    BuildContext context,
    String text, {
    String message = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(DivineSnackbarContainer.snackBar(message));
    }
  }

  /// Copies a public key (npub) to clipboard with appropriate message.
  ///
  /// This is a convenience method specifically for copying Nostr public keys.
  static Future<void> copyPubkey(BuildContext context, String npub) async {
    await copy(context, npub, message: 'Public key copied to clipboard');
  }
}
