// ABOUTME: Main view for a single DM conversation.
// ABOUTME: Displays grouped message bubbles and a bottom input bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/widgets/widgets.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:time_formatter/time_formatter.dart';

/// View for a single DM conversation.
///
/// Reads the [ConversationBloc] from the widget tree and renders messages
/// in a reverse-scrolling list with a bottom input bar.
class ConversationView extends ConsumerWidget {
  const ConversationView({
    required this.participantPubkeys,
    super.key,
  });

  /// Pubkeys of the other participants (excludes current user).
  final List<String> participantPubkeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloc = context.watch<ConversationBloc>();
    final state = bloc.state;
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    // Resolve other participant's profile for the app bar + empty state
    final otherPubkey = participantPubkeys.isNotEmpty
        ? participantPubkeys.first
        : '';
    final profileAsync = ref.watch(fetchUserProfileProvider(otherPubkey));
    final profile = profileAsync.asData?.value;
    final displayName =
        profile?.displayName ??
        profile?.name ??
        NostrKeyUtils.truncateNpub(otherPubkey);
    final handle = _resolveHandle(profile);

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: Column(
        children: [
          // Custom app bar
          ConversationAppBar(
            displayName: displayName,
            handle: handle,
            onBack: () => context.pop(),
            onOptions: () {
              // TODO(dm): Show conversation options (mute, block, etc.)
            },
          ),
          // Message list
          Expanded(
            child: _ConversationContent(
              state: state,
              currentPubkey: currentPubkey,
              displayName: displayName,
              imageUrl: profile?.picture,
              nip05: profile?.nip05,
              onViewProfile: () {
                final npub = NostrKeyUtils.encodePubKey(otherPubkey);
                context.push(
                  '${OtherProfileScreen.path}/$npub',
                );
              },
            ),
          ),
          // Input bar
          MessageInputBar(
            isSending: state.sendStatus == SendStatus.sending,
            onSend: (text) {
              bloc.add(
                ConversationMessageSent(
                  recipientPubkeys: participantPubkeys,
                  content: text,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _resolveHandle(UserProfile? profile) {
    final nip05 = profile?.nip05;
    if (nip05 != null && nip05.isNotEmpty) return '@$nip05';
    final name = profile?.name;
    if (name != null && name.isNotEmpty) return '@$name';
    return '';
  }
}

/// Switches between loading, error, empty, and message-list states.
class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.state,
    required this.currentPubkey,
    required this.displayName,
    this.imageUrl,
    this.nip05,
    this.onViewProfile,
  });

  final ConversationState state;
  final String currentPubkey;
  final String displayName;
  final String? imageUrl;
  final String? nip05;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      ConversationStatus.initial || ConversationStatus.loading => const Center(
        child: CircularProgressIndicator(color: VineTheme.primary),
      ),
      ConversationStatus.error => Center(
        child: Text(
          'Could not load messages',
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
        ),
      ),
      ConversationStatus.loaded =>
        state.messages.isEmpty
            ? EmptyConversation(
                displayName: displayName,
                imageUrl: imageUrl,
                nip05: nip05,
                onViewProfile: onViewProfile,
              )
            : _MessageList(
                messages: state.messages,
                currentPubkey: currentPubkey,
              ),
    };
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.currentPubkey,
  });

  final List<DmMessage> messages;
  final String currentPubkey;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isSent = message.senderPubkey == currentPubkey;

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
          timestamp: TimeFormatter.formatMessageTime(message.createdAt),
          isSent: isSent,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
        );
      },
    );
  }
}
