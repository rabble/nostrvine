// ABOUTME: Presents terminal creator-delete cleanup feedback after relay success.
// ABOUTME: Captures UI dependencies before a delete surface is dismissed.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_deletion_service.dart';

void showOwnerVideoCleanupCompletion(
  BuildContext context,
  OwnerVideoActionsCubit cubit,
) {
  final completion = cubit.cleanupCompletion;
  if (completion == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final confirmed = context.l10n.shareMenuDeleteCleanupConfirmed;
  final delayed = context.l10n.shareMenuDeleteCleanupDelayed;
  final failed = context.l10n.shareMenuDeleteCleanupFailed;
  final partial = context.l10n.shareMenuDeletePartiallyConfirmed;

  unawaited(
    completion.then((state) {
      final message = switch (state.cleanupStatus) {
        OwnerVideoCleanupStatus.confirmed =>
          state.deleteResult?.acceptance == DeleteAcceptance.someRelays
              ? partial
              : confirmed,
        OwnerVideoCleanupStatus.delayed => delayed,
        OwnerVideoCleanupStatus.failed => failed,
        OwnerVideoCleanupStatus.idle || OwnerVideoCleanupStatus.inProgress =>
          throw StateError('Cleanup completion was not terminal'),
      };
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          message,
          error: state.cleanupStatus == OwnerVideoCleanupStatus.failed,
        ),
      );
    }),
  );
}
