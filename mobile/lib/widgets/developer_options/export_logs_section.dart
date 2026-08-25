// ABOUTME: Developer-options section for sharing the captured log file
// ABOUTME: Developer tooling — users ship logs automatically via Report a Bug

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/export_logs/export_logs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/share_position_origin.dart';

/// Hands the captured log file to the system share sheet.
class ExportLogsSection extends ConsumerWidget {
  const ExportLogsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bugReportService = ref.watch(bugReportServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final authState = ref.watch(currentAuthStateProvider);
    return BlocProvider<ExportLogsCubit>(
      key: ValueKey((bugReportService, authService, authState)),
      create: (_) => ExportLogsCubit(
        bugReportService: bugReportService,
        currentScreen: 'DeveloperOptionsScreen',
        userPubkey: authService.currentPublicKeyHex,
      ),
      child: const ExportLogsView(),
    );
  }
}

@visibleForTesting
class ExportLogsView extends StatelessWidget {
  @visibleForTesting
  const ExportLogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExportLogsCubit, ExportLogsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _showOutcome,
      child: const _ExportLogsTile(),
    );
  }

  static void _showOutcome(BuildContext context, ExportLogsState state) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    if (state.status == ExportLogsStatus.exporting) {
      messenger.showSnackBar(
        DivineSnackbarContainer.snackBar(
          l10n.supportExportingLogs,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    messenger.hideCurrentSnackBar();

    switch (state.status) {
      case ExportLogsStatus.idle:
      case ExportLogsStatus.exporting:
      case ExportLogsStatus.cancelled:
        // Cancelled means the user backed out — they know what they did.
        return;
      case ExportLogsStatus.noLogs:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            l10n.supportNoLogsToExport,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      case ExportLogsStatus.unconfirmed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            l10n.supportExportLogsUnconfirmed,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      case ExportLogsStatus.failed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            l10n.supportExportLogsFailed,
            error: true,
          ),
        );
        return;
      case ExportLogsStatus.shared:
      case ExportLogsStatus.saved:
        break;
    }

    final filePath = state.filePath;
    if (filePath == null) return;

    final cubit = context.read<ExportLogsCubit>();
    messenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        l10n.supportLogsSavedTo(filePath),
        duration: const Duration(seconds: 8),
        actionLabel: l10n.supportRevealLogsAction,
        onActionPressed: () {
          // DivineSnackbarContainer's action is a plain button, so unlike
          // SnackBarAction it does not dismiss the banner for us.
          messenger.hideCurrentSnackBar();
          cubit.revealFile(filePath);
        },
      ),
    );
  }
}

class _ExportLogsTile extends StatelessWidget {
  const _ExportLogsTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: DivineIcon(
        icon: DivineIconName.save,
        color: context.vineColors.accentPositive,
      ),
      title: Text(
        context.l10n.devOptionsExportLogs,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        context.l10n.devOptionsExportLogsSubtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      // Resolve the popover anchor before the cubit's first await — the iPad
      // idiom (including iOS builds on Apple Silicon Macs) rejects the share
      // sheet without it.
      onTap: () => context.read<ExportLogsCubit>().export(
        sharePositionOrigin: shareAnchorForContext(context),
      ),
    );
  }
}
