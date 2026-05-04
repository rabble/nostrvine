// ABOUTME: BLoC-compatible notification list item widget using the sealed
// ABOUTME: NotificationItem model. Matches the Figma notifications design:
// ABOUTME: type-icon column on the left, avatar group above the message text.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/widgets/notification_type_icon.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Row representing a single notification entry. Renders [SingleNotification]
/// and [GroupedNotification] variants with the same outer structure.
class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
    this.onFollowBack,
    super.key,
  });

  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onFollowBack;

  @override
  Widget build(BuildContext context) {
    final showFollowBack = switch (notification) {
      SingleNotification(:final type, :final isFollowingBack) =>
        type == NotificationKind.follow && !isFollowingBack,
      GroupedNotification() => false,
    };

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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LeadingTypeIcon(
                    type: notification.type,
                    showUnreadDot: !notification.isRead,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _NotificationContent(
                      notification: notification,
                      onProfileTap: onProfileTap,
                    ),
                  ),
                  if (showFollowBack) ...[
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

// ---------------------------------------------------------------------------
// Leading type icon — maps NotificationKind → accent pair + DivineIcon.
// ---------------------------------------------------------------------------

class _LeadingTypeIcon extends StatelessWidget {
  const _LeadingTypeIcon({required this.type, required this.showUnreadDot});

  final NotificationKind type;
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

_TypeIconSpec _typeIconSpec(NotificationKind type) {
  return switch (type) {
    NotificationKind.like => const _TypeIconSpec(
      icon: DivineIconName.heart,
      background: VineTheme.accentPinkBackground,
      foreground: VineTheme.accentPink,
    ),
    NotificationKind.follow => const _TypeIconSpec(
      icon: DivineIconName.user,
      background: VineTheme.accentLimeBackground,
      foreground: VineTheme.accentLime,
    ),
    NotificationKind.comment ||
    NotificationKind.reply ||
    NotificationKind.mention => const _TypeIconSpec(
      icon: DivineIconName.chat,
      background: VineTheme.accentVioletBackground,
      foreground: VineTheme.accentViolet,
    ),
    NotificationKind.repost => const _TypeIconSpec(
      icon: DivineIconName.repeat,
      background: VineTheme.accentYellowBackground,
      foreground: VineTheme.accentYellow,
    ),
    NotificationKind.system => const _TypeIconSpec(
      icon: DivineIconName.logo,
      background: VineTheme.onPrimaryButton,
      foreground: VineTheme.primary,
    ),
  };
}

// ---------------------------------------------------------------------------
// Content column: avatar(s) above the message text.
// ---------------------------------------------------------------------------

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.notification,
    this.onProfileTap,
  });

  final NotificationItem notification;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatars(notification: notification, onProfileTap: onProfileTap),
        const SizedBox(height: 8),
        _MessageText(notification: notification),
        if (notification is SingleNotification &&
            (notification as SingleNotification).commentText != null) ...[
          const SizedBox(height: 4),
          _CommentQuote(
            text: (notification as SingleNotification).commentText!,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avatars row — single avatar or overlapping stack for grouped.
// ---------------------------------------------------------------------------

class _Avatars extends StatelessWidget {
  const _Avatars({required this.notification, this.onProfileTap});

  final NotificationItem notification;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return switch (notification) {
      SingleNotification(:final actor) => _SingleAvatarTap(
        actor: actor,
        onProfileTap: onProfileTap,
      ),
      GroupedNotification(:final actors, :final totalCount) => Semantics(
        button: onProfileTap != null,
        label: context.l10n.notificationsViewProfilesSemanticLabel,
        child: GestureDetector(
          onTap: onProfileTap,
          child: NotificationAvatarStack(
            actors: actors,
            overflowCount: (totalCount - actors.length).clamp(0, totalCount),
          ),
        ),
      ),
    };
  }
}

class _SingleAvatarTap extends StatelessWidget {
  const _SingleAvatarTap({required this.actor, this.onProfileTap});

  final ActorInfo actor;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: actor.pictureUrl,
      name: actor.displayName,
      placeholderSeed: actor.pubkey,
      size: NotificationConstants.avatarSize,
      cornerRadius: NotificationConstants.avatarCornerRadius,
      onTap: onProfileTap,
      semanticLabel: context.l10n.notificationsViewProfileSemanticLabel(
        actor.displayName,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message — bold actor names + post titles, regular verbs, muted timestamp.
// ---------------------------------------------------------------------------

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spans = _buildSpans(l10n);
    spans.add(
      TextSpan(
        text: ' ${_relativeShort(l10n, notification.timestamp)}',
        style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted55),
      ),
    );
    return Text.rich(
      TextSpan(children: spans),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  List<InlineSpan> _buildSpans(AppLocalizations l10n) {
    final spans = <InlineSpan>[];
    switch (notification) {
      case SingleNotification(
        :final actor,
        :final type,
        :final videoTitle,
      ):
        if (type == NotificationKind.system) {
          spans.add(
            TextSpan(
              text: l10n.notificationSystemUpdate,
              style: VineTheme.bodyMediumFont(),
            ),
          );
          break;
        }
        spans.add(
          TextSpan(text: actor.displayName, style: VineTheme.labelLargeFont()),
        );
        spans.add(
          TextSpan(
            text: ' ${_verbFor(l10n, type)}',
            style: VineTheme.bodyMediumFont(),
          ),
        );
        if (videoTitle != null && _typeShowsTitle(type)) {
          spans.add(
            TextSpan(text: ' $videoTitle', style: VineTheme.labelLargeFont()),
          );
        }
      case GroupedNotification(
        :final actors,
        :final totalCount,
        :final type,
        :final videoTitle,
      ):
        if (actors.isEmpty) {
          spans.add(
            TextSpan(
              text: l10n.notificationSomeoneLikedYourVideo,
              style: VineTheme.bodyMediumFont(),
            ),
          );
          break;
        }
        spans.add(
          TextSpan(
            text: actors.first.displayName,
            style: VineTheme.labelLargeFont(),
          ),
        );
        final othersCount = totalCount - 1;
        if (othersCount > 0) {
          spans.add(
            TextSpan(
              text: ' ${l10n.notificationAndConnector} ',
              style: VineTheme.bodyMediumFont(),
            ),
          );
          spans.add(
            TextSpan(
              text: l10n.notificationOthersCount(othersCount),
              style: VineTheme.labelLargeFont(),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: ' ${_verbFor(l10n, type)}',
            style: VineTheme.bodyMediumFont(),
          ),
        );
        if (videoTitle != null && _typeShowsTitle(type)) {
          spans.add(
            TextSpan(text: ' $videoTitle', style: VineTheme.labelLargeFont()),
          );
        }
    }
    return spans;
  }
}

bool _typeShowsTitle(NotificationKind type) {
  return type == NotificationKind.like ||
      type == NotificationKind.comment ||
      type == NotificationKind.repost;
}

String _verbFor(AppLocalizations l10n, NotificationKind type) {
  return switch (type) {
    NotificationKind.like => _stripActorPlaceholder(
      l10n.notificationLikedYourVideo(''),
    ),
    NotificationKind.comment => _stripActorPlaceholder(
      l10n.notificationCommentedOnYourVideo(''),
    ),
    NotificationKind.reply => l10n.notificationRepliedToYourComment,
    NotificationKind.follow => _stripActorPlaceholder(
      l10n.notificationStartedFollowing(''),
    ),
    NotificationKind.repost => _stripActorPlaceholder(
      l10n.notificationRepostedYourVideo(''),
    ),
    NotificationKind.mention => _stripActorPlaceholder(
      l10n.notificationMentionedYou(''),
    ),
    NotificationKind.system => '',
  };
}

/// l10n verb keys carry the actor name as a leading `{actorName}` placeholder.
/// Calling them with an empty string leaves a leading separator (a space in
/// English, possibly something different in other locales) — strip it so the
/// caller can prepend its own bold actor name.
String _stripActorPlaceholder(String localized) => localized.trimLeft();

String _relativeShort(AppLocalizations l10n, DateTime timestamp) {
  return LocalizedTimeFormatter.formatRelative(
    l10n,
    timestamp.millisecondsSinceEpoch ~/ 1000,
  );
}

// ---------------------------------------------------------------------------
// Comment quote shown beneath comment / reply messages.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Follow-back button shown on follow notifications.
// ---------------------------------------------------------------------------

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
