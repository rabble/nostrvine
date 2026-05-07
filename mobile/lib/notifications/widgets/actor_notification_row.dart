// ABOUTME: One-row layout for ActorNotification — leading 32x32 type icon,
// ABOUTME: avatar + bold actor name + verb + inline timestamp, optional
// ABOUTME: comment quote, optional Follow back button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_type_icon_spec.dart';
import 'package:openvine/widgets/notification_type_icon.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Displays a single actor-anchored notification row (follow / mention /
/// likeComment / reply / system).
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
    final spec = notificationTypeIconSpec(notification.type);

    return Material(
      color: VineTheme.surfaceContainerHigh,
      child: Semantics(
        button: true,
        container: true,
        label: notification.isRead ? null : l10n.notificationsUnreadPrefix,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: VineTheme.outlineDisabled),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NotificationTypeIcon(
                    icon: spec.icon,
                    backgroundColor: spec.background,
                    foregroundColor: spec.foreground,
                    showUnreadDot: !notification.isRead,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(
                          imageUrl: notification.actor.pictureUrl,
                          name: notification.actor.displayName,
                          placeholderSeed: notification.actor.pubkey,
                          size: NotificationConstants.avatarSize,
                          cornerRadius:
                              NotificationConstants.avatarCornerRadius,
                          onTap: onProfileTap,
                          semanticLabel: l10n
                              .notificationsViewProfileSemanticLabel(
                                notification.actor.displayName,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _MessageText(notification: notification),
                        if (_hasComment) ...[
                          const SizedBox(height: 4),
                          _CommentQuote(text: notification.commentText!),
                        ],
                      ],
                    ),
                  ),
                  if (_showFollowBack) ...[
                    const SizedBox(width: 8),
                    _FollowBackButton(onPressed: onFollowBack),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification});

  final ActorNotification notification;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spans = <InlineSpan>[];
    final type = notification.type;

    if (type == NotificationKind.system) {
      spans.add(
        TextSpan(
          text: l10n.notificationSystemUpdate,
          style: VineTheme.bodyMediumFont(),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: notification.actor.displayName,
          style: VineTheme.labelLargeFont(),
        ),
      );
      spans.add(
        TextSpan(
          text: ' ${_verbFor(l10n, type)}',
          style: VineTheme.bodyMediumFont(),
        ),
      );
    }

    spans.add(
      TextSpan(
        text:
            ' ${LocalizedTimeFormatter.formatRelative(l10n, notification.timestamp.millisecondsSinceEpoch ~/ 1000)}',
        style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted55),
      ),
    );

    return Text.rich(
      TextSpan(children: spans),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

/// Returns just the verb portion (no actor name) for inline composition.
///
/// l10n verb keys carry the actor name as a leading `{actorName}`
/// placeholder. Calling them with an empty string leaves a leading
/// separator (a space in English, possibly something different in other
/// locales) — strip it so the caller can prepend its own bold actor name.
/// `notificationRepliedToYourComment` is already actor-free and used
/// as-is.
String _verbFor(AppLocalizations l10n, NotificationKind type) {
  return switch (type) {
    NotificationKind.follow => l10n.notificationStartedFollowing('').trimLeft(),
    NotificationKind.mention => l10n.notificationMentionedYou('').trimLeft(),
    NotificationKind.likeComment =>
      l10n.notificationLikedYourComment('').trimLeft(),
    NotificationKind.reply => l10n.notificationRepliedToYourComment,
    // System is handled inline in _MessageText. The remaining cases are
    // unreachable because ActorNotification asserts on type — but
    // exhaustivity requires them.
    NotificationKind.system ||
    NotificationKind.like ||
    NotificationKind.comment ||
    NotificationKind.repost => '',
  };
}

class _CommentQuote extends StatelessWidget {
  const _CommentQuote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      '“$text”',
      style: VineTheme.bodyMediumFont(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.notificationFollowBack,
      onPressed: onPressed,
      size: DivineButtonSize.small,
    );
  }
}
