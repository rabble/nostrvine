// ABOUTME: BLoC-compatible notification list item widget using the sealed
// ABOUTME: NotificationItem model. Handles single and grouped notifications
// ABOUTME: with exhaustive pattern matching.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:time_formatter/time_formatter.dart';

/// Displays a single notification row in the notifications list.
///
/// Uses exhaustive switch on [NotificationItem] to render the correct
/// layout for [SingleNotification] and [GroupedNotification].
class NotificationListItem extends StatelessWidget {
  /// Creates a notification list item.
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
    this.onFollowBack,
    super.key,
  });

  /// The notification data to display.
  final NotificationItem notification;

  /// Called when the entire row is tapped.
  final VoidCallback onTap;

  /// Called when the actor avatar is tapped.
  final VoidCallback? onProfileTap;

  /// Called when the "Follow back" button is tapped (follow notifications).
  final VoidCallback? onFollowBack;

  @override
  Widget build(BuildContext context) {
    return switch (notification) {
      SingleNotification() => _SingleRow(
        notification: notification as SingleNotification,
        onTap: onTap,
        onProfileTap: onProfileTap,
        onFollowBack: onFollowBack,
      ),
      GroupedNotification() => _GroupedRow(
        notification: notification as GroupedNotification,
        onTap: onTap,
        onProfileTap: onProfileTap,
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Single notification row
// ---------------------------------------------------------------------------

class _SingleRow extends StatelessWidget {
  const _SingleRow({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
    this.onFollowBack,
  });

  final SingleNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onFollowBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isRead
          ? VineTheme.backgroundColor
          : VineTheme.cardBackground,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarWithIcon(
                pictureUrl: notification.actor.pictureUrl,
                displayName: notification.actor.displayName,
                type: notification.type,
                onProfileTap: onProfileTap,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessageText(
                      message: notification.message,
                      actorName: notification.actor.displayName,
                    ),
                    const SizedBox(height: 4),
                    if (_hasCommentText) ...[
                      _CommentPreview(text: notification.commentText!),
                      const SizedBox(height: 4),
                    ],
                    _Timestamp(timestamp: notification.timestamp),
                    if (_showFollowBack) ...[
                      const SizedBox(height: 8),
                      _FollowBackButton(onFollowBack: onFollowBack),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasCommentText =>
      (notification.type == NotificationKind.comment ||
          notification.type == NotificationKind.reply) &&
      notification.commentText != null;

  bool get _showFollowBack =>
      notification.type == NotificationKind.follow &&
      !notification.isFollowingBack;
}

// ---------------------------------------------------------------------------
// Grouped notification row
// ---------------------------------------------------------------------------

class _GroupedRow extends StatelessWidget {
  const _GroupedRow({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
  });

  final GroupedNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final overflowCount = notification.totalCount - notification.actors.length;

    return Material(
      color: notification.isRead
          ? VineTheme.backgroundColor
          : VineTheme.cardBackground,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: _StackWithIcon(
                  actors: notification.actors,
                  overflowCount: overflowCount > 0 ? overflowCount : null,
                  type: notification.type,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessageText(
                      message: notification.message,
                      actorName: notification.actors.isNotEmpty
                          ? notification.actors.first.displayName
                          : null,
                    ),
                    const SizedBox(height: 4),
                    _Timestamp(timestamp: notification.timestamp),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _AvatarWithIcon extends StatelessWidget {
  const _AvatarWithIcon({
    required this.type,
    this.pictureUrl,
    this.displayName,
    this.onProfileTap,
  });

  final String? pictureUrl;
  final String? displayName;
  final NotificationKind type;
  final VoidCallback? onProfileTap;

  static const double _avatarSize = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: displayName != null ? 'View $displayName profile' : 'View profile',
      button: true,
      child: GestureDetector(
        onTap: onProfileTap,
        child: SizedBox(
          width: _avatarSize,
          height: _avatarSize,
          child: Stack(
            children: [
              ClipOval(
                child: pictureUrl != null
                    ? CachedNetworkImage(
                        imageUrl: pictureUrl!,
                        width: _avatarSize,
                        height: _avatarSize,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const _DefaultSingleAvatar(),
                        errorWidget: (context, url, error) =>
                            const _DefaultSingleAvatar(),
                      )
                    : const _DefaultSingleAvatar(),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _TypeIconBadge(type: type),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultSingleAvatar extends StatelessWidget {
  const _DefaultSingleAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: VineTheme.accentPurple.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.person, color: VineTheme.accentPurple, size: 24),
      ),
    );
  }
}

class _StackWithIcon extends StatelessWidget {
  const _StackWithIcon({
    required this.actors,
    required this.type,
    this.overflowCount,
  });

  final List<ActorInfo> actors;
  final int? overflowCount;
  final NotificationKind type;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotificationAvatarStack(
          actors: actors,
          overflowCount: overflowCount,
        ),
        const SizedBox(height: 4),
        _TypeIconBadge(type: type),
      ],
    );
  }
}

class _TypeIconBadge extends StatelessWidget {
  const _TypeIconBadge({required this.type});

  final NotificationKind type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _iconBackgroundColor,
        shape: BoxShape.circle,
        border: Border.all(width: 2),
      ),
      child: Center(
        child: Text(
          _typeEmoji,
          style: const TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  Color get _iconBackgroundColor {
    return switch (type) {
      NotificationKind.like => VineTheme.error,
      NotificationKind.comment => VineTheme.info,
      NotificationKind.reply => VineTheme.info,
      NotificationKind.follow => VineTheme.accentPurple,
      NotificationKind.repost => VineTheme.vineGreen,
      NotificationKind.mention => VineTheme.warning,
      NotificationKind.system => VineTheme.lightText,
    };
  }

  String get _typeEmoji {
    return switch (type) {
      NotificationKind.like => '\u2764\uFE0F',
      NotificationKind.comment => '\uD83D\uDCAC',
      NotificationKind.reply => '\u21A9\uFE0F',
      NotificationKind.follow => '\uD83D\uDC64',
      NotificationKind.repost => '\uD83D\uDD01',
      NotificationKind.mention => '\u0040',
      NotificationKind.system => '\u2139\uFE0F',
    };
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({
    required this.message,
    this.actorName,
  });

  final String message;
  final String? actorName;

  @override
  Widget build(BuildContext context) {
    if (_messageStartsWithActorName) {
      return RichText(
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(
          style: VineTheme.bodyMediumFont(),
          children: [
            TextSpan(
              text: actorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: message.substring(actorName!.length),
            ),
          ],
        ),
      );
    }

    return Text(message, style: VineTheme.bodyMediumFont());
  }

  bool get _messageStartsWithActorName {
    if (actorName == null) return false;
    return message == actorName || message.startsWith('$actorName ');
  }
}

class _CommentPreview extends StatelessWidget {
  const _CommentPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Timestamp extends StatelessWidget {
  const _Timestamp({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final unixSeconds = timestamp.millisecondsSinceEpoch ~/ 1000;
    return Text(
      TimeFormatter.formatRelativeVerbose(unixSeconds),
      style: VineTheme.bodySmallFont(color: VineTheme.lightText),
    );
  }
}

class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({this.onFollowBack});

  final VoidCallback? onFollowBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: onFollowBack,
        style: FilledButton.styleFrom(
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(context.l10n.notificationFollowBack),
      ),
    );
  }
}
