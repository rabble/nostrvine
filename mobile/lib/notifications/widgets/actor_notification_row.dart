// ABOUTME: One-row layout for ActorNotification — leading 32x32 type icon,
// ABOUTME: avatar + bold actor name + verb + inline timestamp, optional
// ABOUTME: comment quote, optional Follow back button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/notifications/widgets/notification_leading_type_icon.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  NotificationLeadingTypeIcon(
                    type: notification.type,
                    isRead: notification.isRead,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _NotificationContent(
                      notification: notification,
                      onProfileTap: onProfileTap,
                      onFollowBack: onFollowBack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.notification,
    required this.onProfileTap,
    this.onFollowBack,
  });

  final ActorNotification notification;
  final VoidCallback onProfileTap;
  final VoidCallback? onFollowBack;

  bool get _showFollowBack =>
      notification.type == NotificationKind.follow &&
      !notification.isFollowingBack;

  bool get _hasComment =>
      notification.commentText != null && notification.commentText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The trailing relative timestamp anchors to the visual end of the
    // row. When a comment quote is rendered, the quote owns the
    // timestamp suffix; without a quote, the timestamp sits at the end
    // of the message text.
    final relativeTime = LocalizedTimeFormatter.formatRelative(
      l10n,
      notification.timestamp.millisecondsSinceEpoch ~/ 1000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + (optional) Follow back share a single row so the avatar
        // stays anchored to the top-left and the button hugs the right
        // edge. Keeping the button on this row — instead of as a sibling
        // of the entire content column — means the message text's width
        // below doesn't change when the button appears or disappears, so
        // tapping Follow back never re-wraps the message line.
        Row(
          children: [
            UserAvatar(
              imageUrl: notification.actor.pictureUrl,
              name: notification.actor.displayName,
              placeholderSeed: notification.actor.pubkey,
              size: NotificationConstants.avatarSize,
              cornerRadius: NotificationConstants.avatarCornerRadius,
              onTap: onProfileTap,
              semanticLabel: l10n.notificationsViewProfileSemanticLabel(
                notification.actor.displayName,
              ),
            ),
            if (_showFollowBack) ...[
              const Spacer(),
              // Tiny variant (32px visible) so the row's trailing
              // affordance aligns with the leading 32px type icon and
              // the actor's 32px avatar — keeping the row's intrinsic
              // height stable when the button shows / hides.
              DivineButton(
                label: l10n.notificationFollowBack,
                onPressed: onFollowBack,
                size: DivineButtonSize.tiny,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _MessageText(
          notification: notification,
          timestamp: _hasComment ? null : relativeTime,
        ),
        if (_hasComment) ...[
          const SizedBox(height: 4),
          NotificationCommentQuote(
            text: notification.commentText!,
            timestamp: relativeTime,
          ),
        ],
      ],
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification, this.timestamp});

  final ActorNotification notification;

  /// When non-empty, appended in muted style at the end of the message.
  /// Pass `null` (the default) when a [NotificationCommentQuote] sits
  /// below this widget — the quote renders the timestamp instead, so
  /// the trailing relative time stays anchored to the visual end of
  /// the row.
  final String? timestamp;

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

    final ts = timestamp;
    if (ts != null && ts.isNotEmpty) {
      spans.add(
        TextSpan(
          text: ' $ts',
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted55),
        ),
      );
    }

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
