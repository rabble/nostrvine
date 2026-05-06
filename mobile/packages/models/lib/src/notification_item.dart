// ABOUTME: Sealed notification domain model. Subtypes live in sibling
// ABOUTME: files video_notification.dart and actor_notification.dart.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/src/actor_info.dart';

part 'video_notification.dart';
part 'actor_notification.dart';

/// Notification kinds matching the Figma design spec.
///
/// Named `NotificationKind` to avoid conflict with the legacy
/// `NotificationType` enum in `notification_model.dart`.
enum NotificationKind {
  like,
  likeComment,
  comment,
  reply,
  follow,
  repost,
  mention,
  system,
}

/// Base for all displayable notifications.
///
/// Sealed so the UI can exhaustively switch on subtypes:
/// [VideoNotification] (video-anchored: like/comment/repost) or
/// [ActorNotification] (actor-anchored: follow/mention/system).
///
/// The model intentionally does NOT carry a `message` getter — the UI
/// layer composes localized strings via `context.l10n` so this
/// Flutter-free package never leaks English copy.
sealed class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetEventId,
  });

  final String id;
  final NotificationKind type;
  final DateTime timestamp;
  final bool isRead;
  final String? targetEventId;
}
