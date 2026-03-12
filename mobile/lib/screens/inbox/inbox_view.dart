// ABOUTME: Main view for the inbox screen with Messages/Notifications toggle.
// ABOUTME: Shows conversation list (with following bar) or notifications
// ABOUTME: depending on the selected tab.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/widgets/widgets.dart';
import 'package:openvine/screens/notifications_screen.dart';

/// Main inbox view containing the Messages/Notifications segmented toggle
/// and the corresponding content for each tab.
class InboxView extends ConsumerStatefulWidget {
  const InboxView({super.key});

  @override
  ConsumerState<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends ConsumerState<InboxView> {
  InboxTab _selectedTab = InboxTab.messages;

  @override
  Widget build(BuildContext context) {
    // Watch notification unread count for the badge.
    final notificationCount = ref.watch(relayNotificationUnreadCountProvider);

    return ColoredBox(
      color: VineTheme.surfaceBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Segmented toggle (Messages / Notifications)
            InboxSegmentedToggle(
              selected: _selectedTab,
              onChanged: (tab) => setState(() => _selectedTab = tab),
              notificationCount: notificationCount,
            ),
            // Content area with rounded top corners
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: ColoredBox(
                  color: VineTheme.surfaceContainerHigh,
                  child: _selectedTab == InboxTab.messages
                      ? const _MessagesContent()
                      : const NotificationsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content for the Messages tab: following bar + conversation list or
/// empty state, with a FAB for composing new messages.
class _MessagesContent extends ConsumerWidget {
  const _MessagesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.watch<ConversationListBloc>().state;
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';

    return Stack(
      children: [
        Column(
          children: [
            // Following users horizontal bar
            FollowingBar(
              onUserTapped: (pubkey) => _onFollowingUserTapped(
                context,
                ref,
                pubkey,
              ),
            ),
            // Conversation list or empty state
            Expanded(
              child: _ConversationListContent(
                state: state,
                currentUserPubkey: currentPubkey,
              ),
            ),
          ],
        ),
        // FAB positioned bottom-right
        Positioned(
          right: 16,
          bottom: 16,
          child: InboxFab(onPressed: () => _onNewConversation(context, ref)),
        ),
      ],
    );
  }

  void _onFollowingUserTapped(
    BuildContext context,
    WidgetRef ref,
    String pubkey,
  ) {
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    if (currentPubkey == null) return;

    final participantPubkeys = [pubkey];
    final conversationId = DmRepository.computeConversationId(
      [currentPubkey, pubkey],
    );

    _pushConversation(context, conversationId, participantPubkeys);
  }

  void _onNewConversation(BuildContext context, WidgetRef ref) {
    // TODO(dm): Open user-picker then navigate to conversation.
  }

  void _pushConversation(
    BuildContext context,
    String conversationId,
    List<String> participantPubkeys,
  ) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => ConversationPage(
          conversationId: conversationId,
          participantPubkeys: participantPubkeys,
        ),
      ),
    );
  }
}

/// Switches between loading, error, empty, and conversation list states.
class _ConversationListContent extends StatelessWidget {
  const _ConversationListContent({
    required this.state,
    required this.currentUserPubkey,
  });

  final ConversationListState state;
  final String currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      ConversationListStatus.initial ||
      ConversationListStatus.loading => const Center(
        child: CircularProgressIndicator(color: VineTheme.primary),
      ),
      ConversationListStatus.error => const InboxEmptyState(),
      ConversationListStatus.loaded =>
        state.conversations.isEmpty
            ? const InboxEmptyState()
            : _ConversationList(
                conversations: state.conversations,
                currentUserPubkey: currentUserPubkey,
                hasMore: state.hasMore,
              ),
    };
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.currentUserPubkey,
    required this.hasMore,
  });

  final List<DmConversation> conversations;
  final String currentUserPubkey;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            notification.metrics.extentAfter < 200 &&
            notification is ScrollUpdateNotification) {
          context.read<ConversationListBloc>().add(
            const ConversationListLoadMore(),
          );
        }
        return false;
      },
      child: ListView.builder(
        itemCount: conversations.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == conversations.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: VineTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          }

          final conversation = conversations[index];
          return ConversationTile(
            conversation: conversation,
            currentUserPubkey: currentUserPubkey,
            onTap: () => _onConversationTapped(context, conversation),
          );
        },
      ),
    );
  }

  void _onConversationTapped(
    BuildContext context,
    DmConversation conversation,
  ) {
    final otherPubkeys = conversation.participantPubkeys
        .where((pk) => pk != currentUserPubkey)
        .toList();

    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => ConversationPage(
          conversationId: conversation.id,
          participantPubkeys: otherPubkeys,
        ),
      ),
    );
  }
}
