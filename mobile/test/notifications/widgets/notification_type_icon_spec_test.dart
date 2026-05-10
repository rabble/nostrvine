// ABOUTME: Locks the NotificationKind → (icon, accent pair) design contract
// ABOUTME: so a future reskin can't silently drift the row palette.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/notification_type_icon_spec.dart';

void main() {
  group('notificationTypeIconSpec', () {
    test('like uses heart on accentPink', () {
      final spec = notificationTypeIconSpec(NotificationKind.like);
      expect(spec.icon, equals(DivineIconName.heart));
      expect(spec.background, equals(VineTheme.accentPinkBackground));
      expect(spec.foreground, equals(VineTheme.accentPink));
    });

    test('likeComment shares the heart accent with like', () {
      final spec = notificationTypeIconSpec(NotificationKind.likeComment);
      expect(spec.icon, equals(DivineIconName.heart));
      expect(spec.background, equals(VineTheme.accentPinkBackground));
      expect(spec.foreground, equals(VineTheme.accentPink));
    });

    test('follow uses user on accentLime', () {
      final spec = notificationTypeIconSpec(NotificationKind.follow);
      expect(spec.icon, equals(DivineIconName.user));
      expect(spec.background, equals(VineTheme.accentLimeBackground));
      expect(spec.foreground, equals(VineTheme.accentLime));
    });

    test('comment uses chat on accentViolet', () {
      final spec = notificationTypeIconSpec(NotificationKind.comment);
      expect(spec.icon, equals(DivineIconName.chat));
      expect(spec.background, equals(VineTheme.accentVioletBackground));
      expect(spec.foreground, equals(VineTheme.accentViolet));
    });

    test('reply shares the chat accent with comment', () {
      final spec = notificationTypeIconSpec(NotificationKind.reply);
      expect(spec.icon, equals(DivineIconName.chat));
      expect(spec.background, equals(VineTheme.accentVioletBackground));
      expect(spec.foreground, equals(VineTheme.accentViolet));
    });

    test('mention shares the chat accent with comment', () {
      final spec = notificationTypeIconSpec(NotificationKind.mention);
      expect(spec.icon, equals(DivineIconName.chat));
      expect(spec.background, equals(VineTheme.accentVioletBackground));
      expect(spec.foreground, equals(VineTheme.accentViolet));
    });

    test('repost uses repeat on accentYellow', () {
      final spec = notificationTypeIconSpec(NotificationKind.repost);
      expect(spec.icon, equals(DivineIconName.repeat));
      expect(spec.background, equals(VineTheme.accentYellowBackground));
      expect(spec.foreground, equals(VineTheme.accentYellow));
    });

    test('system uses logo on the primary accent', () {
      final spec = notificationTypeIconSpec(NotificationKind.system);
      expect(spec.icon, equals(DivineIconName.logo));
      expect(spec.background, equals(VineTheme.onPrimaryButton));
      expect(spec.foreground, equals(VineTheme.primary));
    });

    test('every NotificationKind is covered by the switch', () {
      for (final kind in NotificationKind.values) {
        // Throws if any enum case were missing — the switch is exhaustive
        // by construction, but this ensures the contract still holds when
        // a future enum case is added without updating the helper.
        expect(notificationTypeIconSpec(kind), isA<NotificationTypeIconSpec>());
      }
    });
  });
}
