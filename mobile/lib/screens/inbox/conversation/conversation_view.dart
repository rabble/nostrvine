// ABOUTME: Main view for a single DM conversation.
// ABOUTME: Displays grouped message bubbles and a bottom input bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/dm_reply_context.dart';
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

    // Reactors to hide from the reaction pill + who-reacted sheet: the
    // repository's canonical feed-hide set (blocked ∪ muted ∪ muted-by ∪
    // blocked-by), the same union `shouldFilterFromFeeds` enforces app-wide.
    // Watching blocklistVersionProvider rebuilds this view — re-reading the
    // set and re-passing it to every ReactionsRow — on any block/unblock/mute
    // change while the thread is open.
    ref.watch(blocklistVersionProvider);
    final blockedReactors = ref
        .read(contentBlocklistRepositoryProvider)
        .feedHiddenPubkeys;

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
            // Wrap the AppBar + messages region in a Listener so any
            // tap above the input bar — back button, title, options,
            // dead space in the messages area, a MessageBubble —
            // dismisses the keyboard before any navigation or sheet
            // animation begins. The `_SendBar` is intentionally
            // OUTSIDE this Listener: wrapping the input would
            // `unfocus` on pointer-down and race with the TextField's
            // own focus request, producing a re-focus flicker on
            // every input tap.
            //
            // `Listener` catches pointer-downs without entering the
            // gesture arena, so descendant tap/long-press recognizers
            // (MessageBubble.onLongPress, ConversationAppBar's three
            // buttons) still resolve normally afterwards. Matches the
            // pattern shipped in `comments_list.dart`.
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
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
                            child: _ConversationContent(
                              currentPubkey: currentPubkey,
                              otherPubkey: otherPubkey,
                              participantPubkeys: widget.participantPubkeys,
                              blockedPubkeys: blockedReactors,
                              displayName: displayName,
                              imageUrl: profile?.picture,
                              nip05: profile?.shortDisplayNip05,
                              onViewProfile: () {
                                final npub = NostrKeyUtils.encodePubKey(
                                  otherPubkey,
                                );
                                context.push(
                                  '${OtherProfileScreen.path}/$npub',
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
    required this.participantPubkeys,
    required this.blockedPubkeys,
    required this.displayName,
    this.imageUrl,
    this.nip05,
    this.onViewProfile,
  });

  final String currentPubkey;
  final String otherPubkey;
  final List<String> participantPubkeys;

  /// Effective block/mute set; reactions from these pubkeys are hidden.
  final Set<String> blockedPubkeys;
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
                    participantPubkeys: participantPubkeys,
                    blockedPubkeys: blockedPubkeys,
                    senderDisplayName: displayName,
                  ),
        };
      },
    );
  }
}

/// The video reference to render as a compact quoted preview above a reply's
/// text: the parent shared-reel's video (resolved via `replyToId` from
/// [messagesById]), falling back to the reply's own self-carried citation when
/// the parent isn't in the local store (cross-device / reinstall). Returns
/// `null` when [message] is not a reply.
@visibleForTesting
DmSharedVideoRef? resolveQuotedVideoRef(
  DmMessage message,
  Map<String, DmMessage> messagesById,
) {
  final replyToId = message.replyToId;
  if (replyToId == null) return null;
  return messagesById[replyToId]?.sharedVideoRef ?? message.sharedVideoRef;
}

/// The video reference to render as [message]'s own full share card: its
/// `sharedVideoRef` only when it is NOT a reply. A reply that self-carries a
/// citation renders a compact quote (via [resolveQuotedVideoRef]) instead of
/// the full card, so this returns `null` for replies to keep the two paths
/// mutually exclusive.
@visibleForTesting
DmSharedVideoRef? resolveOwnShareVideoRef(DmMessage message) =>
    message.replyToId == null ? message.sharedVideoRef : null;

/// The emoji a double-tap-to-like publishes: the ❤️ that heads the DM quick
/// reaction row ([kDefaultDmReactionEmojis]), reused verbatim so a double-tap
/// and a picker ❤️ collapse to one reaction instead of two distinct rows
/// (there is no emoji normalization on the reaction path).
final String _doubleTapLikeEmoji = kDefaultDmReactionEmojis.first;

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentPubkey,
    required this.participantPubkeys,
    required this.blockedPubkeys,
    required this.senderDisplayName,
  });

  final List<DmMessage> messages;
  final String currentPubkey;
  final List<String> participantPubkeys;

  /// Effective block/mute set; reactions from these pubkeys are hidden.
  final Set<String> blockedPubkeys;
  final String senderDisplayName;

  Future<void> _onMessageLongPress(
    BuildContext context,
    DmMessage message,
    bool isSent,
    DmDeliveryStatus deliveryStatus,
  ) async {
    final videoUrl = tryExtractDivineVideoUrl(message.content);
    // Reaction picker hidden on failed-send own DMs — reacting to a
    // message the recipient never received is meaningless (#4633 round 25).
    final showPicker = !(isSent && deliveryStatus == DmDeliveryStatus.failed);
    final result = await ReactionPickerOverlay.show(
      context: context,
      isSent: isSent,
      isVideoShare: videoUrl != null,
      showPicker: showPicker,
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (result.emoji != null) {
      _toggleReaction(context, message, result.emoji!);
      return;
    }
    if (result.openFullPicker) {
      final emoji = await FullReactionEmojiPickerSheet.show(context: context);
      if (emoji == null || !context.mounted) return;
      _toggleReaction(context, message, emoji);
      return;
    }
    final action = result.action;
    if (action == null) return;
    switch (action) {
      case MessageAction.copy:
        await ClipboardUtils.copy(context, message.content);
      case MessageAction.copyVideoUrl:
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

  void _toggleReaction(BuildContext context, DmMessage message, String emoji) {
    context.read<ConversationReactionsCubit>().add(
      ConversationReactionToggled(
        conversationId: message.conversationId,
        messageId: message.id,
        messageAuthorPubkey: message.senderPubkey,
        emoji: emoji,
      ),
    );
  }

  /// Double-tap-to-like (Instagram-style). Fires a light haptic and adds a ❤️
  /// via [ConversationReactionSet] (add-only: a repeat double-tap never
  /// un-likes — removal stays on the long-press picker). The chip itself
  /// animates in via [ReactionsRow]. Dedup lives in the cubit's
  /// [ConversationReactionSet] handler — including the pre-persist optimistic
  /// window — so a rapid double-tap burst can't fan out duplicate gift-wrapped
  /// reactions; the UI just dispatches.
  void _likeOnDoubleTap(BuildContext context, DmMessage message) {
    HapticFeedback.lightImpact();
    context.read<ConversationReactionsCubit>().add(
      ConversationReactionSet(
        conversationId: message.conversationId,
        messageId: message.id,
        messageAuthorPubkey: message.senderPubkey,
        emoji: _doubleTapLikeEmoji,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Index built once per render pass so a reply bubble can resolve its
    // parent shared-reel message (and thus the quoted video) in O(1).
    final messagesById = {for (final m in messages) m.id: m};
    return ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

        // participantPubkeys excludes self, so a length > 1 is a group.
        final isGroup = participantPubkeys.length > 1;

        // Context for the in-player reply/reaction bar when this bubble's
        // shared reel is opened. Carries the reel's structured video ref so a
        // text reply can self-carry the NIP-18 `q` citation (cross-device /
        // other-client durability).
        final dmReplyContext = DmReplyContext(
          conversationId: message.conversationId,
          participantPubkeys: participantPubkeys,
          isGroup: isGroup,
          sharedReelMessageId: message.id,
          messageAuthorPubkey: message.senderPubkey,
          hintName: senderDisplayName,
          isOwnMessage: isSent,
          sharedVideoRef: message.sharedVideoRef,
        );

        // A non-reply share renders the full card; a reply that references a
        // video renders a compact quote above its text (mutually exclusive).
        final ownShareVideoRef = resolveOwnShareVideoRef(message);
        final quotedVideoRef = resolveQuotedVideoRef(message, messagesById);

        Widget buildBubbleWithReactions(DmDeliveryStatus status) {
          final bubble = MessageBubble(
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
            onLongPress: () =>
                _onMessageLongPress(context, message, isSent, status),
            // Double-tap-to-like, hidden on failed own sends to mirror the
            // long-press picker guard (reacting to a message the recipient
            // never received is meaningless).
            onDoubleTap: isSent && status == DmDeliveryStatus.failed
                ? null
                : () => _likeOnDoubleTap(context, message),
            deliveryStatus: status,
            dmReplyContext: dmReplyContext,
            sharedVideoRef: ownShareVideoRef,
            quotedVideoRef: quotedVideoRef,
          );
          return Column(
            crossAxisAlignment: isSent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              bubble,
              // One combined reaction pill (distinct emoji glyphs + reactor
              // avatars) for both 1:1 and group; tapping it opens the
              // "who reacted" sheet.
              ReactionsRow(
                conversationId: message.conversationId,
                messageId: message.id,
                messageAuthorPubkey: message.senderPubkey,
                ownerPubkey: currentPubkey,
                isSentByMe: isSent,
                blockedPubkeys: blockedPubkeys,
              ),
            ],
          );
        }

        // Per-row BlocSelector scopes rebuilds to just the indicator's
        // status — the bubble body stays cached across watchOutgoing
        // ticks affecting other rows. Received bubbles never read the
        // outgoing queue, so they bypass the selector and short-circuit
        // to `delivered`.
        if (!isSent) {
          return buildBubbleWithReactions(DmDeliveryStatus.delivered);
        }
        return BlocSelector<
          ConversationBloc,
          ConversationState,
          DmDeliveryStatus
        >(
          selector: (state) => state.statusFor(message.id),
          builder: (_, status) => buildBubbleWithReactions(status),
        );
      },
    );
  }
}
