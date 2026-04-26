// ABOUTME: Widget for displaying individual notification items in the notifications list
// ABOUTME: Shows actor avatar, notification message, timestamp, and action buttons

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/theme/app_theme.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

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
              // Avatar or icon
              _buildLeadingWidget(),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main message
                    _buildMessage(context),
                    const SizedBox(height: 4),

                    // Additional content (comment text, etc.)
                    if (_hasAdditionalContent()) ...[
                      const SizedBox(height: 4),
                      _buildAdditionalContent(),
                    ],

                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      LocalizedTimeFormatter.formatNotificationTimestamp(
                        context.l10n,
                        notification.timestamp,
                        context: context,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: VineTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ),

              // Thumbnail or action button
              if (notification.targetVideoThumbnail != null)
                _buildVideoThumbnail(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget() {
    if (notification.type == NotificationType.system) {
      // System notification icon
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: VineTheme.cardBackground,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            notification.typeIcon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      );
    }

    // User avatar with overlay icon
    return Semantics(
      label: notification.actorName != null
          ? 'View ${notification.actorName} profile'
          : 'View profile',
      button: true,
      child: GestureDetector(
        onTap: onProfileTap,
        child: Stack(
          children: [
            // Avatar
            ClipOval(
              child: notification.actorPictureUrl != null
                  ? VineCachedImage(
                      imageUrl: notification.actorPictureUrl!,
                      width: 48,
                      height: 48,
                      placeholder: (context, url) => Container(
                        width: 48,
                        height: 48,
                        color: VineTheme.cardBackground,
                      ),
                      errorWidget: (context, url, error) {
                        // Log the failed URL for debugging
                        if (error.toString().contains('Invalid image data') ||
                            error.toString().contains('Image codec failed')) {
                          Log.warning(
                            'Invalid image data for actor avatar URL: $url - Error: $error',
                            name: 'NotificationListItem',
                            category: LogCategory.ui,
                          );
                        } else {
                          Log.debug(
                            'Actor avatar load failed, URL: $url - Error: $error',
                            name: 'NotificationListItem',
                            category: LogCategory.ui,
                          );
                        }
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),

            // Type icon overlay
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(),
                  shape: BoxShape.circle,
                  border: Border.all(width: 2),
                ),
                child: Center(
                  child: Text(
                    notification.typeIcon,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: DivineTheme.primaryPurple.withValues(alpha: 0.2),
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Icon(Icons.person, color: DivineTheme.primaryPurple, size: 24),
    ),
  );

  Widget _buildMessage(BuildContext context) {
    final textStyle = VineTheme.bodyMediumFont();
    final message = _displayMessage(context);

    final actorName = notification.actorName;
    if (_messageStartsWithActorName(actorName, message)) {
      // Build rich text with bold actor name
      return RichText(
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(
          style: textStyle,
          children: [
            TextSpan(
              text: actorName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: message.substring(actorName!.length)),
          ],
        ),
      );
    }

    return Text(message, style: textStyle);
  }

  String _displayMessage(BuildContext context) {
    final actorName = notification.actorName;
    final displayName = actorName?.isNotEmpty == true
        ? actorName!
        : UserProfile.defaultDisplayNameFor(notification.actorPubkey);

    return switch (notification.type) {
      NotificationType.like => context.l10n.notificationLikedYourVideo(
        displayName,
      ),
      NotificationType.comment => context.l10n.notificationCommentedOnYourVideo(
        displayName,
      ),
      NotificationType.follow => context.l10n.notificationStartedFollowing(
        displayName,
      ),
      NotificationType.mention => context.l10n.notificationMentionedYou(
        displayName,
      ),
      NotificationType.repost => context.l10n.notificationRepostedYourVideo(
        displayName,
      ),
      NotificationType.system => notification.message,
    };
  }

  bool _messageStartsWithActorName(String? actorName, String message) {
    if (actorName == null) return false;
    return message == actorName || message.startsWith('$actorName ');
  }

  bool _hasAdditionalContent() {
    if (notification.type == NotificationType.comment) {
      return notification.metadata?['comment'] != null;
    } else if (notification.type == NotificationType.mention) {
      return notification.metadata?['text'] != null;
    }
    return false;
  }

  Widget _buildAdditionalContent() {
    String? content;

    if (notification.type == NotificationType.comment) {
      content = notification.metadata?['comment'] as String?;
    } else if (notification.type == NotificationType.mention) {
      content = notification.metadata?['text'] as String?;
    }

    if (content == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        content,
        style: const TextStyle(fontSize: 13, color: VineTheme.secondaryText),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildVideoThumbnail() => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: VineCachedImage(
        imageUrl: notification.targetVideoThumbnail!,
        width: 64,
        height: 64,
        placeholder: (context, url) => Container(
          width: 64,
          height: 64,
          color: VineTheme.cardBackground,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) {
          // Log the failed URL for debugging
          if (error.toString().contains('Invalid image data') ||
              error.toString().contains('Image codec failed')) {
            Log.warning(
              'Invalid image data for video thumbnail URL: $url - Error: $error',
              name: 'NotificationListItem',
              category: LogCategory.ui,
            );
          } else {
            Log.debug(
              'Video thumbnail load failed, URL: $url - Error: $error',
              name: 'NotificationListItem',
              category: LogCategory.ui,
            );
          }
          return Container(
            width: 64,
            height: 64,
            color: VineTheme.cardBackground,
            child: const Icon(Icons.video_library, color: VineTheme.lightText),
          );
        },
      ),
    ),
  );

  Color _getIconBackgroundColor() {
    switch (notification.type) {
      case NotificationType.like:
        return VineTheme.error;
      case NotificationType.comment:
        return VineTheme.info;
      case NotificationType.follow:
        return DivineTheme.primaryPurple;
      case NotificationType.mention:
        return VineTheme.warning;
      case NotificationType.repost:
        return VineTheme.vineGreen;
      case NotificationType.system:
        return VineTheme.lightText;
    }
  }
}
