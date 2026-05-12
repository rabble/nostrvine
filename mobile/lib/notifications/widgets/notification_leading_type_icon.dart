// ABOUTME: Leading 32×32 type indicator at the start of every notification
// ABOUTME: row. Looks up the (icon, accent pair) for a NotificationKind via
// ABOUTME: notificationTypeIconSpec and renders NotificationTypeIcon with
// ABOUTME: the unread red dot driven by isRead.

import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/notification_type_icon_spec.dart';
import 'package:openvine/widgets/notification_type_icon.dart';

/// Leading type indicator at the start of a notification row.
///
/// Combines [notificationTypeIconSpec] (the design contract mapping
/// [NotificationKind] → accent pair + icon) with [NotificationTypeIcon]
/// (the rounded-square primitive) so both row variants —
/// `ActorNotificationRow` and `VideoNotificationRow` — share a single
/// implementation. The unread red dot is driven by [isRead].
class NotificationLeadingTypeIcon extends StatelessWidget {
  /// Creates a [NotificationLeadingTypeIcon].
  const NotificationLeadingTypeIcon({
    required this.type,
    required this.isRead,
    super.key,
  });

  /// The notification's kind. Determines which accent pair the icon uses.
  final NotificationKind type;

  /// Whether the notification has been read. When false, an unread red
  /// dot overlays the badge's top-right corner.
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final spec = notificationTypeIconSpec(type);
    return NotificationTypeIcon(
      icon: spec.icon,
      backgroundColor: spec.background,
      foregroundColor: spec.foreground,
      showUnreadDot: !isRead,
    );
  }
}
