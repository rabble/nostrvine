// ABOUTME: Notification list item used by the legacy relay-based feed inside
// ABOUTME: the inbox tab. Renders the Figma layout (type icon column, avatar
// ABOUTME: above the message) on top of the [NotificationModel] data shape.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/widgets/notification_type_icon.dart';
import 'package:openvine/widgets/user_avatar.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
    super.key,
  });

  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: .transparency,
      child: Semantics(
        button: true,
        container: true,
        label: notification.isRead
            ? null
            : context.l10n.notificationsUnreadPrefix,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: VineTheme.outlineDisabled),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                spacing: 16,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LeadingTypeIcon(
                    type: notification.type,
                    showUnreadDot: !notification.isRead,
                  ),
                  Expanded(
                    child: _Content(
                      notification: notification,
                      onProfileTap: onProfileTap,
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

// ---------------------------------------------------------------------------
// Leading type icon — maps NotificationType → accent pair + DivineIcon.
// ---------------------------------------------------------------------------

class _LeadingTypeIcon extends StatelessWidget {
  const _LeadingTypeIcon({required this.type, required this.showUnreadDot});

  final NotificationType type;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    final spec = _typeIconSpec(type);
    return NotificationTypeIcon(
      icon: spec.icon,
      backgroundColor: spec.background,
      foregroundColor: spec.foreground,
      showUnreadDot: showUnreadDot,
    );
  }
}

class _TypeIconSpec {
  const _TypeIconSpec({
    required this.icon,
    required this.background,
    required this.foreground,
  });
  final DivineIconName icon;
  final Color background;
  final Color foreground;
}

_TypeIconSpec _typeIconSpec(NotificationType type) {
  return switch (type) {
    NotificationType.like => const _TypeIconSpec(
      icon: DivineIconName.heart,
      background: VineTheme.accentPinkBackground,
      foreground: VineTheme.accentPink,
    ),
    NotificationType.follow => const _TypeIconSpec(
      icon: DivineIconName.user,
      background: VineTheme.accentLimeBackground,
      foreground: VineTheme.accentLime,
    ),
    NotificationType.comment || NotificationType.mention => const _TypeIconSpec(
      icon: DivineIconName.chat,
      background: VineTheme.accentVioletBackground,
      foreground: VineTheme.accentViolet,
    ),
    NotificationType.repost => const _TypeIconSpec(
      icon: DivineIconName.repeat,
      background: VineTheme.accentYellowBackground,
      foreground: VineTheme.accentYellow,
    ),
    NotificationType.system => const _TypeIconSpec(
      icon: DivineIconName.logo,
      background: VineTheme.onPrimaryButton,
      foreground: VineTheme.primary,
    ),
  };
}

// ---------------------------------------------------------------------------
// Content column — avatar above message text, with optional comment quote.
// ---------------------------------------------------------------------------

class _Content extends StatelessWidget {
  const _Content({required this.notification, this.onProfileTap});

  final NotificationModel notification;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final commentText = _commentText();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notification.type != NotificationType.system) ...[
          _AvatarTap(notification: notification, onProfileTap: onProfileTap),
          const SizedBox(height: 8),
        ],
        _MessageText(notification: notification),
        if (commentText != null) ...[
          const SizedBox(height: 4),
          _CommentQuote(text: commentText),
        ],
      ],
    );
  }

  String? _commentText() {
    if (notification.type == NotificationType.comment) {
      return notification.metadata?['comment'] as String?;
    }
    if (notification.type == NotificationType.mention) {
      return notification.metadata?['text'] as String?;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Avatar — uses the shared UserAvatar so the deterministic placeholder
// matches what the profile screen shows for users without a picture.
// ---------------------------------------------------------------------------

class _AvatarTap extends StatelessWidget {
  const _AvatarTap({required this.notification, this.onProfileTap});

  final NotificationModel notification;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final displayName =
        notification.actorName ??
        UserProfile.defaultDisplayNameFor(notification.actorPubkey);
    return UserAvatar(
      imageUrl: notification.actorPictureUrl,
      name: displayName,
      placeholderSeed: notification.actorPubkey,
      size: NotificationConstants.avatarSize,
      cornerRadius: NotificationConstants.avatarCornerRadius,
      onTap: onProfileTap,
      semanticLabel: context.l10n.notificationsViewProfileSemanticLabel(
        displayName,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message — bold actor name, regular verb, muted timestamp.
// ---------------------------------------------------------------------------

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spans = <InlineSpan>[];
    final base = VineTheme.bodyMediumFont();
    final bold = VineTheme.labelLargeFont();

    if (notification.type == NotificationType.system) {
      spans.add(TextSpan(text: notification.message, style: base));
    } else {
      final actorName = notification.actorName?.isNotEmpty == true
          ? notification.actorName!
          : UserProfile.defaultDisplayNameFor(notification.actorPubkey);
      spans.add(TextSpan(text: actorName, style: bold));
      spans.add(
        TextSpan(text: ' ${_verb(l10n, notification.type)}', style: base),
      );
    }

    spans.add(
      TextSpan(
        text:
            ' ${LocalizedTimeFormatter.formatRelative(
              l10n,
              notification.timestamp.millisecondsSinceEpoch ~/ 1000,
            )}',
        style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted55),
      ),
    );

    return Text.rich(
      TextSpan(children: spans),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  String _verb(AppLocalizations l10n, NotificationType type) {
    return switch (type) {
      NotificationType.like => l10n.notificationLikedYourVideo('').trimLeft(),
      NotificationType.comment =>
        l10n.notificationCommentedOnYourVideo('').trimLeft(),
      NotificationType.follow =>
        l10n.notificationStartedFollowing('').trimLeft(),
      NotificationType.mention => l10n.notificationMentionedYou('').trimLeft(),
      NotificationType.repost =>
        l10n.notificationRepostedYourVideo('').trimLeft(),
      NotificationType.system => '',
    };
  }
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
