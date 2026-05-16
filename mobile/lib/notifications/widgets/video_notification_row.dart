// ABOUTME: One-row layout for VideoNotification — leading 32x32 type icon,
// ABOUTME: avatar stack + bold actor name(s) + verb + bold title +
// ABOUTME: inline timestamp, 56x56 video thumbnail on the right.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/notifications/widgets/notification_actor_spans.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/notifications/widgets/notification_leading_type_icon.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';

/// Maximum stacked actor avatars before showing the overflow circle.
const int _maxStackActors = 3;

/// Displays a single video-anchored notification row.
///
/// Layout: leading 32x32 type icon (left) → avatar stack + message text
/// (center) → 56x56 rounded thumbnail (right). Tap targets are split: tap
/// on the row body fires [onTap] (open the video), tap on the thumbnail
/// fires [onThumbnailTap], tap on the avatar stack fires [onProfileTap].
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

  bool _shouldStackThumbnail(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1) >
        NotificationConstants.largeTextStackThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shouldStackThumbnail = _shouldStackThumbnail(context);
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      showStackedThumbnail: shouldStackThumbnail,
                      onThumbnailTap: onThumbnailTap,
                    ),
                  ),
                  if (!shouldStackThumbnail) ...[
                    const SizedBox(width: 12),
                    NotificationVideoThumbnail(
                      imageUrl: notification.videoThumbnailUrl,
                      title: notification.videoTitle,
                      onTap: onThumbnailTap,
                    ),
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

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({
    required this.notification,
    required this.onProfileTap,
    required this.showStackedThumbnail,
    required this.onThumbnailTap,
  });

  final VideoNotification notification;
  final VoidCallback onProfileTap;
  final bool showStackedThumbnail;
  final VoidCallback onThumbnailTap;

  bool get _hasComment =>
      notification.commentText != null && notification.commentText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overflowCount = notification.totalCount - notification.actors.length;
    // The trailing relative timestamp anchors to the visual end of the
    // row. When a comment quote is rendered, it goes after the quote
    // (NotificationCommentQuote handles that inline). Without a quote,
    // it sits at the end of the message text.
    final relativeTime = LocalizedTimeFormatter.formatRelative(
      l10n,
      notification.timestamp.millisecondsSinceEpoch ~/ 1000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: l10n.notificationsViewProfilesSemanticLabel,
          child: GestureDetector(
            onTap: onProfileTap,
            child: NotificationAvatarStack(
              actors: notification.actors.take(_maxStackActors).toList(),
              overflowCount: overflowCount > 0 ? overflowCount : null,
            ),
          ),
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
        if (showStackedThumbnail) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: NotificationVideoThumbnail(
              imageUrl: notification.videoThumbnailUrl,
              title: notification.videoTitle,
              onTap: onThumbnailTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.notification, this.timestamp});

  final VideoNotification notification;

  /// When non-empty, appended in muted style at the end of the message.
  /// Pass `null` (the default) when a [NotificationCommentQuote] sits
  /// below this widget — the quote renders the timestamp instead, so it
  /// stays anchored to the visual end of the row.
  final String? timestamp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spans = <InlineSpan>[];
    final actors = notification.actors;
    final type = notification.type;
    final videoTitle = notification.videoTitle;
    final othersCount = notification.totalCount - 1;

    if (othersCount == 0) {
      spans.addAll(
        localizedActorSentenceSpans(
          fullText: _messageFor(l10n, type, actors.first.displayName),
          actorName: actors.first.displayName,
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: actors.first.displayName,
          style: VineTheme.labelLargeFont(),
        ),
      );
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
      spans.add(
        TextSpan(
          text: ' ${_verbFor(l10n, type)}',
          style: VineTheme.bodyMediumFont(),
        ),
      );
    }

    if (videoTitle != null && _typeShowsTitle(type)) {
      spans.add(
        TextSpan(text: ' $videoTitle', style: VineTheme.labelLargeFont()),
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

/// Whether the row should append the bold video title after the verb.
///
/// `likeComment` is intentionally excluded: comment-likes are routed
/// through `ActorNotification` and have no associated video title here;
/// even if the dispatcher routes one to this row, suppressing the title
/// keeps the message accurate.
bool _typeShowsTitle(NotificationKind type) {
  return type == NotificationKind.like ||
      type == NotificationKind.comment ||
      type == NotificationKind.repost;
}

/// Returns just the verb portion (no actor name) for inline composition.
///
/// l10n verb keys carry the actor name as a leading `{actorName}`
/// placeholder. Calling them with an empty string and trimming the leading
/// separator yields just the verb that the caller can prepend a bold actor
/// span to.
String _verbFor(AppLocalizations l10n, NotificationKind type) {
  return switch (type) {
    NotificationKind.like => l10n.notificationLikedYourVideo('').trimLeft(),
    NotificationKind.likeComment =>
      l10n.notificationLikedYourComment('').trimLeft(),
    NotificationKind.comment =>
      l10n.notificationCommentedOnYourVideo('').trimLeft(),
    NotificationKind.repost =>
      l10n.notificationRepostedYourVideo('').trimLeft(),
    // VideoNotification asserts type ∈ {like, likeComment, comment,
    // repost}; the remaining cases satisfy switch exhaustivity only.
    NotificationKind.reply ||
    NotificationKind.follow ||
    NotificationKind.mention ||
    NotificationKind.system => '',
  };
}

String _messageFor(
  AppLocalizations l10n,
  NotificationKind type,
  String actorName,
) {
  return switch (type) {
    NotificationKind.like => l10n.notificationLikedYourVideo(actorName),
    NotificationKind.likeComment => l10n.notificationLikedYourComment(
      actorName,
    ),
    NotificationKind.comment => l10n.notificationCommentedOnYourVideo(
      actorName,
    ),
    NotificationKind.repost => l10n.notificationRepostedYourVideo(actorName),
    NotificationKind.reply ||
    NotificationKind.follow ||
    NotificationKind.mention ||
    NotificationKind.system => '',
  };
}
