// ABOUTME: Messages tab content for the inbox screen
// ABOUTME: Shows a people bar at top and conversation list below
// ABOUTME: Includes a FAB for composing new messages
// ABOUTME: Wired to ConversationListBloc for real-time DM data

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/inbox/conversation_screen.dart'
    show ConversationPage;
import 'package:openvine/screens/inbox/new_message_sheet.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/utils/time_formatter.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/inbox/conversation_list_item.dart';
import 'package:openvine/widgets/inbox/people_bar.dart';

/// The messages tab content within the inbox screen.
///
/// Displays a [PeopleBar] at the top for recent conversation users,
/// and a scrollable conversation list below. When empty, shows a
/// centered empty state with a subtitle. A floating action button
/// opens a [NewMessageSheet] to compose a new message.
///
/// Uses [ConversationListBloc] for reactive conversation data from
/// the DM repository. Falls back to empty state when unauthenticated.
class MessagesTab extends ConsumerWidget {
  /// Creates a [MessagesTab].
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dmRepository = ref.watch(dmRepositoryProvider);

    return BlocProvider(
      create: (_) =>
          ConversationListBloc(dmRepository: dmRepository)
            ..add(const ConversationListStarted()),
      child: const _MessagesTabBody(),
    );
  }

  static Future<void> _openNewMessage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    Log.info(
      'User tapped new message FAB',
      name: 'MessagesTab',
      category: LogCategory.ui,
    );

    final dmRepository = ref.read(dmRepositoryProvider);

    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      Log.warning(
        'Cannot open new message: profileRepo is null',
        name: 'MessagesTab',
        category: LogCategory.ui,
      );
      return;
    }

    final selectedUser = await NewMessageSheet.show(
      context,
      profileRepository: profileRepo,
      followRepository: ref.read(followRepositoryProvider),
    );
    if (selectedUser != null && context.mounted) {
      await ConversationPage.open(
        context,
        dmRepository: dmRepository,
        recipientProfile: selectedUser,
      );
    }
  }
}

class _MessagesTabBody extends ConsumerWidget {
  const _MessagesTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<ConversationListBloc, ConversationListState>(
      builder: (context, state) {
        final hasConversations =
            state.status == ConversationListStatus.loaded &&
            state.conversations.isNotEmpty;

        final Widget body;
        if (hasConversations) {
          body = _ConversationsList(conversations: state.conversations);
        } else {
          body = const _EmptyMessagesState();
        }

        return Stack(
          children: [
            Column(
              children: [
                if (hasConversations)
                  _ReactivePeopleBar(
                    conversations: state.conversations,
                  ),
                Expanded(child: body),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 20,
              child: _NewMessageFab(
                onTap: () => MessagesTab._openNewMessage(context, ref),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// People bar derived from conversation partners
// ---------------------------------------------------------------------------

class _ReactivePeopleBar extends ConsumerWidget {
  const _ReactivePeopleBar({required this.conversations});

  final List<DmConversation> conversations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPubkey = ref.read(dmRepositoryProvider).userPubkey;
    final partnerPubkeys = _extractRecentPartners(userPubkey);

    final users = partnerPubkeys.map((pubkey) {
      final profileAsync = ref.watch(
        userProfileReactiveProvider(pubkey),
      );
      final profile = profileAsync.value;
      final isMod = pubkey == ModerationLabelService.divineModerationPubkeyHex;
      return PeopleBarUser(
        displayName: isMod
            ? 'Divine Moderation Team'
            : profile?.bestDisplayName ??
                  UserProfile.defaultDisplayNameFor(pubkey),
        avatarUrl: profile?.picture,
        pubkey: pubkey,
      );
    }).toList();

    return PeopleBar(
      users: users,
      onUserTap: (user) => _onUserTap(context, ref, user),
    );
  }

  List<String> _extractRecentPartners(String userPubkey) {
    final seen = <String>{};
    final partners = <String>[];
    for (final conv in conversations) {
      if (conv.isGroup) continue;
      final other = conv.participantPubkeys.firstWhere(
        (p) => p != userPubkey,
        orElse: () => conv.participantPubkeys.first,
      );
      if (seen.add(other)) {
        partners.add(other);
      }
    }
    return partners;
  }

  void _onUserTap(BuildContext context, WidgetRef ref, PeopleBarUser user) {
    if (user.pubkey == null) return;
    final dmRepo = ref.read(dmRepositoryProvider);
    final profileAsync = ref.read(
      userProfileReactiveProvider(user.pubkey!),
    );
    final profile = profileAsync.value;
    final recipientProfile =
        profile ??
        UserProfile(
          pubkey: user.pubkey!,
          rawData: const {},
          createdAt: DateTime.now(),
          eventId: '',
        );
    ConversationPage.open(
      context,
      dmRepository: dmRepo,
      recipientProfile: recipientProfile,
    );
  }
}

// ---------------------------------------------------------------------------
// Conversations list (populated state)
// ---------------------------------------------------------------------------

class _ConversationsList extends ConsumerWidget {
  const _ConversationsList({required this.conversations});

  final List<DmConversation> conversations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPubkey = ref.read(dmRepositoryProvider).userPubkey;

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _ConversationItemWidget(
          conversation: conversation,
          userPubkey: userPubkey,
        );
      },
    );
  }
}

class _ConversationItemWidget extends ConsumerWidget {
  const _ConversationItemWidget({
    required this.conversation,
    required this.userPubkey,
  });

  final DmConversation conversation;
  final String userPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherPubkey = _otherParticipant;
    final profileAsync = ref.watch(
      userProfileReactiveProvider(otherPubkey),
    );
    final profile = profileAsync.value;

    final isModerationTeam =
        otherPubkey == ModerationLabelService.divineModerationPubkeyHex;
    final displayName =
        conversation.subject ??
        (isModerationTeam ? 'Divine Moderation Team' : null) ??
        profile?.bestDisplayName ??
        (conversation.isGroup
            ? '${conversation.participantPubkeys.length} people'
            : UserProfile.defaultDisplayNameFor(otherPubkey));

    final dmRepo = ref.read(dmRepositoryProvider);

    return ConversationListItem(
      displayName: displayName,
      lastMessage: conversation.lastMessageContent ?? '',
      timestamp: conversation.lastMessageTimestamp != null
          ? TimeFormatter.formatRelative(
              conversation.lastMessageTimestamp!,
            )
          : '',
      avatarUrl: profile?.picture,
      isUnread: !conversation.isRead,
      isGroupChat: conversation.isGroup,
      participantCount: conversation.participantPubkeys.length,
      onTap: () => _onTap(context, profile, dmRepo),
    );
  }

  String get _otherParticipant {
    return conversation.participantPubkeys.firstWhere(
      (p) => p != userPubkey,
      orElse: () => conversation.participantPubkeys.first,
    );
  }

  void _onTap(
    BuildContext context,
    UserProfile? profile,
    DmRepository dmRepo,
  ) {
    if (conversation.isGroup) {
      ConversationPage.openGroup(
        context,
        dmRepository: dmRepo,
        participantCount: conversation.participantPubkeys.length,
        participantNames: conversation.participantPubkeys,
      );
    } else {
      final recipientProfile =
          profile ??
          UserProfile(
            pubkey: _otherParticipant,
            rawData: const {},
            createdAt: DateTime.now(),
            eventId: '',
          );
      ConversationPage.open(
        context,
        dmRepository: dmRepo,
        recipientProfile: recipientProfile,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyMessagesState extends StatelessWidget {
  const _EmptyMessagesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No messages yet',
              textAlign: TextAlign.center,
              style: VineTheme.titleMediumFont(
                fontSize: 16,
                height: 24 / 16,
                color: VineTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "That + button won't bite.",
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compose FAB
// ---------------------------------------------------------------------------

class _NewMessageFab extends StatelessWidget {
  const _NewMessageFab({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Compose new message',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: VineTheme.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: VineTheme.onPrimary, size: 24),
        ),
      ),
    );
  }
}
