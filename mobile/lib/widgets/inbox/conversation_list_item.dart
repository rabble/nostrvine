// ABOUTME: Conversation list item widget for the messages tab
// ABOUTME: Displays avatar, name, message preview, timestamp, and
// ABOUTME: unread indicator for a single conversation entry

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/image_cache_manager.dart';

/// A single conversation entry in the messages list.
///
/// Renders the conversation with an avatar (single or group), display name,
/// last message preview, timestamp, and optional unread indicator.
class ConversationListItem extends StatelessWidget {
  /// Creates a [ConversationListItem].
  const ConversationListItem({
    required this.displayName,
    required this.lastMessage,
    required this.timestamp,
    this.avatarUrl,
    this.isUnread = false,
    this.isGroupChat = false,
    this.participantCount = 1,
    this.participantAvatars = const [],
    this.onTap,
    super.key,
  });

  /// The display name of the conversation (user or group name).
  final String displayName;

  /// Preview text of the last message in the conversation.
  final String lastMessage;

  /// Formatted timestamp string (e.g. "14h", "2d", "Just now").
  final String timestamp;

  /// Avatar URL for single-user conversations.
  final String? avatarUrl;

  /// Whether the conversation has unread messages.
  final bool isUnread;

  /// Whether this is a group conversation.
  final bool isGroupChat;

  /// Number of participants in a group chat.
  final int participantCount;

  /// Avatar URLs for group chat participants.
  final List<String> participantAvatars;

  /// Callback when the conversation item is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConversationAvatar(
                    avatarUrl: avatarUrl,
                    isGroupChat: isGroupChat,
                    participantAvatars: participantAvatars,
                    participantCount: participantCount,
                    isUnread: isUnread,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _ConversationContent(
                      displayName: displayName,
                      lastMessage: lastMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ConversationTimestamp(timestamp: timestamp),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: VineTheme.outlineMuted),
      ],
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.isGroupChat,
    required this.participantAvatars,
    required this.participantCount,
    required this.isUnread,
    this.avatarUrl,
  });

  final String? avatarUrl;
  final bool isGroupChat;
  final List<String> participantAvatars;
  final int participantCount;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isGroupChat && participantAvatars.length >= 2)
            _GroupAvatar(
              participantAvatars: participantAvatars,
              participantCount: participantCount,
            )
          else
            _SingleAvatar(avatarUrl: avatarUrl),
          if (isUnread)
            const Positioned(top: -4, left: 36, child: _UnreadDot()),
        ],
      ),
    );
  }
}

class _SingleAvatar extends StatelessWidget {
  const _SingleAvatar({this.avatarUrl});

  final String? avatarUrl;

  static const double _size = 40;
  static const double _borderRadius = 16;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_borderRadius),
      child: SizedBox(
        width: _size,
        height: _size,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                cacheManager: openVineImageCache,
                placeholder: (context, url) =>
                    const _AvatarFallback(size: _size),
                errorWidget: (context, url, error) =>
                    const _AvatarFallback(size: _size),
              )
            : const _AvatarFallback(size: _size),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({
    required this.participantAvatars,
    required this.participantCount,
  });

  final List<String> participantAvatars;
  final int participantCount;

  @override
  Widget build(BuildContext context) {
    if (participantAvatars.length == 2) {
      return const _TwoPersonGroupAvatar();
    }
    return _GridGroupAvatar(
      participantAvatars: participantAvatars,
      participantCount: participantCount,
    );
  }
}

class _TwoPersonGroupAvatar extends StatelessWidget {
  const _TwoPersonGroupAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const _AvatarFallback(size: 32),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: const _AvatarFallback(size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridGroupAvatar extends StatelessWidget {
  const _GridGroupAvatar({
    required this.participantAvatars,
    required this.participantCount,
  });

  final List<String> participantAvatars;
  final int participantCount;

  static const double _cellSize = 18;
  static const double _cellRadius = 6;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_cellRadius),
                child: const _AvatarFallback(size: _cellSize),
              ),
              const SizedBox(width: _gap),
              ClipRRect(
                borderRadius: BorderRadius.circular(_cellRadius),
                child: const _AvatarFallback(size: _cellSize),
              ),
            ],
          ),
          const SizedBox(height: _gap),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_cellRadius),
                child: const _AvatarFallback(size: _cellSize),
              ),
              const SizedBox(width: _gap),
              _CountBadgeCell(count: participantCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBadgeCell extends StatelessWidget {
  const _CountBadgeCell({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 18,
        height: 18,
        color: VineTheme.surfaceContainer,
        child: Center(
          child: Text(
            '+$count',
            style: VineTheme.bodySmallFont(
              color: VineTheme.onSurfaceVariant,
            ).copyWith(fontSize: 8),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: VineTheme.error, shape: BoxShape.circle),
      child: SizedBox(width: 8, height: 8),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: VineTheme.surfaceContainer,
      child: Icon(
        Icons.person,
        color: VineTheme.onSurfaceVariant,
        size: size * 0.6,
      ),
    );
  }
}

class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.displayName,
    required this.lastMessage,
  });

  final String displayName;
  final String lastMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          style: VineTheme.titleMediumFont(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          lastMessage,
          style: VineTheme.bodyMediumFont(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ConversationTimestamp extends StatelessWidget {
  const _ConversationTimestamp({required this.timestamp});

  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        timestamp,
        style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
      ),
    );
  }
}
