// ABOUTME: Shared "Clip moved to trash • Undo" snackbar for the recorder
// ABOUTME: Wires both capture and classic recording modes to the same UX.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

/// Shows the floating "Clip moved to trash • Undo" snackbar after the
/// user taps the recorder's delete-last-clip button. Tapping Undo
/// reverses the soft-delete via [ClipManagerNotifier.undoPendingDeletion].
///
/// The snackbar duration is matched to the notifier's
/// [ClipManagerNotifier.pendingDeletionWindow] so the Undo affordance
/// stays visible for as long as it is honored. Stacks are dismissed
/// before showing so rapid taps see only the latest snackbar.
void showClipDeleteSnackbar(BuildContext context, WidgetRef ref) {
  final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: ClipManagerNotifier.pendingDeletionWindow,
      padding: EdgeInsets.zero,
      backgroundColor: VineTheme.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 68),
      content: DivineSnackbarContainer(
        label: context.l10n.videoRecorderClipDeletedMessage,
        actionLabel: context.l10n.videoRecorderClipUndoLabel,
        onActionPressed: () {
          messenger.hideCurrentSnackBar();
          ref.read(clipManagerProvider.notifier).undoPendingDeletion();
        },
      ),
    ),
  );
}
