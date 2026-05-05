// ABOUTME: One-row layout for ActorNotification — single avatar with type
// ABOUTME: badge, message + timestamp, optional Follow back button.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:time_formatter/time_formatter.dart';

const double _avatarSize = 48;
const double _badgeSize = 20;
const double _followBackHeight = 32;

/// Displays a single actor-anchored notification row (follow / mention /
/// system).
class ActorNotificationRow extends StatelessWidget {
  /// Creates an [ActorNotificationRow].
  const ActorNotificationRow({
    required this.notification,
    required this.onTap,
    required this.onProfileTap,
    this.onFollowBack,
    super.key,
  });

  /// The actor-anchored notification to render.
  final ActorNotification notification;

  /// Called when the row body is tapped.
  final VoidCallback onTap;

  /// Called when the avatar is tapped.
  final VoidCallback onProfileTap;

  /// Called when the Follow back button is tapped (follow kind only).
  final VoidCallback? onFollowBack;

  bool get _showFollowBack =>
      notification.type == NotificationKind.follow &&
      !notification.isFollowingBack;

  bool get _hasComment =>
      notification.commentText != null && notification.commentText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actorName = notification.actor.displayName;
    final message = switch (notification.type) {
      NotificationKind.follow => l10n.notificationStartedFollowing(actorName),
      NotificationKind.mention => l10n.notificationMentionedYou(actorName),
      NotificationKind.likeComment => l10n.notificationLikedYourComment(
        actorName,
      ),
      NotificationKind.system => l10n.notificationSystemUpdate,
      NotificationKind.like ||
      NotificationKind.comment ||
      NotificationKind.reply ||
      NotificationKind.repost => actorName,
    };

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
              _AvatarWithBadge(
                actor: notification.actor,
                type: notification.type,
                onProfileTap: onProfileTap,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: VineTheme.bodyMediumFont()),
                    if (_hasComment) ...[
                      const SizedBox(height: 4),
                      _CommentPreview(text: notification.commentText!),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      TimeFormatter.formatRelativeVerbose(
                        notification.timestamp.millisecondsSinceEpoch ~/ 1000,
                      ),
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.lightText,
                      ),
                    ),
                    if (_showFollowBack) ...[
                      const SizedBox(height: 8),
                      _FollowBackButton(onPressed: onFollowBack),
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
}

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({
    required this.actor,
    required this.type,
    required this.onProfileTap,
  });

  final ActorInfo actor;
  final NotificationKind type;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'View ${actor.displayName} profile',
      button: true,
      child: GestureDetector(
        onTap: onProfileTap,
        child: SizedBox(
          width: _avatarSize,
          height: _avatarSize,
          child: Stack(
            children: [
              ClipOval(
                child: actor.pictureUrl != null
                    ? CachedNetworkImage(
                        imageUrl: actor.pictureUrl!,
                        width: _avatarSize,
                        height: _avatarSize,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const _DefaultAvatar(),
                        errorWidget: (context, url, error) =>
                            const _DefaultAvatar(),
                      )
                    : const _DefaultAvatar(),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _TypeBadge(type: type),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.accentPurple.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(
        width: _avatarSize,
        height: _avatarSize,
        child: Center(
          child: Icon(Icons.person, color: VineTheme.accentPurple, size: 24),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final NotificationKind type;

  Color get _backgroundColor {
    return switch (type) {
      NotificationKind.like => VineTheme.error,
      NotificationKind.likeComment => VineTheme.error,
      NotificationKind.comment => VineTheme.info,
      NotificationKind.reply => VineTheme.info,
      NotificationKind.follow => VineTheme.accentPurple,
      NotificationKind.repost => VineTheme.vineGreen,
      NotificationKind.mention => VineTheme.warning,
      NotificationKind.system => VineTheme.lightText,
    };
  }

  String get _emoji {
    return switch (type) {
      NotificationKind.like => '❤️',
      NotificationKind.likeComment => '❤️',
      NotificationKind.comment => '💬',
      NotificationKind.reply => '↩️',
      NotificationKind.follow => '👤',
      NotificationKind.repost => '🔁',
      NotificationKind.mention => '@',
      NotificationKind.system => 'ℹ️',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        color: _backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(width: 2),
      ),
      child: Center(
        child: Text(
          _emoji,
          style: const TextStyle(fontSize: 10),
        ),
      ),
    );
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

class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _followBackHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: VineTheme.vineGreen,
          foregroundColor: VineTheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('Follow back'),
      ),
    );
  }
}
