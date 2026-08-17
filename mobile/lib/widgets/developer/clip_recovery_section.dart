// ABOUTME: Developer-only rescue for recordings the app can no longer show.
// ABOUTME: Answers "my clips are gone" with where they actually are.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/clip_recovery/clip_recovery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_recovery.dart';
import 'package:openvine/providers/storage_providers.dart';
import 'package:openvine/utils/byte_size_format.dart';
import 'package:openvine/utils/clipboard_utils.dart';

/// Developer Options section that finds and reattaches missing recordings.
///
/// Two things make a library look empty while the recordings are still on the
/// device: rows stamped with a different account (every query filters by
/// owner), and files left behind by a database reset. This reports both and
/// offers to move them to the signed-in account.
///
/// The report comes first on purpose — both actions write, and the owner
/// restamp in particular takes rows away from whichever account currently
/// holds them, so the operator sees the pubkey before deciding.
class ClipRecoverySection extends ConsumerWidget {
  /// Creates the section.
  const ClipRecoverySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(clipRecoveryServiceProvider);
    return BlocProvider<ClipRecoveryCubit>(
      key: ValueKey(service),
      create: (_) => ClipRecoveryCubit(service: service),
      child: const ClipRecoveryView(),
    );
  }
}

/// The section UI. Split from [ClipRecoverySection] so it can be tested with a
/// stubbed [ClipRecoveryCubit].
class ClipRecoveryView extends StatelessWidget {
  /// Creates the view.
  @visibleForTesting
  const ClipRecoveryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select((ClipRecoveryCubit c) => c.state.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.devOptionsClipRecovery,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(
                l10n.devOptionsClipRecoveryDescription,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              if (status == ClipRecoveryStatus.failure)
                Text(
                  l10n.devOptionsClipRecoveryFailure,
                  style: VineTheme.titleMediumFont(color: VineTheme.error),
                )
              else
                const _RecoveryResult(),
              const _RecoveryActions(),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecoveryResult extends StatelessWidget {
  const _RecoveryResult();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ClipRecoveryCubit>().state;
    if (!state.hasReport) return const SizedBox.shrink();

    final report = state.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (state.status != ClipRecoveryStatus.scanned)
          Text(
            l10n.devOptionsClipRecoveryRecovered(state.lastRecoveredCount),
            style: VineTheme.titleMediumFont(
              color: context.vineColors.accentPositive,
            ),
          ),
        Text(
          l10n.devOptionsClipRecoveryVisible(
            report.ownedClipCount,
            report.ownedDraftCount,
          ),
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        if (!report.hasRecoverableContent)
          Text(
            l10n.devOptionsClipRecoveryEmpty,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        if (report.foreignGroups.isNotEmpty) ...[
          Text(
            l10n.devOptionsClipRecoveryOtherAccounts,
            style: VineTheme.labelLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          ...report.foreignGroups.map(_OwnerGroupRow.new),
        ],
        if (report.orphanFiles.isNotEmpty) const _OrphanFiles(),
      ],
    );
  }
}

class _OwnerGroupRow extends StatelessWidget {
  const _OwnerGroupRow(this.group);

  final ClipOwnerGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBusy = context.select((ClipRecoveryCubit c) => c.state.isBusy);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          // Printed in full: a truncated pubkey cannot be matched against an
          // account, and this is the one value the operator has to verify
          // before handing the rows to someone else.
          Text(
            group.ownerPubkey ?? l10n.devOptionsClipRecoveryUnowned,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  l10n.devOptionsClipRecoveryCounts(
                    group.clipCount,
                    group.draftCount,
                  ),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineButton(
                label: l10n.devOptionsClipRecoveryClaim,
                type: DivineButtonType.secondary,
                onPressed: isBusy
                    ? null
                    : () => context.read<ClipRecoveryCubit>().claimOwnerGroup(
                        group,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrphanFiles extends StatelessWidget {
  const _OrphanFiles();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ClipRecoveryCubit>().state;
    final report = state.report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          l10n.devOptionsClipRecoveryOrphanFiles(
            report.orphanFiles.length,
            formatByteSize(report.orphanBytes),
          ),
          style: VineTheme.labelLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
        ...report.orphanFiles.map(_OrphanFileRow.new),
        DivineButton(
          label: l10n.devOptionsClipRecoveryImport,
          type: DivineButtonType.secondary,
          expanded: true,
          onPressed: state.isBusy
              ? null
              : () => context.read<ClipRecoveryCubit>().importOrphanFiles(),
        ),
      ],
    );
  }
}

class _OrphanFileRow extends StatelessWidget {
  const _OrphanFileRow(this.file);

  final OrphanClipFile file;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodySmallFont(
      color: context.vineColors.secondaryText,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        SizedBox(
          width: 72,
          child: Text(formatByteSize(file.sizeBytes), style: style),
        ),
        Expanded(child: Text(file.path.split('/').last, style: style)),
      ],
    );
  }
}

class _RecoveryActions extends StatelessWidget {
  const _RecoveryActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ClipRecoveryCubit>().state;

    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: DivineButton(
            label: l10n.devOptionsClipRecoveryScan,
            type: DivineButtonType.secondary,
            expanded: true,
            onPressed: state.isBusy
                ? null
                : () => context.read<ClipRecoveryCubit>().scan(),
          ),
        ),
        if (state.hasReport)
          Expanded(
            child: DivineButton(
              label: l10n.shareSheetCopy,
              type: DivineButtonType.secondary,
              expanded: true,
              onPressed: () => ClipboardUtils.copyVerified(
                context,
                state.report.toReportText(),
                message: l10n.devOptionsClipRecoveryCopied,
              ),
            ),
          ),
      ],
    );
  }
}
