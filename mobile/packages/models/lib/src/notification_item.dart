// ABOUTME: Sealed notification domain model. Subtypes live in sibling
// ABOUTME: files video_notification.dart and actor_notification.dart.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/src/actor_info.dart';

part 'video_notification.dart';
part 'actor_notification.dart';

/// Notification kinds matching the Figma design spec.
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
    this.sourceEventIds = const [],
    this.notificationIds = const [],
  });

  final String id;
  final NotificationKind type;
  final DateTime timestamp;
  final bool isRead;
  final String? targetEventId;

  /// Underlying Nostr event ids that this item represents.
  ///
  /// Items carry the server's UUID in [id] and the Nostr event id in
  /// [sourceEventIds]. Cross-page snapshot dedupe in
  /// `NotificationRepository._emitSnapshotForPage` keys on overlap in this
  /// set rather than [id] equality so a logical event delivered as
  /// distinct rows across pages resolves to a single rendered row. For
  /// grouped video notifications this is the union of all underlying
  /// likes/comments/reposts contributing to the row.
  final List<String> sourceEventIds;

  /// Raw relay notification ids represented by this rendered row.
  ///
  /// Grouped rows can stand in for multiple server notifications. Mark-read
  /// writes must send every underlying raw id or a later refresh can
  /// resurrect unread state for the same visible row.
  final List<String> notificationIds;
}
