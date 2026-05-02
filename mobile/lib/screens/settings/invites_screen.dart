// ABOUTME: Settings screen for viewing and sharing invite codes.
// ABOUTME: Page creates InviteStatusCubit; View renders code list with
// ABOUTME: copy/share actions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:share_plus/share_plus.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  static const routeName = 'invites';
  static const path = '/invites';

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InviteStatusCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.navGreen,
        title: Text(context.l10n.invitesTitle),
      ),
      body: const InvitesView(),
    );
  }
}

@visibleForTesting
class InvitesView extends StatelessWidget {
  const InvitesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: BlocBuilder<InviteStatusCubit, InviteStatusState>(
          builder: (context, state) {
            return switch (state.status) {
              InviteStatusLoadingStatus.initial ||
              InviteStatusLoadingStatus.loading => const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
              InviteStatusLoadingStatus.error => _ErrorView(
                onRetry: () => context.read<InviteStatusCubit>().load(),
              ),
              InviteStatusLoadingStatus.loaded => _LoadedView(
                inviteStatus: state.inviteStatus!,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.inviteStatus});

  final InviteStatus inviteStatus;

  @override
  Widget build(BuildContext context) {
    final unclaimed = inviteStatus.unclaimedCodes;
    final claimed = inviteStatus.claimedCodes;
    final hasRemainingCapacity = inviteStatus.remaining > 0;

    if (unclaimed.isEmpty && claimed.isEmpty && !hasRemainingCapacity) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.invitesNoneAvailable,
            style: const TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (unclaimed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.invitesShareWithPeople,
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ),
          ...unclaimed.map((code) => _InviteCodeCard(code: code)),
          const SizedBox(height: 24),
        ],
        if (hasRemainingCapacity) ...[
          _GenerateInviteCard(remaining: inviteStatus.remaining),
          const SizedBox(height: 24),
        ],
        if (claimed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.invitesUsedInvites,
              style: VineTheme.titleSmallFont(color: VineTheme.secondaryText),
            ),
          ),
          ...claimed.map((code) => _ClaimedCodeRow(code: code)),
        ],
      ],
    );
  }
}

class _GenerateInviteCard extends StatelessWidget {
  const _GenerateInviteCard({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: VineTheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              l10n.invitesGenerateCardTitle(remaining),
              style: VineTheme.titleMediumFont(),
            ),
            Text(
              l10n.invitesGenerateCardSubtitle,
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
            DivineButton(
              label: l10n.invitesGenerateButtonLabel,
              expanded: true,
              onPressed: () =>
                  context.read<InviteStatusCubit>().generateInvite(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final InviteCode code;

  String _shareMessage(BuildContext context) =>
      context.l10n.invitesShareMessage(code.code);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text(code.code, style: VineTheme.titleLargeFont())),
            IconButton(
              icon: const DivineIcon(
                icon: DivineIconName.copy,
                color: VineTheme.vineGreen,
              ),
              tooltip: context.l10n.invitesCopyInvite,
              onPressed: () => ClipboardUtils.copy(
                context,
                _shareMessage(context),
                message: context.l10n.invitesCopied,
              ),
            ),
            IconButton(
              icon: const DivineIcon(
                icon: DivineIconName.shareFat,
                color: VineTheme.vineGreen,
              ),
              tooltip: context.l10n.invitesShareInvite,
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: _shareMessage(context),
                  subject: context.l10n.invitesShareSubject,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimedCodeRow extends StatelessWidget {
  const _ClaimedCodeRow({required this.code});

  final InviteCode code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code.code,
              style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
            ),
          ),
          const DivineIcon(
            icon: DivineIconName.check,
            color: VineTheme.vineGreen,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.invitesClaimed,
            style: VineTheme.labelSmallFont(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.invitesCouldNotLoad,
            style: const TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(
              context.l10n.invitesRetry,
              style: const TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }
}
