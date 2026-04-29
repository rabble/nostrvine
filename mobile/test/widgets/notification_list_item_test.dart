// ABOUTME: Widget tests for the legacy NotificationListItem (relay-feed
// ABOUTME: variant) covering type-icon mapping, message rendering, callbacks,
// ABOUTME: and the unread indicator dot.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/notification_list_item.dart';
import 'package:openvine/widgets/notification_type_icon.dart';

bool _richTextContains(WidgetTester tester, String substring) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  for (final rt in richTexts) {
    if (rt.text.toPlainText().contains(substring)) return true;
  }
  return false;
}

bool _hasBoldSpan(WidgetTester tester, String text) {
  for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
    if (_walkSpan(rt.text, text)) return true;
  }
  return false;
}

bool _walkSpan(InlineSpan span, String text) {
  if (span is TextSpan) {
    final weight = span.style?.fontWeight?.value ?? 400;
    if (span.text == text && weight >= 600) {
      return true;
    }
    final children = span.children;
    if (children != null) {
      for (final child in children) {
        if (_walkSpan(child, text)) return true;
      }
    }
  }
  return false;
}

DivineIconName _typeIconName(WidgetTester tester) {
  final icon = tester.widget<NotificationTypeIcon>(
    find.byType(NotificationTypeIcon),
  );
  return icon.icon;
}

void main() {
  group(NotificationListItem, () {
    const testPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testEventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    Widget buildTestWidget({
      required NotificationModel notification,
      VoidCallback? onTap,
      VoidCallback? onProfileTap,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: NotificationListItem(
            notification: notification,
            onTap: onTap ?? () {},
            onProfileTap: onProfileTap,
          ),
        ),
      );
    }

    NotificationModel makeNotification({
      NotificationType type = NotificationType.like,
      String? actorName = 'Alice',
      String? message,
      bool isRead = false,
      Map<String, dynamic>? metadata,
    }) {
      return NotificationModel(
        id: 'notif-1',
        type: type,
        actorPubkey: testPubkey,
        actorName: actorName,
        message: message ?? 'Alice liked your video',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: isRead,
        targetEventId: testEventId,
        metadata: metadata,
      );
    }

    group('type icon', () {
      testWidgets('like uses heart', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification()),
        );
        expect(_typeIconName(tester), DivineIconName.heart);
      });

      testWidgets('comment uses chat', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(type: NotificationType.comment),
          ),
        );
        expect(_typeIconName(tester), DivineIconName.chat);
      });

      testWidgets('follow uses user', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(type: NotificationType.follow),
          ),
        );
        expect(_typeIconName(tester), DivineIconName.user);
      });

      testWidgets('repost uses repeat', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(type: NotificationType.repost),
          ),
        );
        expect(_typeIconName(tester), DivineIconName.repeat);
      });

      testWidgets('mention uses chat', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(type: NotificationType.mention),
          ),
        );
        expect(_typeIconName(tester), DivineIconName.chat);
      });

      testWidgets('system uses logo', (tester) async {
        final notification = NotificationModel(
          id: 'sys-1',
          type: NotificationType.system,
          actorPubkey: testPubkey,
          message: 'System notification',
          timestamp: DateTime.now(),
        );
        await tester.pumpWidget(buildTestWidget(notification: notification));
        expect(_typeIconName(tester), DivineIconName.logo);
      });
    });

    group('message', () {
      testWidgets('renders actor name bold for like', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification()),
        );

        expect(_hasBoldSpan(tester, 'Alice'), isTrue);
      });

      testWidgets('verb is "liked your video" for like', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification()),
        );
        expect(_richTextContains(tester, 'liked your video'), isTrue);
      });

      testWidgets(
        'falls back to default display name when actor name is null',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            buildTestWidget(
              notification: makeNotification(actorName: null),
            ),
          );

          final fallback = UserProfile.defaultDisplayNameFor(testPubkey);
          expect(
            _richTextContains(tester, '$fallback liked your video'),
            isTrue,
          );
        },
      );

      testWidgets('shows comment metadata as quoted text', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(
              type: NotificationType.comment,
              metadata: const {'comment': 'Nice content!'},
            ),
          ),
        );

        expect(find.textContaining('Nice content!'), findsOneWidget);
      });

      testWidgets('renders system message as plain text', (tester) async {
        final notification = NotificationModel(
          id: 'sys-2',
          type: NotificationType.system,
          actorPubkey: testPubkey,
          message: 'You have a new update',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        expect(_richTextContains(tester, 'You have a new update'), isTrue);
      });

      testWidgets('appends short relative timestamp', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification()),
        );

        // 5 minutes ago renders as "5m" via formatRelative.
        expect(_richTextContains(tester, '5m'), isTrue);
      });
    });

    group('unread indicator', () {
      testWidgets('shows unread dot when isRead is false', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification()),
        );

        final icon = tester.widget<NotificationTypeIcon>(
          find.byType(NotificationTypeIcon),
        );
        expect(icon.showUnreadDot, isTrue);
      });

      testWidgets('hides unread dot when isRead is true', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification(isRead: true)),
        );

        final icon = tester.widget<NotificationTypeIcon>(
          find.byType(NotificationTypeIcon),
        );
        expect(icon.showUnreadDot, isFalse);
      });
    });

    group('callbacks', () {
      testWidgets('onTap fires when row is tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(),
            onTap: () => tapped = true,
          ),
        );
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('onProfileTap fires when avatar is tapped', (tester) async {
        var profileTapped = false;
        await tester.pumpWidget(
          buildTestWidget(
            notification: makeNotification(),
            onProfileTap: () => profileTapped = true,
          ),
        );
        await tester.tap(find.bySemanticsLabel(RegExp('View .* profile')));
        await tester.pump();

        expect(profileTapped, isTrue);
      });

      testWidgets('does not crash when onProfileTap is null', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(notification: makeNotification()),
        );
        await tester.tap(find.bySemanticsLabel(RegExp('View .* profile')));
        await tester.pump();

        expect(find.byType(NotificationListItem), findsOneWidget);
      });
    });
  });
}
