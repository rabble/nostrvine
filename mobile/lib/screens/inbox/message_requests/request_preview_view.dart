// ABOUTME: View for the message request preview screen.
// ABOUTME: Shows sender profile info, message count, and accept/decline actions.

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/collaborator_invite_parser.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// View for the message request preview screen.
///
/// Displays the sender's profile (avatar, name, NIP-05, stats),
/// a "View profile" button, message count text, and two action buttons:
/// "View messages" (accept) and "Decline and remove".
class RequestPreviewView extends ConsumerWidget {
  const RequestPreviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = context.select(
      (RequestPreviewCubit cubit) => cubit.state.status,
    );
    // #176 preview gate: a DM-restricted user reaching this route directly is
    // bounced to the inbox and nothing renders, mirroring the ConversationPage
    // route guard. A build-time branch (not a BlocListener) because the lazy
    // cubit emits `denied` synchronously during its `create:`/`load()`, before
    // any listener could subscribe.
    if (status == RequestPreviewStatus.denied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(InboxPage.path);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final participantPubkeys = context.select(
      (RequestPreviewCubit cubit) => cubit.state.participantPubkeys,
    );

    final otherPubkey = participantPubkeys.isNotEmpty
        ? participantPubkeys.first
        : '';

    // #7335 unresolved-counterparty gate. Everything past this point either
    // identifies the sender or acts on them, and neither is possible until the
    // load resolves a counterparty. Falling through was not cosmetic:
    // `_ActionButtons` went live over an empty `participantPubkeys`, and its
    // "View messages" opened a conversation whose composer cleared the text
    // field and then threw before writing a queue row — no bubble, no toast,
    // no error, so the message looked sent. The header meanwhile named the
    // sender `UserProfile.defaultDisplayNameFor('')`, a generated "Adjective
    // Animal N", above a message count of 0.
    //
    // Returning before the profile watch below also stops the fetch for `''`
    // seen repeatedly in the August iOS release log, where the REST profile
    // fallback rejects it with "Pubkey cannot be empty" and the relay fallback
    // then goes looking for the empty string.
    //
    // `loaded` is gated on the pubkey rather than the status because
    // `_resolveParticipants` returns `[]` for a conversation the local
    // database does not have, reaching this same layout without ever failing.
    if (status == RequestPreviewStatus.loading) {
      return const _UnresolvedRequestScaffold(
        child: CircularProgressIndicator(color: VineTheme.primary),
      );
    }
    if (status == RequestPreviewStatus.error || otherPubkey.isEmpty) {
      return const _UnresolvedRequestScaffold(child: _LoadFailedMessage());
    }

    final messageCount = context.select(
      (RequestPreviewCubit cubit) => cubit.state.messageCount,
    );
    final messages = context.select(
      (RequestPreviewCubit cubit) => cubit.state.messages,
    );
    final currentPubkey =
        ref.watch(authServiceProvider).currentPublicKeyHex ?? '';

    final profileAsync = ref.watch(userProfileReactiveProvider(otherPubkey));

    final profile = profileAsync.asData?.value;

    final displayName =
        moderationDisplayName(context, otherPubkey) ??
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(otherPubkey);

    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: displayName,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: _PreviewBackdrop(
        child: Column(
          children: [
            Expanded(
              child: _ProfileContent(
                displayName: displayName,
                profile: profile,
                otherPubkey: otherPubkey,
                currentPubkey: currentPubkey,
                messageCount: messageCount,
                messages: messages,
              ),
            ),
            _ActionButtons(participantPubkeys: participantPubkeys),
          ],
        ),
      ),
    );
  }
}

/// The rounded panel every state of this screen sits on.
class _PreviewBackdrop extends StatelessWidget {
  const _PreviewBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: ColoredBox(
        color: context.vineColors.surfaceContainerHigh,
        child: child,
      ),
    );
  }
}

/// Chrome for the states that have no counterparty to name yet (#7335).
///
/// Offers no accept action — that one hands the participant list to the
/// conversation route, and the whole point of this branch is that there isn't
/// one. Decline stays, because `declineRequest` keys off the conversation ID
/// alone: a preview read that fails is no reason to make an unwanted request
/// undismissable, leaving the inbox-wide "Remove all requests" as the only way
/// out. The app bar falls back to the section title, since the loaded header's
/// name would be a generated placeholder here.
class _UnresolvedRequestScaffold extends StatelessWidget {
  const _UnresolvedRequestScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.inboxMessageRequestsTitle,
        showBackButton: true,
        // safePop, not pop: `loading` is the first frame of *every* entry to
        // this route, deep links included, and a cold deep link leaves a
        // one-entry stack that plain `pop()` throws on (#6112).
        onBackPressed: () => context.safePop(fallback: InboxPage.path),
      ),
      body: _PreviewBackdrop(
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            const _ActionBar(children: [_DeclineAndRemoveButton()]),
          ],
        ),
      ),
    );
  }
}

/// The read failed. Offers a retry rather than a dead end — the cubit's own
/// `load()` is idempotent, and a Drift read failure is usually transient.
class _LoadFailedMessage extends StatelessWidget {
  const _LoadFailedMessage();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text(
            l10n.messageRequestLoadFailed,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
          _OutlinedActionButton(
            label: l10n.commonRetry,
            onTap: () => context.read<RequestPreviewCubit>().load(),
          ),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.displayName,
    required this.profile,
    required this.otherPubkey,
    required this.currentPubkey,
    required this.messageCount,
    required this.messages,
  });

  final String displayName;
  final UserProfile? profile;
  final String otherPubkey;
  final String currentPubkey;
  final int messageCount;
  final List<DmMessage> messages;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile?.picture;
    final nip05 = profile?.shortDisplayNip05;
    final followerCount = profile?.followerCount;
    final videoCount = profile?.videoCount;

    return ColoredBox(
      color: VineTheme.scrim15,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                imageUrl: imageUrl,
                name: displayName,
                placeholderSeed: otherPubkey,
                size: 96,
                contentOverride: isModerationAccount(otherPubkey)
                    ? const ModerationAvatar()
                    : null,
              ),
              const SizedBox(height: 32),
              Text(
                displayName,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.primaryText,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (nip05 != null && nip05.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  nip05,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (followerCount != null || videoCount != null) ...[
                const SizedBox(height: 4),
                _StatsLine(
                  followerCount: followerCount,
                  videoCount: videoCount,
                ),
              ],
              const SizedBox(height: 16),
              _OutlinedActionButton(
                label: context.l10n.messageRequestViewProfileButton,
                onTap: () => context.push(
                  OtherProfileScreen.pathForNpub(
                    NostrKeyUtils.encodePubKey(otherPubkey),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _MessageCountDescription(
                displayName: displayName,
                messageCount: messageCount,
              ),
              _InvitePreview(
                messages: messages,
                senderDisplayName: displayName,
                currentPubkey: currentPubkey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitePreview extends StatelessWidget {
  const _InvitePreview({
    required this.messages,
    required this.senderDisplayName,
    required this.currentPubkey,
  });

  final List<DmMessage> messages;
  final String senderDisplayName;
  final String currentPubkey;

  @override
  Widget build(BuildContext context) {
    ({DmMessage message, CollaboratorInvite invite})? inviteMessage;
    for (final message in messages) {
      final invite = CollaboratorInviteParser.parse(message);
      if (invite == null) continue;
      inviteMessage = (message: message, invite: invite);
      break;
    }
    if (inviteMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: CollaboratorInviteCard(
        invite: inviteMessage.invite,
        isSent:
            currentPubkey.isNotEmpty &&
            inviteMessage.message.senderPubkey == currentPubkey,
        senderDisplayName: senderDisplayName,
      ),
    );
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({this.followerCount, this.videoCount});

  final int? followerCount;
  final int? videoCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (followerCount != null) {
      parts.add(
        context.l10n.messageRequestFollowersCount(
          CountFormatter.formatCompact(followerCount!),
        ),
      );
    }
    if (videoCount != null) {
      parts.add(
        context.l10n.messageRequestVideosCount(
          CountFormatter.formatCompact(videoCount!),
        ),
      );
    }

    return Text(
      parts.join(' \u2022 '),
      style: VineTheme.bodySmallFont(
        color: context.vineColors.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _MessageCountDescription extends StatelessWidget {
  const _MessageCountDescription({
    required this.displayName,
    required this.messageCount,
  });

  final String displayName;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    final msgText = context.l10n.messageRequestMessageCount(messageCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.messageRequestWantsToMessageYou(displayName, msgText),
        style: VineTheme.bodyLargeFont(
          color: context.vineColors.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The bottom action strip, in the same place on every state of this screen so
/// decline does not move when the load resolves.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: children,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.participantPubkeys});

  final List<String> participantPubkeys;

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return _ActionBar(
      children: [
        _PrimaryActionButton(
          label: context.l10n.messageRequestViewMessagesButton,
          onTap: () {
            context.pushReplacementNamed(
              ConversationPage.routeName,
              pathParameters: {'id': conversationId},
              extra: participantPubkeys,
            );
          },
        ),
        const _DeclineAndRemoveButton(),
      ],
    );
  }
}

/// The one action that survives an unresolved counterparty: `declineRequest`
/// takes the conversation ID, not the participants.
class _DeclineAndRemoveButton extends StatelessWidget {
  const _DeclineAndRemoveButton();

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return _SecondaryActionButton(
      label: context.l10n.messageRequestDeclineAndRemoveButton,
      onTap: () async {
        await context.read<MessageRequestActionsCubit>().declineRequest(
          conversationId,
        );
        // safePop for the same reason as the app-bar back button above: this
        // route is deep-linkable, and a cold entry has nothing to pop (#6112).
        if (context.mounted) context.safePop(fallback: InboxPage.path);
      },
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                label,
                style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            border: Border.all(
              color: context.vineColors.outlineMuted,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: VineTheme.titleMediumFont(color: VineTheme.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              border: Border.all(
                color: context.vineColors.outlineMuted,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                label,
                style: VineTheme.titleMediumFont(color: VineTheme.primary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
