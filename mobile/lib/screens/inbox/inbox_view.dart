// ABOUTME: Main view for the inbox screen with Messages/Notifications toggle.
// ABOUTME: Shows conversation list (with following bar) or notifications
// ABOUTME: depending on the selected tab.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

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

/// Pushes the conversation page using the [GoRouter] instance directly,
/// bypassing the nested Navigator's context which cannot reach GoRouter.
void _pushConversation(
  GoRouter router,
  String conversationId,
  List<String> participantPubkeys,
) {
  Log.info(
    '🚀 Pushing conversation: id=$conversationId',
    name: 'InboxView',
    category: LogCategory.ui,
  );
  router.pushNamed(
    ConversationPage.routeName,
    pathParameters: {'id': conversationId},
    extra: participantPubkeys,
  );
}

/// Content for the Messages tab: following bar + conversation list or
/// empty state, with a FAB for composing new messages.
class _MessagesContent extends ConsumerWidget {
  const _MessagesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex ?? '';
    final router = ref.read(goRouterProvider);

    return BlocListener<ConversationListBloc, ConversationListState>(
      listenWhen: (prev, curr) =>
          curr.navigationTarget != null &&
          prev.navigationTarget != curr.navigationTarget,
      listener: (context, state) {
        final target = state.navigationTarget;
        if (target == null) return;

        Log.info(
          '🎯 Navigation target received: ${target.conversationId}',
          name: 'InboxView',
          category: LogCategory.ui,
        );

        // Clear the navigation target so it doesn't re-fire.
        context.read<ConversationListBloc>().add(
          const ConversationListNavigationConsumed(),
        );

        _pushConversation(
          router,
          target.conversationId,
          target.participantPubkeys,
        );
      },
      child: Column(
        children: [
          // Following users horizontal bar
          FollowingBar(
            onUserTapped: (pubkey) {
              Log.info(
                '👤 User tapped in following bar: $pubkey',
                name: 'InboxView',
                category: LogCategory.ui,
              );
              context.read<ConversationListBloc>().add(
                ConversationListNavigateToUser(pubkey),
              );
            },
          ),
          // Conversation list or empty state
          Expanded(
            child: _ConversationListContent(
              currentUserPubkey: currentPubkey,
              router: router,
            ),
          ),
        ],
      ),
    );
  }
}

/// Switches between loading, error, empty, and conversation list states.
class _ConversationListContent extends StatelessWidget {
  const _ConversationListContent({
    required this.currentUserPubkey,
    required this.router,
  });

  final String currentUserPubkey;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final status = context.select<ConversationListBloc, ConversationListStatus>(
      (bloc) => bloc.state.status,
    );

    return switch (status) {
      ConversationListStatus.initial ||
      ConversationListStatus.loading => const Center(
        child: CircularProgressIndicator(color: VineTheme.primary),
      ),
      ConversationListStatus.error => const InboxEmptyState(),
      ConversationListStatus.loaded => _ConversationList(
        currentUserPubkey: currentUserPubkey,
        router: router,
      ),
    };
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.currentUserPubkey,
    required this.router,
  });

  static const double _paginationThreshold = 200;

  final String currentUserPubkey;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final conversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.conversations,
        );
    final hasMore = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.hasMore,
    );

    if (conversations.isEmpty) return const InboxEmptyState();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasMore &&
            notification.metrics.extentAfter < _paginationThreshold &&
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
    Log.info(
      '💬 Conversation tapped: ${conversation.id}',
      name: 'InboxView',
      category: LogCategory.ui,
    );
    final otherPubkeys = conversation.participantPubkeys
        .where((pk) => pk != currentUserPubkey)
        .toList();

    _pushConversation(router, conversation.id, otherPubkeys);
  }
}
