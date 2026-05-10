// ABOUTME: Maps NotificationKind to the (icon, background, foreground)
// ABOUTME: triple used by the leading 32×32 type indicator on every row.
//
// Single source of truth for the design contract. Adding a new
// NotificationKind is a compile error here — and a regression test in
// notification_type_icon_spec_test.dart locks the mapping so it can't
// silently drift again.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:models/models.dart';

/// Triple (icon, background, foreground) consumed by [NotificationTypeIcon].
class NotificationTypeIconSpec {
  const NotificationTypeIconSpec({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final DivineIconName icon;
  final Color background;
  final Color foreground;
}

/// Returns the spec for [type] used by both row widgets.
NotificationTypeIconSpec notificationTypeIconSpec(NotificationKind type) {
  return switch (type) {
    NotificationKind.like ||
    NotificationKind.likeComment => const NotificationTypeIconSpec(
      icon: DivineIconName.heart,
      background: VineTheme.accentPinkBackground,
      foreground: VineTheme.accentPink,
    ),
    NotificationKind.follow => const NotificationTypeIconSpec(
      icon: DivineIconName.user,
      background: VineTheme.accentLimeBackground,
      foreground: VineTheme.accentLime,
    ),
    NotificationKind.comment ||
    NotificationKind.reply ||
    NotificationKind.mention => const NotificationTypeIconSpec(
      icon: DivineIconName.chat,
      background: VineTheme.accentVioletBackground,
      foreground: VineTheme.accentViolet,
    ),
    NotificationKind.repost => const NotificationTypeIconSpec(
      icon: DivineIconName.repeat,
      background: VineTheme.accentYellowBackground,
      foreground: VineTheme.accentYellow,
    ),
    NotificationKind.system => const NotificationTypeIconSpec(
      icon: DivineIconName.logo,
      background: VineTheme.onPrimaryButton,
      foreground: VineTheme.primary,
    ),
  };
}
