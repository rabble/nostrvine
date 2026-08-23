// ABOUTME: View for the message request preview screen.
// ABOUTME: Shows sender profile info, message count, and accept/decline actions.

import 'dart:ui' show ImageFilter;

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
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// View for the message request preview screen.
///
/// Displays the sender's profile (avatar, name, NIP-05, stats), a
/// "View profile" button, the accept prompt, the blurred newest message,
/// and two action buttons: "Accept" (opens the thread) and
/// "Decline and remove". Blocking the sender lives on their profile.
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
      return _UnresolvedRequestScaffold(
        child: CircularProgressIndicator(
          color: context.vineColors.accentPositive,
        ),
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
        // Same one-entry-stack exposure as the unresolved states below:
        // `loading` is only the first frame of a cold deep-link entry, and
        // resolving to `loaded` does not put an entry behind it (#6112).
        onBackPressed: () => context.safePop(fallback: InboxPage.path),
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
            _ActionButtons(
              participantPubkeys: participantPubkeys,
              displayName: displayName,
            ),
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
              _AcceptPrompt(
                displayName: displayName,
                messageCount: messageCount,
              ),
              _BlurredMessagePreview(messages: messages),
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
        StringUtils.compactPlural(
          followerCount!,
          context.l10n.messageRequestFollowersCount,
        ),
      );
    }
    if (videoCount != null) {
      parts.add(
        StringUtils.compactPlural(
          videoCount!,
          context.l10n.messageRequestVideosCount,
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

/// Marks the start of a bold segment while parsing the localized prompt.
///
/// Private-use code points survive any translation's word order, so the
/// bold spans always land on the placeholder values wherever the locale
/// puts them. The same characters are stripped from the interpolated
/// values first, so sender-controlled display names cannot forge a
/// marker.
const _emphasisStart = '\u{E000}';

/// Marks the end of a bold segment. See [_emphasisStart].
const _emphasisEnd = '\u{E001}';

/// The redesign's "Accept 3 messages from **Name**?" line, with the
/// sender's name bolded in every locale (v2: the count stays plain).
class _AcceptPrompt extends StatelessWidget {
  const _AcceptPrompt({required this.displayName, required this.messageCount});

  final String displayName;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = context.vineColors.onSurfaceVariant;
    final baseStyle = VineTheme.bodyLargeFont(color: color);
    final boldStyle = VineTheme.titleMediumFont(color: color);

    String sanitize(String value) =>
        value.replaceAll(_emphasisStart, '').replaceAll(_emphasisEnd, '');

    final template = l10n.messageRequestAcceptPrompt(
      '$_emphasisStart${sanitize(displayName)}$_emphasisEnd',
      sanitize(l10n.messageRequestMessageCount(messageCount)),
    );

    final spans = <TextSpan>[];
    for (final (index, part) in template.split(_emphasisStart).indexed) {
      if (index == 0) {
        if (part.isNotEmpty) spans.add(TextSpan(text: part));
        continue;
      }
      final closeAt = part.indexOf(_emphasisEnd);
      spans.add(
        TextSpan(text: part.substring(0, closeAt), style: boldStyle),
      );
      final rest = part.substring(closeAt + _emphasisEnd.length);
      if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text.rich(
        TextSpan(style: baseStyle, children: spans),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The newest text message of the request, rendered blurred inside the
/// redesign's dark capsule: readable enough to prove there is a message,
/// unreadable until the request is accepted.
class _BlurredMessagePreview extends StatelessWidget {
  const _BlurredMessagePreview({required this.messages});

  final List<DmMessage> messages;

  /// Newest plain text message; collaborator invites render their own
  /// card below the prompt, and file messages carry no readable text.
  DmMessage? get _previewMessage {
    DmMessage? newest;
    for (final message in messages) {
      if (message.isFileMessage) continue;
      if (CollaboratorInviteParser.parse(message) != null) continue;
      if (message.content.trim().isEmpty) continue;
      if (newest == null || message.createdAt > newest.createdAt) {
        newest = message;
      }
    }
    return newest;
  }

  @override
  Widget build(BuildContext context) {
    final message = _previewMessage;
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 96),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        // Deliberately static: the capsule is a redaction scrim, dark in
        // both appearance modes, so its ink stays white.
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(56),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        // Hidden-by-design: the blur must not leak through a screen
        // reader, so the capsule is decorative until accepted.
        child: ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Text(
              message.content,
              style: VineTheme.bodyLargeFont(color: VineTheme.whiteText),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
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
  const _ActionButtons({
    required this.participantPubkeys,
    required this.displayName,
  });

  final List<String> participantPubkeys;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return _ActionBar(
      children: [
        // Accepting is just opening the thread: replying is still what
        // moves the conversation out of Requests, and blocking the sender
        // stays available from their profile (the v2 redesign removed the
        // Block button from this screen).
        _PrimaryActionButton(
          label: context.l10n.messageRequestAcceptButton,
          onTap: () {
            context.pushReplacementNamed(
              ConversationPage.routeName,
              pathParameters: {'id': conversationId},
              extra: participantPubkeys,
            );
          },
        ),
        _DeclineAndRemoveButton(displayName: displayName),
      ],
    );
  }
}

/// The one action that survives an unresolved counterparty: `declineRequest`
/// takes the conversation ID, not the participants.
///
/// [displayName] is null on the unresolved-counterparty states, where there is
/// no name to put in the confirmation snackbar; the decline still runs.
class _DeclineAndRemoveButton extends StatelessWidget {
  const _DeclineAndRemoveButton({this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return _SecondaryActionButton(
      label: context.l10n.messageRequestDeclineAndRemoveButton,
      onTap: () async {
        final cubit = context.read<MessageRequestActionsCubit>();
        if (cubit.state.status == MessageRequestActionsStatus.processing) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context);
        final errorText = context.l10n.commonSomethingWentWrong;
        final name = displayName;
        // A resolved counterparty names them in the confirmation; the
        // unresolved states have no name, so fall back to the name-free
        // "Removed conversation" rather than staying silent (#7881 review).
        final successText = name == null
            ? context.l10n.inboxRemovedConversation
            : context.l10n.messageRequestDeclinedSnackbar(name);
        final removed = await cubit.declineRequest(conversationId);
        if (!removed) {
          messenger.showSnackBar(
            DivineSnackbarContainer.snackBar(errorText, error: true),
          );
          return;
        }
        // safePop for the same reason as the app-bar back button above: this
        // route is deep-linkable, and a cold entry has nothing to pop (#6112).
        if (context.mounted) context.safePop(fallback: InboxPage.path);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(successText),
        );
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
              style: VineTheme.titleMediumFont(
                color: context.vineColors.accentPositive,
              ),
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
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.accentPositive,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
