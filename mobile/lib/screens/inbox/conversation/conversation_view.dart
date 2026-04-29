// ABOUTME: Main view for a single DM conversation.
// ABOUTME: Displays grouped message bubbles and a bottom input bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
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
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';

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
      case MoreSheetResult.blockConfirmed:
        await blocklistRepository.blockUser(
          otherPubkey,
          ourPubkey: ref.read(authServiceProvider).currentPublicKeyHex ?? '',
        );
        if (mounted) context.pop();
      case MoreSheetResult.unblockConfirmed:
        await blocklistRepository.unblockUser(otherPubkey);
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
    final handle = profile?.handle ?? '';

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: Column(
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
            child: _ConversationContent(
              currentPubkey: currentPubkey,
              otherPubkey: otherPubkey,
              displayName: displayName,
              imageUrl: profile?.picture,
              nip05: profile?.displayNip05,
              onViewProfile: () {
                final npub = NostrKeyUtils.encodePubKey(otherPubkey);
                context.push('${OtherProfileScreen.path}/$npub');
              },
            ),
          ),
          _SendBar(participantPubkeys: widget.participantPubkeys),
        ],
      ),
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
      selector: (state) => (status: state.status, messages: state.messages),
      builder: (context, selected) {
        return switch (selected.status) {
          ConversationStatus.initial ||
          ConversationStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.primary),
          ),
          ConversationStatus.error => Center(
            child: Text(
              'Could not load messages',
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
                  ),
        };
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.currentPubkey});

  final List<DmMessage> messages;
  final String currentPubkey;

  Future<void> _onMessageLongPress(
    BuildContext context,
    DmMessage message,
    bool isSent,
  ) async {
    final action = await MessageActionsSheet.show(
      context: context,
      isSent: isSent,
    );
    if (action == null) return;
    if (!context.mounted) return;

    switch (action) {
      case MessageAction.copy:
        await ClipboardUtils.copy(context, message.content);
      case MessageAction.delete:
        context.read<ConversationBloc>().add(
          ConversationMessageDeleted(rumorId: message.id),
        );
      case MessageAction.report:
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => ReportMessageDialog(
            messageId: message.id,
            senderPubkey: message.senderPubkey,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isSent = message.senderPubkey == currentPubkey;
        final invite = CollaboratorInviteParser.parse(message);
        if (invite != null) {
          return CollaboratorInviteCard(invite: invite, isSent: isSent);
        }

        // Grouping: in a reversed list, index 0 is newest (bottom of screen).
        // "Above" = index + 1 (older), "below" = index - 1 (newer).
        final isFirstInGroup =
            index == messages.length - 1 ||
            messages[index + 1].senderPubkey != message.senderPubkey;
        final isLastInGroup =
            index == 0 ||
            messages[index - 1].senderPubkey != message.senderPubkey;

        return MessageBubble(
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
        );
      },
    );
  }
}
