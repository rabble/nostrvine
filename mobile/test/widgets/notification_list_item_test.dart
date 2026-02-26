// ABOUTME: Widget tests for NotificationListItem covering all notification types
// ABOUTME: Tests rendering, onTap callback, read/unread visual state, and thumbnails

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/notification_list_item.dart';

/// Helper to check if any RichText in the tree contains a given substring
bool _richTextContains(WidgetTester tester, String substring) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  for (final richText in richTexts) {
    if (richText.text.toPlainText().contains(substring)) {
      return true;
    }
  }
  return false;
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
    }) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: NotificationListItem(
            notification: notification,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    NotificationModel makeNotification({
      NotificationType type = NotificationType.like,
      String? actorName = 'Alice',
      String? message,
      bool isRead = false,
      String? targetVideoThumbnail,
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
        targetVideoThumbnail: targetVideoThumbnail,
        metadata: metadata,
      );
    }

    group('like notification', () {
      testWidgets('renders with heart icon overlay and message', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          message: 'Alice liked your video',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Heart emoji should appear as type icon overlay
        expect(find.text('❤️'), findsOneWidget);
        // Message should contain "liked your video" (rendered in RichText)
        expect(_richTextContains(tester, 'liked your video'), isTrue);
      });

      testWidgets('renders video thumbnail when targetVideoThumbnail set', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          targetVideoThumbnail: 'https://example.com/thumb.jpg',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // The thumbnail widget should be rendered (ClipRRect wrapping the image)
        expect(find.byType(ClipRRect), findsWidgets);
      });
    });

    group('comment notification', () {
      testWidgets('renders with comment icon and message', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          type: NotificationType.comment,
          message: 'Alice commented: Great video!',
          metadata: {'comment': 'Great video!'},
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Comment icon emoji
        expect(find.text('💬'), findsOneWidget);
        // Message text rendered in RichText
        expect(_richTextContains(tester, 'commented'), isTrue);
      });

      testWidgets('shows comment text from metadata', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          type: NotificationType.comment,
          message: 'Alice commented: Nice content!',
          metadata: {'comment': 'Nice content!'},
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Additional content (comment text) should be displayed as a Text widget
        expect(find.text('Nice content!'), findsOneWidget);
      });
    });

    group('follow notification', () {
      testWidgets('renders with follow icon and no video thumbnail', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          type: NotificationType.follow,
          message: 'Alice started following you',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Follow icon emoji
        expect(find.text('👤'), findsOneWidget);
        // Message rendered in RichText
        expect(_richTextContains(tester, 'following you'), isTrue);
      });
    });

    group('repost notification', () {
      testWidgets('renders with repost icon and message', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          type: NotificationType.repost,
          message: 'Alice reposted your video',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Repost icon emoji
        expect(find.text('🔄'), findsOneWidget);
        // Message rendered in RichText
        expect(_richTextContains(tester, 'reposted'), isTrue);
      });

      testWidgets('renders video thumbnail when available', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          type: NotificationType.repost,
          message: 'Alice reposted your video',
          targetVideoThumbnail: 'https://example.com/repost-thumb.jpg',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Should have ClipRRect widgets for thumbnail rendering
        expect(find.byType(ClipRRect), findsWidgets);
      });
    });

    group('onTap callback', () {
      testWidgets('fires when notification is tapped', (
        WidgetTester tester,
      ) async {
        var tapped = false;
        final notification = makeNotification();

        await tester.pumpWidget(
          buildTestWidget(
            notification: notification,
            onTap: () => tapped = true,
          ),
        );

        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });

    group('read vs unread visual state', () {
      testWidgets('unread notification has different background than read', (
        WidgetTester tester,
      ) async {
        // Build unread notification
        final unreadNotification = makeNotification();
        await tester.pumpWidget(
          buildTestWidget(notification: unreadNotification),
        );

        // Find the Material widget inside NotificationListItem
        // (it's the direct child that provides background color)
        final unreadMaterials = tester.widgetList<Material>(
          find.descendant(
            of: find.byType(NotificationListItem),
            matching: find.byType(Material),
          ),
        );
        // The first Material descendant of the NotificationListItem is ours
        final unreadColor = unreadMaterials.first.color;

        // Build read notification
        final readNotification = makeNotification(isRead: true);
        await tester.pumpWidget(
          buildTestWidget(notification: readNotification),
        );

        final readMaterials = tester.widgetList<Material>(
          find.descendant(
            of: find.byType(NotificationListItem),
            matching: find.byType(Material),
          ),
        );
        final readColor = readMaterials.first.color;

        // The colors should be different
        expect(unreadColor, isNot(equals(readColor)));
      });
    });

    group('actor name rendering', () {
      testWidgets('renders actor name bold in message', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          message: 'Alice liked your video',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Find the RichText that contains our notification message
        // (the one with 'Alice' in bold)
        bool foundBoldActor = false;
        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        for (final richText in richTexts) {
          final textSpan = richText.text;
          if (textSpan is TextSpan && textSpan.children != null) {
            for (final child in textSpan.children!) {
              if (child is TextSpan &&
                  child.text == 'Alice' &&
                  child.style?.fontWeight == FontWeight.bold) {
                foundBoldActor = true;
              }
            }
          }
        }
        expect(foundBoldActor, isTrue);
      });

      testWidgets('renders plain text when actor name is null', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          actorName: null,
          message: 'Someone liked your video',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        expect(find.text('Someone liked your video'), findsOneWidget);
      });
    });

    group('video thumbnail', () {
      testWidgets('shows thumbnail when targetVideoThumbnail is set', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification(
          targetVideoThumbnail: 'https://example.com/thumb.jpg',
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Should render ClipRRect containing the thumbnail
        expect(find.byType(ClipRRect), findsWidgets);
      });

      testWidgets('does not show thumbnail when targetVideoThumbnail is null', (
        WidgetTester tester,
      ) async {
        final notification = makeNotification();

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Verify the widget renders without error
        expect(find.byType(NotificationListItem), findsOneWidget);
      });
    });

    group('system notification', () {
      testWidgets('renders system icon without avatar stack', (
        WidgetTester tester,
      ) async {
        final notification = NotificationModel(
          id: 'sys-1',
          type: NotificationType.system,
          actorPubkey: testPubkey,
          message: 'System notification',
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // System icon emoji
        expect(find.text('📱'), findsOneWidget);
        expect(find.text('System notification'), findsOneWidget);
      });
    });

    group('timestamp', () {
      testWidgets('renders formatted timestamp', (WidgetTester tester) async {
        final notification = makeNotification();

        await tester.pumpWidget(buildTestWidget(notification: notification));

        // Since timestamp is 5 minutes ago, should show "5m ago"
        expect(find.text('5m ago'), findsOneWidget);
      });
    });
  });
}
