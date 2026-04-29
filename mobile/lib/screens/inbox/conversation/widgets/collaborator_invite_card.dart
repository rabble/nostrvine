// ABOUTME: Card UI for structured collaborator invite direct messages.
// ABOUTME: Keeps invite plaintext fallback hidden and exposes accept/ignore.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';

class CollaboratorInviteCard extends StatefulWidget {
  const CollaboratorInviteCard({
    required this.invite,
    required this.isSent,
    super.key,
  });

  final CollaboratorInvite invite;
  final bool isSent;

  @override
  State<CollaboratorInviteCard> createState() => _CollaboratorInviteCardState();
}

class _CollaboratorInviteCardState extends State<CollaboratorInviteCard> {
  @override
  void initState() {
    super.initState();
    // Sender-side cards are static — they never read or write cubit
    // state. The recipient is the only side with actionable state, so
    // skip the load and the BlocSelector subscription entirely (#3559).
    if (!widget.isSent) {
      _loadInviteState();
    }
  }

  @override
  void didUpdateWidget(covariant CollaboratorInviteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSent) return;
    if (oldWidget.invite != widget.invite || oldWidget.isSent) {
      _loadInviteState();
    }
  }

  void _loadInviteState() {
    context.read<CollaboratorInviteActionsCubit>().loadInvites([
      widget.invite,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSent) {
      return _CardChrome(
        invite: widget.invite,
        isSent: true,
        action: _StatusText(
          label: context.l10n.inboxCollabInviteSentStatus,
          color: VineTheme.onSurfaceMuted,
        ),
      );
    }
    return BlocSelector<
      CollaboratorInviteActionsCubit,
      CollaboratorInviteActionsState,
      CollaboratorInviteState
    >(
      selector: (state) => state.stateFor(widget.invite),
      builder: (context, inviteState) {
        return _CardChrome(
          invite: widget.invite,
          isSent: false,
          action: _InviteActions(
            invite: widget.invite,
            state: inviteState,
          ),
        );
      },
    );
  }
}

class _CardChrome extends StatelessWidget {
  const _CardChrome({
    required this.invite,
    required this.isSent,
    required this.action,
  });

  final CollaboratorInvite invite;
  final bool isSent;
  final Widget action;

  String get _titleText {
    final title = invite.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return invite.videoDTag;
  }

  String get _detailText => '${invite.role} on this post';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: isSent
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainerHigh,
            border: Border.all(color: VineTheme.outlineMuted),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Collaborator invite',
                style: VineTheme.labelLargeFont(color: VineTheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                _titleText,
                style: VineTheme.titleMediumFont(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _detailText,
                style: VineTheme.bodySmallFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 16),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteActions extends StatelessWidget {
  const _InviteActions({
    required this.invite,
    required this.state,
  });

  final CollaboratorInvite invite;
  final CollaboratorInviteState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      CollaboratorInviteState.accepted => const _StatusText(
        label: 'Accepted',
        color: VineTheme.primary,
      ),
      CollaboratorInviteState.ignored => const _StatusText(
        label: 'Ignored',
        color: VineTheme.onSurfaceMuted,
      ),
      CollaboratorInviteState.failed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _StatusText(
            label: 'Could not accept. Try again.',
            color: VineTheme.error,
          ),
          const SizedBox(height: 12),
          _ActionRow(invite: invite, isAccepting: false),
        ],
      ),
      CollaboratorInviteState.accepting => _ActionRow(
        invite: invite,
        isAccepting: true,
      ),
      CollaboratorInviteState.pending => _ActionRow(
        invite: invite,
        isAccepting: false,
      ),
    };
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.invite,
    required this.isAccepting,
  });

  final CollaboratorInvite invite;
  final bool isAccepting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DivineButton(
            label: 'Accept',
            size: DivineButtonSize.small,
            isLoading: isAccepting,
            onPressed: isAccepting
                ? null
                : () {
                    context.read<CollaboratorInviteActionsCubit>().acceptInvite(
                      invite,
                    );
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DivineButton(
            label: 'Ignore',
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            onPressed: isAccepting
                ? null
                : () {
                    context.read<CollaboratorInviteActionsCubit>().ignoreInvite(
                      invite,
                    );
                  },
          ),
        ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: VineTheme.labelLargeFont(color: color),
    );
  }
}
