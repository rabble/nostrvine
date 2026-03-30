// ABOUTME: Main view for the inbox screen with Messages/Notifications toggle.
// ABOUTME: Shows conversation list (with following bar) or notifications
// ABOUTME: depending on the selected tab.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/screens/inbox/widgets/conversation_actions_sheet.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_fab.dart';
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
  InboxTab _selectedTab = InboxTab.notifications;

  @override
  Widget build(BuildContext context) {
    // Re-filter conversation list when blocklist changes.
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<ConversationListBloc>().add(
          const ConversationListBlocklistChanged(),
        );
      }
    });

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
  BuildContext context,
  String conversationId,
  List<String> participantPubkeys,
) {
  Log.info(
    '🚀 Pushing conversation: id=$conversationId',
    name: 'InboxView',
    category: LogCategory.ui,
  );
  context.push(
    ConversationPage.pathForId(conversationId),
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
          context,
          target.conversationId,
          target.participantPubkeys,
        );
      },
      child: Stack(
        children: [
          Column(
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
                ),
              ),
            ],
          ),
          // FAB positioned bottom-right
          Positioned(
            right: 16,
            bottom: 16,
            child: InboxFab(
              onPressed: () => _onNewConversation(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onNewConversation(BuildContext context, WidgetRef ref) async {
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      Log.warning(
        'Cannot open new message: profileRepo is null',
        name: 'InboxView',
        category: LogCategory.ui,
      );
      return;
    }

    final selectedUser = await NewMessageSheet.show(
      context,
      profileRepository: profileRepo,
      followRepository: ref.read(followRepositoryProvider),
    );

    if (selectedUser == null || !context.mounted) return;

    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    if (currentPubkey == null) return;

    final conversationId = DmRepository.computeConversationId(
      [currentPubkey, selectedUser.pubkey],
    );
    _pushConversation(context, conversationId, [selectedUser.pubkey]);
  }
}

/// Switches between loading, error, empty, and conversation list states.
class _ConversationListContent extends StatelessWidget {
  const _ConversationListContent({
    required this.currentUserPubkey,
  });

  final String currentUserPubkey;

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
      ),
    };
  }
}

class _ConversationList extends ConsumerStatefulWidget {
  const _ConversationList({
    required this.currentUserPubkey,
  });

  final String currentUserPubkey;

  @override
  ConsumerState<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends ConsumerState<_ConversationList>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() {
    final bloc = context.read<ConversationListBloc>();
    return bloc.state.hasMore && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ConversationListBloc>().add(
      const ConversationListLoadMore(),
    );
  }

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.conversations,
        );
    final requestConversations = context
        .select<ConversationListBloc, List<DmConversation>>(
          (bloc) => bloc.state.requestConversations,
        );
    final hasMore = context.select<ConversationListBloc, bool>(
      (bloc) => bloc.state.hasMore,
    );

    final hasRequests = requestConversations.isNotEmpty;
    final bannerOffset = hasRequests ? 1 : 0;

    if (conversations.isEmpty && !hasRequests) return const InboxEmptyState();

    // Only requests, no followed conversations — show banner + empty state
    if (conversations.isEmpty && hasRequests) {
      return Column(
        children: [
          MessageRequestsBanner(
            requestCount: requestConversations.length,
            onTap: () => _openMessageRequests(context),
          ),
          const Expanded(child: InboxEmptyState()),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: conversations.length + bannerOffset + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasRequests && index == 0) {
          return MessageRequestsBanner(
            requestCount: requestConversations.length,
            onTap: () => _openMessageRequests(context),
          );
        }

        final conversationIndex = index - bannerOffset;

        if (conversationIndex == conversations.length) {
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

        final conversation = conversations[conversationIndex];
        return ConversationTile(
          conversation: conversation,
          currentUserPubkey: widget.currentUserPubkey,
          onTap: () => _onConversationTapped(context, conversation),
          onLongPress: () => _onConversationLongPressed(
            context,
            ref,
            conversation,
          ),
        );
      },
    );
  }

  void _openMessageRequests(BuildContext context) {
    context.pushNamed(MessageRequestsPage.routeName);
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
        .where((pk) => pk != widget.currentUserPubkey)
        .toList();

    _pushConversation(context, conversation.id, otherPubkeys);
  }

  Future<void> _onConversationLongPressed(
    BuildContext context,
    WidgetRef ref,
    DmConversation conversation,
  ) async {
    final otherPubkey = conversation.participantPubkeys.firstWhere(
      (pk) => pk != widget.currentUserPubkey,
      orElse: () => conversation.participantPubkeys.first,
    );

    final profile = await ref.read(
      fetchUserProfileProvider(otherPubkey).future,
    );
    final displayName = profile?.bestDisplayName ?? 'user';

    if (!context.mounted) return;

    final muteCubit = context.read<ConversationMuteCubit>();
    final isMuted = muteCubit.state.isMuted(conversation.id);

    final actionsCubit = context.read<ConversationActionsCubit>();
    final isBlocked = actionsCubit.isBlocked(otherPubkey);

    final action = await ConversationActionsSheet.show(
      context,
      displayName: displayName,
      isMuted: isMuted,
      isBlocked: isBlocked,
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case ConversationAction.toggleMute:
        final nowMuted = await muteCubit.toggleMute(conversation.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nowMuted ? 'Conversation muted' : 'Conversation unmuted',
              ),
            ),
          );
        }

      case ConversationAction.report:
        final reported = await actionsCubit.reportUser(otherPubkey);
        if (context.mounted && reported) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reported $displayName')),
          );
        }

      case ConversationAction.block:
        if (isBlocked) {
          actionsCubit.unblockUser(otherPubkey);
        } else {
          actionsCubit.blockUser(otherPubkey);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBlocked ? 'Unblocked $displayName' : 'Blocked $displayName',
              ),
            ),
          );
        }

      case ConversationAction.remove:
        if (!context.mounted) return;
        final confirmed = await _confirmRemove(context, displayName);
        if (confirmed && context.mounted) {
          final removed = await actionsCubit.removeConversation(
            conversation.id,
          );
          if (context.mounted && removed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed conversation')),
            );
          }
        }
    }
  }

  Future<bool> _confirmRemove(
    BuildContext context,
    String displayName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          'Remove conversation?',
          style: VineTheme.titleLargeFont(),
        ),
        content: Text(
          'This will delete your conversation with $displayName. '
          'This action cannot be undone.',
          style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
