// ABOUTME: Chat conversation screen for NIP-17 direct messaging
// ABOUTME: Supports both 1:1 and group conversations
// ABOUTME: Page/View pattern: ConversationPage provides BLoC,
// ABOUTME: ConversationView renders the UI

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/thumbnail_api_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/time_formatter.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page wrapper that provides [ConversationBloc] to [ConversationView].
///
/// Handles dependency resolution (DmRepository, conversation ID) and
/// creates the BLoC. Delegates all UI rendering to [ConversationView].
class ConversationPage extends StatelessWidget {
  /// Creates a 1:1 [ConversationPage].
  const ConversationPage({
    required this.dmRepository,
    required this.recipientProfile,
    super.key,
  }) : isGroup = false,
       participantCount = 1,
       participantNames = const [];

  /// Creates a group [ConversationPage].
  const ConversationPage.group({
    required this.dmRepository,
    required this.participantCount,
    required this.participantNames,
    super.key,
  }) : isGroup = true,
       recipientProfile = null;

  /// The DM repository for sending/receiving messages.
  final DmRepository dmRepository;

  /// The user profile of the conversation partner (1:1 only).
  final UserProfile? recipientProfile;

  /// Whether this is a group conversation.
  final bool isGroup;

  /// Number of participants in the group.
  final int participantCount;

  /// Display names of group participants.
  final List<String> participantNames;

  /// Navigates to a 1:1 conversation screen.
  ///
  /// Uses the root navigator so the conversation is rendered full-screen,
  /// outside the app shell (no "Inbox" header or bottom nav).
  static Future<void> open(
    BuildContext context, {
    required DmRepository dmRepository,
    required UserProfile recipientProfile,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationPage(
          dmRepository: dmRepository,
          recipientProfile: recipientProfile,
        ),
      ),
    );
  }

  /// Navigates to a group conversation screen.
  ///
  /// Uses the root navigator so the conversation is rendered full-screen,
  /// outside the app shell (no "Inbox" header or bottom nav).
  static Future<void> openGroup(
    BuildContext context, {
    required DmRepository dmRepository,
    required int participantCount,
    required List<String> participantNames,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationPage.group(
          dmRepository: dmRepository,
          participantCount: participantCount,
          participantNames: participantNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPubkey = dmRepository.userPubkey;
    String? conversationId;

    if (!isGroup && recipientProfile != null) {
      final participants = [userPubkey, recipientProfile!.pubkey]..sort();
      conversationId = DmRepository.computeConversationId(participants);
    }

    if (conversationId == null) {
      return ConversationView(
        isGroup: isGroup,
        recipientProfile: recipientProfile,
        participantCount: participantCount,
        participantNames: participantNames,
        userPubkey: userPubkey,
      );
    }

    return BlocProvider(
      create: (_) => ConversationBloc(
        dmRepository: dmRepository,
        conversationId: conversationId!,
      )..add(const ConversationStarted()),
      child: ConversationView(
        isGroup: isGroup,
        recipientProfile: recipientProfile,
        participantCount: participantCount,
        participantNames: participantNames,
        userPubkey: userPubkey,
      ),
    );
  }
}

/// The UI for a DM conversation.
///
/// Renders the header, message list, and input bar. When a
/// [ConversationBloc] is available in the widget tree, messages are
/// loaded reactively and sending is supported.
@visibleForTesting
class ConversationView extends StatefulWidget {
  @visibleForTesting
  const ConversationView({
    required this.isGroup,
    required this.participantCount,
    required this.participantNames,
    required this.userPubkey,
    this.recipientProfile,
    super.key,
  });

  final bool isGroup;
  final UserProfile? recipientProfile;
  final int participantCount;
  final List<String> participantNames;
  final String userPubkey;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow =
        _scrollController.offset <
        _scrollController.position.maxScrollExtent - 100;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 100;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final ConversationBloc bloc;
    try {
      bloc = context.read<ConversationBloc>();
    } on Object {
      return;
    }

    if (widget.recipientProfile != null) {
      bloc.add(
        ConversationMessageSent(
          recipientPubkeys: [widget.recipientProfile!.pubkey],
          content: text,
        ),
      );
    }

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMoreOptions() {
    final profile = widget.recipientProfile;
    if (profile == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: VineTheme.onSurfaceMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.block,
                color: VineTheme.whiteText,
              ),
              title: Text(
                'Block user',
                style: VineTheme.bodyLargeFont(),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showBlockConfirmation(profile);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: VineTheme.error,
              ),
              title: Text(
                'Report',
                style: VineTheme.bodyLargeFont(color: VineTheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showReportUserDialog(profile);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(UserProfile profile) {
    showDialog<bool>(
      context: context,
      builder: (_) => _BlockUserConfirmationDialog(
        recipientProfile: profile,
        userPubkey: widget.userPubkey,
      ),
    ).then((blocked) {
      if (blocked == true && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            '${profile.bestDisplayName} has been blocked',
          ),
        );
      }
    });
  }

  void _showReportUserDialog(UserProfile profile) {
    showDialog<void>(
      context: context,
      builder: (_) => _ReportUserDialog(recipientProfile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: SafeArea(
        child: _NewMessageScrollListener(
          scrollController: _scrollController,
          isNearBottom: _isNearBottom,
          previousMessageCount: _previousMessageCount,
          onMessageCountChanged: (count) => _previousMessageCount = count,
          onScrollToBottom: _scrollToBottom,
          child: _SendStatusListener(
            child: Column(
              children: [
                if (widget.isGroup)
                  _GroupConversationHeader(
                    participantCount: widget.participantCount,
                    participantNames: widget.participantNames,
                    onClose: () => Navigator.of(context).pop(),
                    onMore: _showMoreOptions,
                  )
                else
                  _ConversationHeader(
                    profile: widget.recipientProfile!,
                    onBack: () => Navigator.of(context).pop(),
                    onMore: _showMoreOptions,
                  ),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: VineTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(48),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              _MessageArea(
                                scrollController: _scrollController,
                                isGroup: widget.isGroup,
                                userPubkey: widget.userPubkey,
                                recipientProfile: widget.recipientProfile,
                              ),
                              if (_showScrollToBottom)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: _ScrollToBottomButton(
                                    onTap: _scrollToBottom,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _MessageInput(
                          controller: _messageController,
                          onSend: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Listens for new messages arriving via [ConversationBloc] and auto-scrolls
/// to the bottom when the user is already near the bottom of the list.
class _NewMessageScrollListener extends StatelessWidget {
  const _NewMessageScrollListener({
    required this.scrollController,
    required this.isNearBottom,
    required this.previousMessageCount,
    required this.onMessageCountChanged,
    required this.onScrollToBottom,
    required this.child,
  });

  final ScrollController scrollController;
  final bool isNearBottom;
  final int previousMessageCount;
  final ValueChanged<int> onMessageCountChanged;
  final VoidCallback onScrollToBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    ConversationBloc? bloc;
    try {
      bloc = context.read<ConversationBloc>();
    } on Object {
      // No BLoC available (unauthenticated mode).
    }

    if (bloc == null) return child;

    return BlocListener<ConversationBloc, ConversationState>(
      listenWhen: (prev, curr) => curr.messages.length != prev.messages.length,
      listener: (context, state) {
        final newCount = state.messages.length;
        final hadMessages = previousMessageCount > 0;
        onMessageCountChanged(newCount);

        // Only auto-scroll when the user is already near the bottom,
        // so we don't yank them away from reading older messages.
        if (!hadMessages || isNearBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onScrollToBottom();
          });
        }
      },
      child: child,
    );
  }
}

class _SendStatusListener extends StatelessWidget {
  const _SendStatusListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    try {
      context.read<ConversationBloc>();
    } on Object {
      return child;
    }

    return BlocListener<ConversationBloc, ConversationState>(
      listenWhen: (prev, curr) => prev.sendStatus != curr.sendStatus,
      listener: (context, state) {
        if (state.sendStatus == SendStatus.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.sendError ?? 'Failed to send message',
              ),
              backgroundColor: VineTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: child,
    );
  }
}

class _MessageArea extends StatelessWidget {
  const _MessageArea({
    required this.scrollController,
    required this.isGroup,
    required this.userPubkey,
    this.recipientProfile,
  });

  final ScrollController scrollController;
  final bool isGroup;
  final String userPubkey;
  final UserProfile? recipientProfile;

  @override
  Widget build(BuildContext context) {
    ConversationBloc? bloc;
    try {
      bloc = context.read<ConversationBloc>();
    } on Object {
      // No BLoC available (unauthenticated mode)
    }

    if (bloc == null) {
      return _EmptyConversationProfile(profile: recipientProfile);
    }

    return BlocBuilder<ConversationBloc, ConversationState>(
      builder: (context, state) {
        return switch (state.status) {
          ConversationStatus.initial || ConversationStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          ConversationStatus.error => _EmptyConversationProfile(
            profile: recipientProfile,
          ),
          ConversationStatus.loaded =>
            state.messages.isNotEmpty
                ? _BlocMessagesList(
                    messages: state.messages,
                    scrollController: scrollController,
                    isGroup: isGroup,
                    userPubkey: userPubkey,
                  )
                : _EmptyConversationProfile(profile: recipientProfile),
        };
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1:1 header with back button, avatar, name, username, and more menu
// ---------------------------------------------------------------------------

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.profile,
    required this.onBack,
    required this.onMore,
  });

  final UserProfile profile;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VineTheme.surfaceBackground,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: _HeaderIconButton(
              onTap: onBack,
              icon: Icons.chevron_left,
              semanticLabel: 'Back',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.pubkey ==
                            ModerationLabelService.divineModerationPubkeyHex
                        ? 'Divine Moderation Team'
                        : profile.bestDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleMediumFont(
                      fontSize: 16,
                      height: 24 / 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: _HeaderIconButton(
              onTap: onMore,
              icon: Icons.more_horiz,
              semanticLabel: 'More options',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Group header with close button, "N people" title, and participant names
// ---------------------------------------------------------------------------

class _GroupConversationHeader extends StatelessWidget {
  const _GroupConversationHeader({
    required this.participantCount,
    required this.participantNames,
    required this.onClose,
    required this.onMore,
  });

  final int participantCount;
  final List<String> participantNames;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VineTheme.surfaceBackground,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: _HeaderIconButton(
              onTap: onClose,
              icon: Icons.close,
              semanticLabel: 'Close conversation',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$participantCount people',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleMediumFont(
                      fontSize: 16,
                      height: 24 / 16,
                    ),
                  ),
                  Text(
                    participantNames.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodySmallFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: _HeaderIconButton(
              onTap: onMore,
              icon: Icons.more_horiz,
              semanticLabel: 'More options',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onTap,
    required this.icon,
    required this.semanticLabel,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VineTheme.outlineMuted, width: 2),
          ),
          child: Icon(icon, color: VineTheme.whiteText, size: 24),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty conversation state
// ---------------------------------------------------------------------------

class _EmptyConversationProfile extends StatelessWidget {
  const _EmptyConversationProfile({this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No messages yet',
              style: VineTheme.titleMediumFont(
                fontSize: 20,
                height: 28 / 20,
                color: VineTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation!',
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        ),
      );
    }

    final displayName =
        profile!.pubkey == ModerationLabelService.divineModerationPubkeyHex
        ? 'Divine Moderation Team'
        : profile!.bestDisplayName;
    final nip05 = profile!.nip05;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileAvatar(avatarUrl: profile!.picture),
          const SizedBox(height: 32),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: VineTheme.titleMediumFont(
              fontSize: 20,
              height: 28 / 20,
            ),
          ),
          if (nip05 != null && nip05.isNotEmpty) ...[
            Text(
              '@$nip05',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodySmallFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              final npub = NostrKeyUtils.encodePubKey(profile!.pubkey);
              context.push(
                OtherProfileScreen.pathForNpub(npub),
                extra: <String, String?>{
                  'displayName': profile!.bestDisplayName,
                  'avatarUrl': profile!.picture,
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: VineTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: VineTheme.outlineMuted,
                  width: 2,
                ),
              ),
              child: Text(
                'View profile',
                style: VineTheme.titleMediumFont(
                  fontSize: 16,
                  color: VineTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.avatarUrl});

  final String? avatarUrl;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: VineTheme.onSurfaceDisabled,
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(37),
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                cacheManager: ImageCacheManager(),
                placeholder: (_, _) => const _ProfileAvatarFallback(),
                errorWidget: (_, _, _) => const _ProfileAvatarFallback(),
              )
            : const _ProfileAvatarFallback(),
      ),
    );
  }
}

class _ProfileAvatarFallback extends StatelessWidget {
  const _ProfileAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: VineTheme.surfaceContainer,
      child: Icon(
        Icons.person,
        color: VineTheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared video detection and parsing
// ---------------------------------------------------------------------------

/// Parsed metadata from a shared video message.
@immutable
class _SharedVideoInfo {
  const _SharedVideoInfo({
    required this.title,
    this.videoId,
    this.personalMessage,
  });

  final String? title;

  /// The video's stable ID extracted from a `divine.video/video/{id}` URL.
  final String? videoId;
  final String? personalMessage;
}

/// Marker prefix emitted by [VideoSharingService._createShareMessage].
const _sharePrefix = '🎬 Check out this vine:';

/// Regex to extract a quoted title: `"Some Title"`.
final _titlePattern = RegExp('"([^"]+)"');

/// Regex to extract the video ID from a `divine.video/video/{id}` URL.
final _divineVideoUrlPattern = RegExp(r'divine\.video/video/([A-Za-z0-9_-]+)');

/// Returns parsed [_SharedVideoInfo] if [content] matches the share format,
/// or `null` for plain text messages.
_SharedVideoInfo? _parseSharedVideo(String content) {
  final prefixIndex = content.indexOf(_sharePrefix);
  if (prefixIndex == -1) return null;

  // Personal message is any text before the share prefix.
  final personalMessage = prefixIndex > 0
      ? content.substring(0, prefixIndex).trim()
      : null;

  final shareBlock = content.substring(prefixIndex);

  // Extract quoted title.
  final titleMatch = _titlePattern.firstMatch(shareBlock);
  final title = titleMatch?.group(1);

  // Extract the video ID from the divine.video share URL.
  final videoIdMatch = _divineVideoUrlPattern.firstMatch(shareBlock);
  final videoId = videoIdMatch?.group(1);

  return _SharedVideoInfo(
    title: title,
    videoId: videoId,
    personalMessage: personalMessage != null && personalMessage.isNotEmpty
        ? personalMessage
        : null,
  );
}

// ---------------------------------------------------------------------------
// BLoC-driven messages list (real data from DM repository)
// ---------------------------------------------------------------------------

class _BlocMessagesList extends StatelessWidget {
  const _BlocMessagesList({
    required this.messages,
    required this.scrollController,
    required this.userPubkey,
    this.isGroup = false,
  });

  final List<DmMessage> messages;
  final ScrollController scrollController;
  final String userPubkey;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    // Messages come newest-first from DAO; reverse for chronological display.
    final chronological = messages.reversed.toList();

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chronological.length,
      itemBuilder: (context, index) {
        final message = chronological[index];
        final isSent = message.isSentBy(userPubkey);
        final sharedVideo = _parseSharedVideo(message.content);

        // Grouping: determine if first/last in consecutive same-sender run.
        final nextSender = index < chronological.length - 1
            ? chronological[index + 1].senderPubkey
            : null;
        final isLastInGroup = message.senderPubkey != nextSender;

        // Date divider: show when the day changes from the previous message.
        final showDateDivider =
            index == 0 ||
            !_isSameDay(
              chronological[index - 1].createdAt,
              message.createdAt,
            );

        return Column(
          crossAxisAlignment: isSent
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (showDateDivider)
              _DateDivider(
                label: TimeFormatter.formatDateLabel(message.createdAt),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: isLastInGroup ? 8 : 2),
              child: Column(
                crossAxisAlignment: isSent
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (sharedVideo != null) ...[
                    if (sharedVideo.personalMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MessageBubble(
                          text: sharedVideo.personalMessage!,
                          isSent: isSent,
                          isLastInGroup: isLastInGroup,
                        ),
                      ),
                    _SharedVideoCard(info: sharedVideo, isSent: isSent),
                  ] else
                    _MessageBubble(
                      text: message.content,
                      isSent: isSent,
                      isLastInGroup: isLastInGroup,
                    ),
                  if (isLastInGroup) ...[
                    const SizedBox(height: 4),
                    _TimestampLabel(
                      timestamp: TimeFormatter.formatRelativeVerbose(
                        message.createdAt,
                      ),
                      isSent: isSent,
                      senderName: isGroup && !isSent
                          ? message.senderPubkey
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1 * 1000);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2 * 1000);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}

// ---------------------------------------------------------------------------
// Message bubble (sent = green/right, received = dark/left)
// ---------------------------------------------------------------------------

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isSent,
    this.isLastInGroup = true,
  });

  final String text;
  final bool isSent;
  final bool isLastInGroup;

  static const _sentRadius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(4),
  );

  static const _receivedRadius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(4),
    bottomRight: Radius.circular(16),
  );

  static const _allRounded = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final emojiOnly = _isEmojiOnly(text);

    if (emojiOnly) {
      return Text(text, style: VineTheme.displaySmallFont());
    }

    final BorderRadius radius;
    if (isLastInGroup) {
      radius = isSent ? _sentRadius : _receivedRadius;
    } else {
      radius = _allRounded;
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSent ? VineTheme.primaryAccessible : VineTheme.containerLow,
        borderRadius: radius,
      ),
      child: Text(text, style: VineTheme.bodyMediumFont()),
    );
  }
}

/// Returns `true` if [text] contains only emoji characters and whitespace.
bool _isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.length > 20) return false;

  var hasEmoji = false;
  for (final rune in trimmed.runes) {
    // Skip whitespace, variation selectors (FE0F), and ZWJ (200D).
    if (rune == 0x20 || rune == 0xFE0F || rune == 0x200D) continue;
    // Common emoji ranges.
    if (_isEmojiRune(rune)) {
      hasEmoji = true;
      continue;
    }
    // Non-emoji character found.
    return false;
  }
  return hasEmoji;
}

bool _isEmojiRune(int rune) {
  return (rune >= 0x1F600 && rune <= 0x1F64F) || // Emoticons
      (rune >= 0x1F300 && rune <= 0x1F5FF) || // Misc Symbols & Pictographs
      (rune >= 0x1F680 && rune <= 0x1F6FF) || // Transport & Map
      (rune >= 0x1F1E0 && rune <= 0x1F1FF) || // Regional indicators (flags)
      (rune >= 0x2600 && rune <= 0x27BF) || // Misc Symbols & Dingbats
      (rune >= 0x1F900 && rune <= 0x1F9FF) || // Supplemental Symbols
      (rune >= 0x1FA00 && rune <= 0x1FA6F) || // Chess, extended-A
      (rune >= 0x1FA70 && rune <= 0x1FAFF) || // Symbols extended-A
      (rune >= 0x2702 && rune <= 0x27B0) || // Dingbats
      (rune >= 0x231A && rune <= 0x23F3) || // Misc technical
      (rune == 0x2764) || // Heart
      (rune == 0x2B50) || // Star
      (rune == 0x2B55) || // Circle
      (rune == 0x2934) || // Arrow
      (rune == 0x2935) || // Arrow
      (rune >= 0x25AA && rune <= 0x25FE); // Geometric shapes
}

// ---------------------------------------------------------------------------
// Shared video card (Figma: ChatItem layout=share)
// ---------------------------------------------------------------------------

class _SharedVideoCard extends StatelessWidget {
  const _SharedVideoCard({required this.info, required this.isSent});

  final _SharedVideoInfo info;
  final bool isSent;

  void _onTap(BuildContext context) {
    final videoId = info.videoId;
    if (videoId == null) return;
    context.push(VideoDetailScreen.pathForId(videoId));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Shared video${info.title != null ? ': ${info.title}' : ''}',
      button: info.videoId != null,
      child: GestureDetector(
        onTap: info.videoId != null ? () => _onTap(context) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 144,
            height: 256,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (info.videoId != null)
                  CachedNetworkImage(
                    imageUrl: ThumbnailApiService.getThumbnailUrl(
                      info.videoId!,
                    ),
                    cacheManager: ImageCacheManager(),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(
                      color: VineTheme.surfaceContainer,
                    ),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: VineTheme.surfaceContainer,
                    ),
                  )
                else
                  const ColoredBox(color: VineTheme.surfaceContainer),
                // Play icon centered
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: VineTheme.backgroundColor.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: VineTheme.whiteText,
                      size: 28,
                    ),
                  ),
                ),
                // Bottom gradient scrim
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xA6000000), // 65% black
                        ],
                      ),
                    ),
                  ),
                ),
                // Title overlay at bottom
                if (info.title != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      info.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.titleMediumFont(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scroll-to-bottom floating button
// ---------------------------------------------------------------------------

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Scroll to bottom',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: VineTheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_downward,
            color: VineTheme.onPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date divider for timeline grouping
// ---------------------------------------------------------------------------

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: VineTheme.labelSmallFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timestamp / sender attribution label
// ---------------------------------------------------------------------------

class _TimestampLabel extends StatelessWidget {
  const _TimestampLabel({
    required this.timestamp,
    required this.isSent,
    this.senderName,
  });

  final String timestamp;
  final bool isSent;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    if (senderName != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              senderName!,
              style: VineTheme.labelSmallFont(color: VineTheme.onSurfaceMuted),
            ),
            const SizedBox(width: 8),
            Text(
              timestamp,
              style: VineTheme.labelSmallFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        timestamp,
        style: VineTheme.labelSmallFont(color: VineTheme.onSurfaceMuted),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message input bar
// ---------------------------------------------------------------------------

class _MessageInput extends StatelessWidget {
  const _MessageInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VineTheme.surfaceBackground,
        border: Border(
          top: BorderSide(color: VineTheme.outlineDisabled, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: TextFieldTapRegion(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: VineTheme.bodyLargeFont(),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Say something...',
                    hintStyle: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, _) {
                  if (value.text.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      _SendButton(onTap: onSend),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Send message',
      button: true,
      child: Material(
        color: VineTheme.primary,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_upward,
              color: VineTheme.onPrimary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Block user confirmation dialog
// ---------------------------------------------------------------------------

class _BlockUserConfirmationDialog extends ConsumerWidget {
  const _BlockUserConfirmationDialog({
    required this.recipientProfile,
    required this.userPubkey,
  });

  final UserProfile recipientProfile;
  final String userPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Block user',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: Text(
        'Are you sure you want to block '
        '${recipientProfile.bestDisplayName}? '
        'You will no longer receive messages from this user.',
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            ref
                .read(contentBlocklistServiceProvider)
                .blockUser(
                  recipientProfile.pubkey,
                  ourPubkey: userPubkey,
                );
            Navigator.of(context).pop(true);
          },
          child: const Text(
            'Block',
            style: TextStyle(color: VineTheme.error),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Report user dialog (DM context — no VideoEvent needed)
// ---------------------------------------------------------------------------

class _ReportUserDialog extends ConsumerStatefulWidget {
  const _ReportUserDialog({required this.recipientProfile});

  final UserProfile recipientProfile;

  @override
  ConsumerState<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends ConsumerState<_ReportUserDialog> {
  ContentFilterReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _blockUser = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Report User',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Why are you reporting this user?',
                style: TextStyle(color: VineTheme.whiteText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Divine will review reports within 24 hours and take '
                'appropriate action.',
                style: TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              RadioGroup<ContentFilterReason>(
                groupValue: _selectedReason,
                onChanged: (value) => setState(() => _selectedReason = value),
                child: Column(
                  children: ContentFilterReason.values
                      .map(
                        (reason) => RadioListTile<ContentFilterReason>(
                          title: Text(
                            _reasonDisplayName(reason),
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                            ),
                          ),
                          value: reason,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                enableInteractiveSelection: true,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  labelStyle: TextStyle(color: VineTheme.secondaryText),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text(
                  'Block this user',
                  style: TextStyle(color: VineTheme.whiteText),
                ),
                value: _blockUser,
                onChanged: (value) =>
                    setState(() => _blockUser = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Report'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          'Please select a reason for your report',
          error: true,
        ),
      );
      return;
    }
    _submitReport();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );

      final result = await reportService.reportUser(
        userPubkey: widget.recipientProfile.pubkey,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty
            ? _reasonDisplayName(_selectedReason!)
            : _detailsController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      if (result.success) {
        if (_blockUser) {
          ref
              .read(contentBlocklistServiceProvider)
              .blockUser(
                widget.recipientProfile.pubkey,
                ourPubkey: ref.read(nostrServiceProvider).publicKey,
              );
        }

        // Send moderation DM
        final dmRepo = ref.read(dmRepositoryProvider);
        try {
          await dmRepo.sendMessage(
            recipientPubkey: ModerationLabelService.divineModerationPubkeyHex,
            content: _formatReportDm(),
          );
        } catch (e) {
          Log.warning(
            'Failed to send moderation DM: $e',
            name: 'ReportUserDialog',
            category: LogCategory.system,
          );
        }

        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (_) => const _ReportConfirmationDialog(),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            'Failed to report: ${result.error}',
            error: true,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to submit user report: $e',
        name: 'ReportUserDialog',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            'Failed to report: $e',
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatReportDm() {
    final buffer = StringBuffer()
      ..writeln('User Report')
      ..writeln('User: ${widget.recipientProfile.pubkey}')
      ..writeln('Reason: ${_reasonDisplayName(_selectedReason!)}');
    final details = _detailsController.text.trim();
    if (details.isNotEmpty) {
      buffer.writeln('Details: $details');
    }
    return buffer.toString().trimRight();
  }

  static String _reasonDisplayName(ContentFilterReason reason) {
    return switch (reason) {
      ContentFilterReason.spam => 'Spam or Unwanted Content',
      ContentFilterReason.harassment => 'Harassment, Bullying, or Threats',
      ContentFilterReason.violence => 'Violent or Extremist Content',
      ContentFilterReason.sexualContent => 'Sexual or Adult Content',
      ContentFilterReason.copyright => 'Copyright Violation',
      ContentFilterReason.falseInformation => 'False Information',
      ContentFilterReason.csam => 'Child Safety Violation',
      ContentFilterReason.aiGenerated => 'AI-Generated Content',
      ContentFilterReason.other => 'Other Policy Violation',
    };
  }
}

// ---------------------------------------------------------------------------
// Report confirmation dialog
// ---------------------------------------------------------------------------

class _ReportConfirmationDialog extends StatelessWidget {
  const _ReportConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Row(
        spacing: 12,
        children: [
          Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 28),
          Text(
            'Report Received',
            style: TextStyle(color: VineTheme.whiteText),
          ),
        ],
      ),
      content: const Text(
        'Thank you for helping keep Divine safe. Our team will '
        'review your report and take appropriate action.',
        style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: VineTheme.vineGreen),
          ),
        ),
      ],
    );
  }
}
