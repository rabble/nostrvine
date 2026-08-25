// ABOUTME: Developer-options section for sharing the captured log file
// ABOUTME: Developer tooling — users ship logs automatically via Report a Bug

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/utils/share_position_origin.dart';

/// Hands the captured log file to the system share sheet.
class ExportLogsSection extends ConsumerWidget {
  const ExportLogsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: DivineIcon(
        icon: DivineIconName.save,
        color: context.vineColors.accentPositive,
      ),
      title: Text(
        context.l10n.devOptionsExportLogs,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
      ),
      subtitle: Text(
        context.l10n.devOptionsExportLogsSubtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      onTap: () => _exportLogs(context, ref),
    );
  }

  Future<void> _exportLogs(BuildContext context, WidgetRef ref) async {
    final bugReportService = ref.read(bugReportServiceProvider);
    final userPubkey = ref.read(authServiceProvider).currentPublicKeyHex;

    // Resolve the popover anchor before any await — iPad idiom (including
    // iOS builds on Apple Silicon Macs) rejects the share sheet without it.
    final sharePositionOrigin = shareAnchorForContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.supportExportingLogs,
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await bugReportService.exportLogsToFile(
      currentScreen: 'DeveloperOptionsScreen',
      userPubkey: userPubkey,
      sharePositionOrigin: sharePositionOrigin,
    );
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    switch (result.status) {
      case LogExportStatus.cancelled:
        // User backed out of the share sheet or Save As dialog.
        return;
      case LogExportStatus.noLogs:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportNoLogsToExport,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      case LogExportStatus.unconfirmed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportExportLogsUnconfirmed,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      case LogExportStatus.failed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.supportExportLogsFailed,
            error: true,
          ),
        );
        return;
      case LogExportStatus.shared:
      case LogExportStatus.saved:
        break;
    }

    final filePath = result.filePath;
    if (filePath != null) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.supportLogsSavedTo(filePath),
          duration: const Duration(seconds: 8),
          actionLabel: context.l10n.supportRevealLogsAction,
          onActionPressed: () {
            // DivineSnackbarContainer's action is a plain button, so unlike
            // SnackBarAction it does not dismiss the banner for us.
            messenger.hideCurrentSnackBar();
            bugReportService.revealExportedFile(filePath);
          },
        ),
      );
    }
  }
}
