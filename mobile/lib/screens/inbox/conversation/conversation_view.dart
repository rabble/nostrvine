// ABOUTME: Main view for a single DM conversation.
// ABOUTME: Displays grouped message bubbles and a bottom input bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/collaborator_invite_parser.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/divine_video_url.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart'
    show truncateNpubForDisplay;
import 'package:openvine/widgets/report_content_dialog.dart';

/// View for a single DM conversation.
///
/// Reads the [ConversationBloc] from the widget tree and renders messages
/// in a reverse-scrolling list with a bottom input bar.
///
/// Uses [BlocSelector] for child widgets that depend on specific slices of
/// [ConversationState] to avoid unnecessary rebuilds.
class ConversationView extends ConsumerStatefulWidget {
  const ConversationView({required this.participantPubkeys, super.key});

  /// Pubkeys of the other participants (excludes current user).
  final List<String> participantPubkeys;

  @override
  ConsumerState<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends ConsumerState<ConversationView> {
  Future<void> _onOptions(String otherPubkey, String displayName) async {
    if (otherPubkey.isEmpty) return;

    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);
    final followRepository = ref.read(followRepositoryProvider);
    final isBlocked = blocklistRepository.isBlocked(otherPubkey);
    final isFollowing = followRepository.isFollowing(otherPubkey);

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: MoreSheetContent(
        userIdHex: otherPubkey,
        displayName: displayName,
        isFollowing: isFollowing,
        isBlocked: isBlocked,
        showReport: true,
      ),
      children: const [],
    );

    if (!mounted || result == null) return;

    switch (result) {
      case MoreSheetResult.copy:
        final npub = NostrKeyUtils.encodePubKey(otherPubkey);
        await ClipboardUtils.copyPubkey(context, npub);
      case MoreSheetResult.unfollow:
        await followRepository.toggleFollow(otherPubkey);
      case MoreSheetResult.report:
        if (!mounted) return;
        await ReportContentDialog.showForUser(context, userPubkey: otherPubkey);
      case MoreSheetResult.blockConfirmed:
        await blocklistRepository.blockUser(
          otherPubkey,
          ourPubkey: ref.read(authServiceProvider).currentPublicKeyHex ?? '',
        );
        if (mounted) context.pop();
      case MoreSheetResult.unblockConfirmed:
        await blocklistRepository.unblockUser(otherPubkey);
      case MoreSheetResult.addToList:
        // addToList is not surfaced from this caller (showAddToList defaults
        // to false on MoreSheetContent here), so this branch is unreachable.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    // Resolve other participant's profile for the app bar + empty state
    final otherPubkey = widget.participantPubkeys.isNotEmpty
        ? widget.participantPubkeys.first
        : '';
    final profileAsync = ref.watch(fetchUserProfileProvider(otherPubkey));
    final profile = profileAsync.asData?.value;
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(otherPubkey);
    // Prefer the profile's NIP-05 / divine handle when set, otherwise
    // fall back to a truncated npub so the header always carries a
    // stable secondary identifier under the display name. Format
    // mirrors the profile header (`profile_header_widget.dart`): first
    // 16 chars of the npub + ellipsis.
    final profileHandle = profile?.handle;
    final handle = (profileHandle != null && profileHandle.isNotEmpty)
        ? profileHandle
        : (otherPubkey.isNotEmpty
              ? truncateNpubForDisplay(NostrKeyUtils.encodePubKey(otherPubkey))
              : '');

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: BlocListener<ConversationBloc, ConversationState>(
        listenWhen: (previous, current) =>
            previous.sendStatus != current.sendStatus &&
            (current.sendStatus == SendStatus.failed ||
                current.sendStatus == SendStatus.sentPartial),
        listener: _onSendOutcome,
        child: Column(
          children: [
            ConversationAppBar(
              displayName: displayName,
              handle: handle,
              onBack: () => context.pop(),
              onTitleTap: otherPubkey.isNotEmpty
                  ? () => context.push(
                      '${OtherProfileScreen.path}/${NostrKeyUtils.encodePubKey(otherPubkey)}',
                    )
                  : null,
              onOptions: () => _onOptions(otherPubkey, displayName),
            ),
            Expanded(
              // Force the messages card to fill the available width
              // regardless of its content. Without this, the empty /
              // loading state's SingleChildScrollView shrink-wraps the
              // ClipRRect down to the EmptyConversation column's
              // intrinsic width and the surface card renders as a
              // narrow strip; the ListView (with messages) is fine on
              // its own.
              child: SizedBox(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: ColoredBox(
                    color: VineTheme.surfaceContainerHigh,
                    // Tap anywhere in the messages area to dismiss the
                    // keyboard. Translucent hit behavior keeps bubble
                    // long-press and list-scroll gestures intact.
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: _ConversationContent(
                        currentPubkey: currentPubkey,
                        otherPubkey: otherPubkey,
                        displayName: displayName,
                        imageUrl: profile?.picture,
                        nip05: profile?.shortDisplayNip05,
                        onViewProfile: () {
                          final npub = NostrKeyUtils.encodePubKey(otherPubkey);
                          context.push('${OtherProfileScreen.path}/$npub');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _SendBar(participantPubkeys: widget.participantPubkeys),
          ],
        ),
      ),
    );
  }

  void _onSendOutcome(BuildContext context, ConversationState state) {
    final isPartial = state.sendStatus == SendStatus.sentPartial;
    // Pick the retry payload based on which outcome we're recovering
    // from: failed → full resend (content + recipients), sentPartial →
    // self-wrap-only recovery (rumor ids). Either side may be null on
    // an out-of-band emit; bail out rather than show a SnackBar that
    // does nothing.
    final partialSend = state.lastPartialSend;
    final failedSend = state.lastFailedSend;
    if (isPartial && partialSend == null) return;
    if (!isPartial && failedSend == null) return;

    final l10n = context.l10n;
    final message = isPartial
        ? l10n.dmSendPartialMessage
        : l10n.dmSendFailedMessage;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: l10n.dmSendFailedRetry,
          onPressed: () {
            final bloc = context.read<ConversationBloc>();
            if (isPartial) {
              bloc.add(
                ConversationSelfWrapRecoveryRequested(
                  rumorIds: partialSend!.rumorIds,
                ),
              );
            } else {
              bloc.add(
                ConversationMessageSent(
                  recipientPubkeys: failedSend!.recipientPubkeys,
                  content: failedSend.content,
                ),
              );
            }
          },
        ),
      ),
    );
    // Per `accessibility.md`, async visible state changes must announce
    // explicitly — relying on Material's default SnackBar semantics is
    // weaker than the written rule and not guaranteed across platforms.
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
}

/// Selects [SendStatus] from the bloc and renders [MessageInputBar].
class _SendBar extends StatelessWidget {
  const _SendBar({required this.participantPubkeys});

  final List<String> participantPubkeys;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ConversationBloc, ConversationState, SendStatus>(
      selector: (state) => state.sendStatus,
      builder: (context, sendStatus) {
        return MessageInputBar(
          isSending: sendStatus == SendStatus.sending,
          onSend: (text) {
            context.read<ConversationBloc>().add(
              ConversationMessageSent(
                recipientPubkeys: participantPubkeys,
                content: text,
              ),
            );
          },
        );
      },
    );
  }
}

/// Selects status and messages from the bloc and switches between loading,
/// error, empty, and message-list states.
class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.currentPubkey,
    required this.otherPubkey,
    required this.displayName,
    this.imageUrl,
    this.nip05,
    this.onViewProfile,
  });

  final String currentPubkey;
  final String otherPubkey;
  final String displayName;
  final String? imageUrl;
  final String? nip05;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ConversationBloc,
      ConversationState,
      ({ConversationStatus status, List<DmMessage> messages})
    >(
      selector: (state) =>
          (status: state.status, messages: state.displayedMessages),
      builder: (context, selected) {
        return switch (selected.status) {
          ConversationStatus.initial ||
          ConversationStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.primary),
          ),
          ConversationStatus.error => Center(
            child: Text(
              context.l10n.dmConversationLoadError,
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            ),
          ),
          ConversationStatus.loaded =>
            selected.messages.isEmpty
                ? EmptyConversation(
                    displayName: displayName,
                    pubkey: otherPubkey,
                    imageUrl: imageUrl,
                    nip05: nip05,
                    onViewProfile: onViewProfile,
                  )
                : _MessageList(
                    messages: selected.messages,
                    currentPubkey: currentPubkey,
                    senderDisplayName: displayName,
                  ),
        };
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentPubkey,
    required this.senderDisplayName,
  });

  final List<DmMessage> messages;
  final String currentPubkey;
  final String senderDisplayName;

  Future<void> _onMessageLongPress(
    BuildContext context,
    DmMessage message,
    bool isSent,
  ) async {
    final videoUrl = tryExtractDivineVideoUrl(message.content);
    final action = await MessageActionsSheet.show(
      context: context,
      isSent: isSent,
      isVideoShare: videoUrl != null,
    );
    if (action == null) return;
    if (!context.mounted) return;

    switch (action) {
      case MessageAction.copy:
        await ClipboardUtils.copy(context, message.content);
      case MessageAction.copyVideoUrl:
        // Defensive: the sheet only surfaces this action when videoUrl
        // is non-null, but guard against a future caller change.
        if (videoUrl == null) return;
        await ClipboardUtils.copy(context, videoUrl);
      case MessageAction.delete:
        context.read<ConversationBloc>().add(
          ConversationMessageDeleted(rumorId: message.id),
        );
      case MessageAction.report:
        if (!context.mounted) return;
        await ReportContentDialog.showForMessage(
          context,
          messageId: message.id,
          senderPubkey: message.senderPubkey,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      // bottom: 8 stacks with the newest bubble's own 8 px bottom padding
      // for a 16 px gap to the scroll-view edge.
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isSent = message.senderPubkey == currentPubkey;
        final invite = CollaboratorInviteParser.parse(message);
        if (invite != null) {
          return CollaboratorInviteCard(
            invite: invite,
            isSent: isSent,
            senderDisplayName: isSent ? null : senderDisplayName,
          );
        }

        // Suppress legacy NIP-04 invite plaintext duplicates (#3559).
        // Phase 1 stopped new sends from emitting this fallback, but
        // older app builds and cross-client senders can still produce
        // bubbles that read "Open diVine to review and accept" — useless
        // copy inside diVine, and the structured fields needed to render
        // an actionable card are not recoverable from plaintext alone.
        if (message.content.endsWith(
          CollaboratorInviteService.invitePlaintextSuffix,
        )) {
          return const SizedBox.shrink();
        }

        // Grouping: in a reversed list, index 0 is newest (bottom of screen).
        // "Above" = index + 1 (older), "below" = index - 1 (newer).
        final isFirstInGroup =
            index == messages.length - 1 ||
            messages[index + 1].senderPubkey != message.senderPubkey;
        final isLastInGroup =
            index == 0 ||
            messages[index - 1].senderPubkey != message.senderPubkey;

        MessageBubble buildBubble(DmDeliveryStatus status) => MessageBubble(
          message: message.content,
          timestamp: LocalizedTimeFormatter.formatMessageTime(
            context.l10n,
            message.createdAt,
            locale: Localizations.localeOf(context).toLanguageTag(),
            use24Hour: MediaQuery.of(context).alwaysUse24HourFormat,
          ),
          isSent: isSent,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          onLongPress: () => _onMessageLongPress(context, message, isSent),
          deliveryStatus: status,
        );

        // Per-row BlocSelector scopes rebuilds to just the indicator's
        // status — the bubble body stays cached across watchOutgoing
        // ticks affecting other rows. Received bubbles never read the
        // outgoing queue, so they bypass the selector and short-circuit
        // to `delivered`.
        if (!isSent) return buildBubble(DmDeliveryStatus.delivered);
        return BlocSelector<
          ConversationBloc,
          ConversationState,
          DmDeliveryStatus
        >(
          selector: (state) => state.statusFor(message.id),
          builder: (_, status) => buildBubble(status),
        );
      },
    );
  }
}
