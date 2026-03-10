// ABOUTME: Redesigned notification list item widget matching the Figma design.
// ABOUTME: Uses colored type icons, inline rich text with avatars, and
// ABOUTME: timestamps per notification type.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/services/image_cache_manager.dart';

/// Redesigned notification item matching the Figma spec.
///
/// Renders a leading type icon, inline rich text with avatar(s), username,
/// action description, optional video title, timestamp, and an unread dot.
class NotificationItemRedesigned extends StatelessWidget {
  /// Creates a [NotificationItemRedesigned].
  const NotificationItemRedesigned({
    required this.notification,
    required this.onTap,
    super.key,
  });

  /// The notification data to display.
  final NotificationModel notification;

  /// Callback invoked when the item is tapped.
  final VoidCallback onTap;

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
                  _LeadingIconArea(notification: notification),
                  const SizedBox(width: 16),
                  Expanded(child: _ContentArea(notification: notification)),
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

// ---------------------------------------------------------------------------
// Leading icon area with unread dot
// ---------------------------------------------------------------------------

class _LeadingIconArea extends StatelessWidget {
  const _LeadingIconArea({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _TypeIcon(type: notification.type),
          if (!notification.isRead) const _UnreadDot(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type icon (24x24 container, 8px radius, type-specific bg colour)
// ---------------------------------------------------------------------------

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final NotificationType type;

  @override
  Widget build(BuildContext context) {
    final config = _iconConfig(type);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(config.icon, size: 16, color: config.iconColor),
      ),
    );
  }

  static _IconConfig _iconConfig(NotificationType type) {
    return switch (type) {
      NotificationType.follow => const _IconConfig(
        backgroundColor: VineTheme.accentLimeBackground,
        icon: Icons.person_add_rounded,
        iconColor: VineTheme.accentLime,
      ),
      NotificationType.comment => const _IconConfig(
        backgroundColor: VineTheme.accentVioletBackground,
        icon: Icons.chat_bubble_rounded,
        iconColor: VineTheme.accentViolet,
      ),
      NotificationType.like => const _IconConfig(
        backgroundColor: VineTheme.accentPinkBackground,
        icon: Icons.favorite_rounded,
        iconColor: VineTheme.accentPink,
      ),
      NotificationType.repost => const _IconConfig(
        backgroundColor: VineTheme.accentYellowBackground,
        icon: Icons.repeat_rounded,
        iconColor: VineTheme.accentYellow,
      ),
      NotificationType.mention => const _IconConfig(
        backgroundColor: VineTheme.accentBlueBackground,
        icon: Icons.alternate_email_rounded,
        iconColor: VineTheme.accentBlue,
      ),
      NotificationType.system => const _IconConfig(
        backgroundColor: VineTheme.onPrimaryButton,
        icon: Icons.campaign_rounded,
        iconColor: VineTheme.vineGreen,
      ),
    };
  }
}

class _IconConfig {
  const _IconConfig({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
}

// ---------------------------------------------------------------------------
// Unread dot (8px red circle at top-left of the leading icon area)
// ---------------------------------------------------------------------------

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -4,
      left: -4,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: VineTheme.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content area: inline rich text with avatar, username, action, timestamp
// ---------------------------------------------------------------------------

class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRichContent(),
        if (_hasSupportingText()) ...[
          const SizedBox(height: 4),
          _SupportingText(notification: notification),
        ],
      ],
    );
  }

  bool _hasSupportingText() {
    if (notification.type == NotificationType.comment) {
      return notification.metadata?['comment'] != null;
    }
    if (notification.type == NotificationType.mention) {
      return notification.metadata?['text'] != null;
    }
    if (notification.type == NotificationType.system) {
      return notification.metadata?['body'] != null;
    }
    return false;
  }

  Widget _buildRichContent() {
    return switch (notification.type) {
      NotificationType.system => _SystemContent(notification: notification),
      _ => _StandardContent(notification: notification),
    };
  }
}

// ---------------------------------------------------------------------------
// Standard content (follow / like / comment / repost / mention)
// ---------------------------------------------------------------------------

class _StandardContent extends StatelessWidget {
  const _StandardContent({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final actionText = _actionText();
    final videoTitle = _videoTitle();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _ActorAvatar(pictureUrl: notification.actorPictureUrl),
        Text(
          notification.actorName ?? 'Someone',
          style: VineTheme.titleMediumFont(fontSize: 16, height: 24 / 16),
        ),
        Text(actionText, style: VineTheme.bodyLargeFont()),
        if (videoTitle != null)
          Text(
            videoTitle,
            style: VineTheme.titleMediumFont(fontSize: 16, height: 24 / 16),
          ),
        Text(
          notification.formattedTimestamp,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
        ),
      ],
    );
  }

  String _actionText() {
    return switch (notification.type) {
      NotificationType.follow => 'started following you',
      NotificationType.like => 'liked your video',
      NotificationType.comment => 'commented on your video',
      NotificationType.repost => 'reposted your video',
      NotificationType.mention => 'mentioned you in',
      NotificationType.system => '',
    };
  }

  String? _videoTitle() {
    if (notification.type == NotificationType.follow) return null;

    final title = notification.metadata?['videoTitle'] as String?;
    return title;
  }
}

// ---------------------------------------------------------------------------
// System / announcement content
// ---------------------------------------------------------------------------

class _SystemContent extends StatelessWidget {
  const _SystemContent({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final hashtag = notification.metadata?['hashtag'] as String?;
    final title = notification.metadata?['title'] as String?;

    if (title != null) {
      // Flagged-style: bold title + body below
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(fontSize: 16, height: 24 / 16),
          ),
          const SizedBox(height: 4),
          Text(
            notification.formattedTimestamp,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
          ),
        ],
      );
    }

    // Announcement-style with optional hashtag pill
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        Text(notification.message, style: VineTheme.bodyLargeFont()),
        if (hashtag != null) _HashtagPill(tag: hashtag),
        Text(
          notification.formattedTimestamp,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hashtag pill for announcement-type notifications
// ---------------------------------------------------------------------------

class _HashtagPill extends StatelessWidget {
  const _HashtagPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#', style: VineTheme.titleSmallFont(color: VineTheme.primary)),
          Text(tag, style: VineTheme.titleSmallFont()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actor avatar (24x24 circular, 12px radius)
// ---------------------------------------------------------------------------

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({this.pictureUrl});

  final String? pictureUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: pictureUrl != null
          ? CachedNetworkImage(
              imageUrl: pictureUrl!,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              cacheManager: openVineImageCache,
              placeholder: (context, url) => const _AvatarPlaceholder(),
              errorWidget: (context, url, error) => const _AvatarPlaceholder(),
            )
          : const _AvatarPlaceholder(),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: VineTheme.cardBackground,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.person, size: 14, color: VineTheme.lightText),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting text (comment preview, mention text, system body)
// ---------------------------------------------------------------------------

class _SupportingText extends StatelessWidget {
  const _SupportingText({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    String? content;

    if (notification.type == NotificationType.comment) {
      content = notification.metadata?['comment'] as String?;
    } else if (notification.type == NotificationType.mention) {
      content = notification.metadata?['text'] as String?;
    } else if (notification.type == NotificationType.system) {
      content = notification.metadata?['body'] as String?;
    }

    if (content == null) return const SizedBox.shrink();

    return Text(
      content,
      style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
