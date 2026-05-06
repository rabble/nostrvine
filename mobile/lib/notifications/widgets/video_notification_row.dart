// ABOUTME: One-row layout for VideoNotification — avatar stack on the left,
// ABOUTME: message + timestamp in the middle, 56x56 video thumbnail on right.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:time_formatter/time_formatter.dart';

/// Diameter of the video thumbnail on the right of the row.
const double _thumbnailSize = 56;

/// Maximum stacked actor avatars before showing the overflow circle.
const int _maxStackActors = 3;

/// Memory-cache decode width for the thumbnail (~3.5x at 2x DPI).
const int _thumbnailMemCacheWidth = 200;

/// Displays a single video-anchored notification row.
///
/// Layout: avatar stack (left) → message + relative timestamp (center) →
/// 56x56 rounded thumbnail (right). Tap targets are split: tap on the
/// row body fires [onTap] (open the video), tap on the thumbnail fires
/// [onThumbnailTap], tap on the avatar stack fires [onProfileTap].
class VideoNotificationRow extends StatelessWidget {
  /// Creates a [VideoNotificationRow].
  const VideoNotificationRow({
    required this.notification,
    required this.onTap,
    required this.onProfileTap,
    required this.onThumbnailTap,
    super.key,
  });

  /// The video-anchored notification to render.
  final VideoNotification notification;

  /// Called when the row body is tapped.
  final VoidCallback onTap;

  /// Called when the avatar stack is tapped.
  final VoidCallback onProfileTap;

  /// Called when the thumbnail on the right is tapped.
  final VoidCallback onThumbnailTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overflowCount = notification.totalCount - notification.actors.length;
    final firstName = notification.actors.first.displayName;
    final othersCount = notification.totalCount - 1;
    final message = othersCount <= 0
        ? _verbWithActor(l10n, notification.type, firstName)
        : '$firstName ${l10n.notificationAndConnector} '
              '${l10n.notificationOthersCount(othersCount)} '
              '${_verb(l10n, notification.type)}';

    return Material(
      color: notification.isRead
          ? VineTheme.backgroundColor
          : VineTheme.cardBackground,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: NotificationAvatarStack(
                  actors: notification.actors.take(_maxStackActors).toList(),
                  overflowCount: overflowCount > 0 ? overflowCount : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: VineTheme.bodyMediumFont()),
                    const SizedBox(height: 4),
                    Text(
                      TimeFormatter.formatRelativeVerbose(
                        notification.timestamp.millisecondsSinceEpoch ~/ 1000,
                      ),
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Thumbnail(
                key: const Key('video_notification_thumbnail'),
                imageUrl: notification.videoThumbnailUrl,
                title: notification.videoTitle,
                onTap: onThumbnailTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds the localized "{actor} {verb}" string for a single-actor row.
String _verbWithActor(
  AppLocalizations l10n,
  NotificationKind type,
  String actor,
) {
  return switch (type) {
    NotificationKind.like => l10n.notificationLikedYourVideo(actor),
    NotificationKind.likeComment => l10n.notificationLikedYourComment(actor),
    NotificationKind.comment => l10n.notificationCommentedOnYourVideo(actor),
    NotificationKind.repost => l10n.notificationRepostedYourVideo(actor),
    // The repository asserts that VideoNotification.type is one of the
    // four above; the remaining cases satisfy switch exhaustivity only.
    NotificationKind.reply ||
    NotificationKind.follow ||
    NotificationKind.mention ||
    NotificationKind.system => actor,
  };
}

/// Returns just the verb portion (no actor name) for the multi-actor
/// "{first} and N others {verb}" composition.
String _verb(AppLocalizations l10n, NotificationKind type) {
  return _verbWithActor(l10n, type, '').trimLeft();
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    super.key,
  });

  final String? imageUrl;
  final String? title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title != null ? 'Video thumbnail for $title' : 'Video thumbnail',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _thumbnailSize,
            height: _thumbnailSize,
            child: imageUrl != null
                ? VineCachedImage(
                    imageUrl: imageUrl!,
                    memCacheWidth: _thumbnailMemCacheWidth,
                  )
                : const ColoredBox(color: VineTheme.cardBackground),
          ),
        ),
      ),
    );
  }
}
